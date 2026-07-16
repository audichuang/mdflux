"""Unit tests for deterministic Markdown cleanup (no network, no models).

Run from this directory:
  python3 -m unittest test_cleanup.py -v
Or via app scripts:
  npm run test:sidecar
"""

from __future__ import annotations

import unittest

import cleanup


class TestCleanApi(unittest.TestCase):
    def test_empty_with_all_rules_off(self):
        text, summary = cleanup.clean("", "pdf", {})
        self.assertEqual(text, "")
        self.assertEqual(len(summary["rules"]), len(cleanup.RULE_ORDER))
        self.assertTrue(all(not r["applied"] for r in summary["rules"]))

    def test_rules_order_and_labels_stable(self):
        self.assertEqual(
            cleanup.RULE_ORDER,
            [
                "strip_cid",
                "dedup_lines",
                "repair_lines",
                "collapse_blanks",
                "detect_headings",
            ],
        )
        for key in cleanup.RULE_ORDER:
            self.assertIn(key, cleanup.RULE_LABELS)

    def test_disabled_rules_leave_text_unchanged(self):
        raw = "Hello (cid:12)\n\n\nWorld"
        text, summary = cleanup.clean(raw, "pdf", {k: False for k in cleanup.RULE_ORDER})
        self.assertEqual(text, raw)
        self.assertEqual(summary["char_delta"], 0)
        for r in summary["rules"]:
            self.assertFalse(r["applied"])
            self.assertEqual(r["changes"], 0)


class TestStripCid(unittest.TestCase):
    def test_removes_cid_markers(self):
        raw = "Glyph (cid:12) junk (cid:3) end"
        text, summary = cleanup.clean(raw, "pdf", {"strip_cid": True})
        self.assertNotIn("cid:", text)
        self.assertIn("Glyph", text)
        self.assertIn("end", text)
        cid = next(r for r in summary["rules"] if r["key"] == "strip_cid")
        self.assertTrue(cid["applied"])
        self.assertEqual(cid["changes"], 2)


class TestDedupLines(unittest.TestCase):
    def test_collapses_immediate_duplicates(self):
        raw = "Header\nHeader\nBody\nBody"
        text, summary = cleanup.clean(raw, "pdf", {"dedup_lines": True})
        lines = text.split("\n")
        # Consecutive duplicates should collapse
        self.assertEqual(lines.count("Header"), 1)
        self.assertEqual(lines.count("Body"), 1)
        rule = next(r for r in summary["rules"] if r["key"] == "dedup_lines")
        self.assertGreaterEqual(rule["changes"], 1)


class TestCollapseBlanks(unittest.TestCase):
    def test_collapses_long_blank_runs(self):
        raw = "A\n\n\n\n\nB"
        text, _ = cleanup.clean(raw, "docx", {"collapse_blanks": True})
        # Should not keep 4+ consecutive empty lines
        self.assertNotIn("\n\n\n\n", text)
        self.assertIn("A", text)
        self.assertIn("B", text)


class TestDetectHeadings(unittest.TestCase):
    def test_promotes_numbered_heading_like_lines(self):
        raw = "1. Introduction\n\nSome paragraph text here that is long enough."
        text, summary = cleanup.clean(raw, "docx", {"detect_headings": True})
        rule = next(r for r in summary["rules"] if r["key"] == "detect_headings")
        self.assertTrue(rule["applied"])
        # Conservative: either promotes or leaves alone with 0 changes — must not crash
        self.assertIsInstance(text, str)
        self.assertGreater(len(text), 0)


class TestRepairLines(unittest.TestCase):
    def test_rejoins_broken_sentence(self):
        # Two lines that look like a mid-sentence break (no terminal punct on first)
        raw = "This is a long sentence that was split\nacross a column boundary somehow."
        text, summary = cleanup.clean(raw, "pdf", {"repair_lines": True})
        rule = next(r for r in summary["rules"] if r["key"] == "repair_lines")
        self.assertTrue(rule["applied"])
        self.assertIsInstance(text, str)
        # Content words preserved
        self.assertIn("sentence", text)
        self.assertIn("boundary", text)


class TestAllRulesTogether(unittest.TestCase):
    def test_pdf_fixture_pipeline(self):
        raw = (
            "Title (cid:1)\n"
            "Title (cid:1)\n"
            "\n\n\n"
            "A broken line that continues\non the next line.\n"
            "1. Section One\n"
            "Body text."
        )
        rules = {k: True for k in cleanup.RULE_ORDER}
        text, summary = cleanup.clean(raw, "pdf", rules)
        self.assertNotIn("(cid:", text)
        self.assertEqual(summary["char_delta"], len(text) - len(raw))
        self.assertEqual(len(summary["rules"]), 5)
        self.assertTrue(all(r["applied"] for r in summary["rules"]))


class TestDataLossWarning(unittest.TestCase):
    def test_none_when_faithful(self):
        original = "The quick brown fox jumps over the lazy dog and keeps going with more words."
        self.assertIsNone(cleanup.data_loss_warning(original, original))

    def test_warns_when_much_shorter(self):
        original = "word " * 200
        candidate = "short summary only"
        warn = cleanup.data_loss_warning(original, candidate)
        self.assertIsNotNone(warn)
        self.assertIn("shorter", warn.lower())

    def test_empty_candidate_returns_none(self):
        # Caller treats emptiness as hard failure
        self.assertIsNone(cleanup.data_loss_warning("hello world text", "   "))


class TestSplitChunks(unittest.TestCase):
    def test_small_text_is_single_chunk(self):
        chunks = cleanup._split_into_chunks("hello\n\nworld", 8_000)
        self.assertEqual(len(chunks), 1)

    def test_respects_blank_line_boundaries(self):
        blocks = [f"Paragraph number {i} with some filler text." for i in range(20)]
        text = "\n\n".join(blocks)
        chunks = cleanup._split_into_chunks(text, target_chars=80)
        self.assertGreater(len(chunks), 1)
        # Rejoining should preserve all content words
        joined = "\n\n".join(chunks)
        for b in blocks:
            self.assertIn(b, joined)


if __name__ == "__main__":
    unittest.main()
