import { describe, expect, it } from 'vitest';
import {
  CLEANUP_RULES,
  defaultRules,
  freshCleanup,
  totalChanges,
  type CleanupSummary,
} from './cleanup';

describe('CLEANUP_RULES metadata', () => {
  it('has stable keys matching the sidecar RULE_ORDER', () => {
    expect(CLEANUP_RULES.map((r) => r.key)).toEqual([
      'strip_cid',
      'dedup_lines',
      'repair_lines',
      'collapse_blanks',
      'detect_headings',
    ]);
  });

  it('uses i18n keys for labels and hints', () => {
    for (const r of CLEANUP_RULES) {
      expect(r.labelKey).toMatch(/^rule_/);
      expect(r.hintKey).toMatch(/^rule_/);
      expect(r.hintKey.endsWith('_hint')).toBe(true);
    }
  });
});

describe('defaultRules', () => {
  it('enables PDF-only rules for PDF sources', () => {
    const rules = defaultRules('pdf');
    expect(rules.strip_cid).toBe(true);
    expect(rules.dedup_lines).toBe(true);
    expect(rules.repair_lines).toBe(true);
    expect(rules.collapse_blanks).toBe(true);
    expect(rules.detect_headings).toBe(true);
  });

  it('disables PDF-only rules for non-PDF sources', () => {
    const rules = defaultRules('docx');
    expect(rules.strip_cid).toBe(false);
    expect(rules.dedup_lines).toBe(false);
    expect(rules.repair_lines).toBe(false);
    expect(rules.collapse_blanks).toBe(true);
    expect(rules.detect_headings).toBe(true);
  });

  it('treats format strings containing pdf as PDF', () => {
    expect(defaultRules('application/pdf').strip_cid).toBe(true);
    expect(defaultRules('PDF').strip_cid).toBe(true);
  });
});

describe('totalChanges', () => {
  it('returns 0 for null or empty applied rules', () => {
    expect(totalChanges(null)).toBe(0);
    const empty: CleanupSummary = {
      rules: [{ key: 'x', label: 'x', applied: false, changes: 9 }],
      char_delta: 0,
      line_delta: 0,
    };
    expect(totalChanges(empty)).toBe(0);
  });

  it('sums only applied rules', () => {
    const summary: CleanupSummary = {
      rules: [
        { key: 'a', label: 'a', applied: true, changes: 3 },
        { key: 'b', label: 'b', applied: false, changes: 100 },
        { key: 'c', label: 'c', applied: true, changes: 2 },
      ],
      char_delta: -10,
      line_delta: -1,
    };
    expect(totalChanges(summary)).toBe(5);
  });
});

describe('freshCleanup', () => {
  it('starts idle with preview mode and PDF-aware rules', () => {
    const state = freshCleanup('pdf');
    expect(state.method).toBe('none');
    expect(state.viewMode).toBe('preview');
    expect(state.running).toBe(false);
    expect(state.showAdvanced).toBe(false);
    expect(state.rulesCleaned).toBeNull();
    expect(state.aiCleaned).toBeNull();
    expect(state.rules.strip_cid).toBe(true);
  });

  it('uses non-PDF defaults for docx', () => {
    expect(freshCleanup('docx').rules.strip_cid).toBe(false);
  });
});
