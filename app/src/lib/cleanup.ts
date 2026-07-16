// Stage 5 — shared cleanup rule metadata and defaults.
// Mirrors the sidecar's RULE_ORDER (cleanup.py). Single source of truth for the UI.
// Labels/hints are i18n keys resolved via tr() in components.

export interface CleanupRuleDef {
  key: string;
  labelKey: string;
  hintKey: string;
  /** PDF-oriented rules default-on only when the source is a PDF (context-aware). */
  pdfOnly: boolean;
}

export const CLEANUP_RULES: CleanupRuleDef[] = [
  {
    key: 'strip_cid',
    labelKey: 'rule_strip_cid',
    hintKey: 'rule_strip_cid_hint',
    pdfOnly: true,
  },
  {
    key: 'dedup_lines',
    labelKey: 'rule_dedup_lines',
    hintKey: 'rule_dedup_lines_hint',
    pdfOnly: true,
  },
  {
    key: 'repair_lines',
    labelKey: 'rule_repair_lines',
    hintKey: 'rule_repair_lines_hint',
    pdfOnly: true,
  },
  {
    key: 'collapse_blanks',
    labelKey: 'rule_collapse_blanks',
    hintKey: 'rule_collapse_blanks_hint',
    pdfOnly: false,
  },
  {
    key: 'detect_headings',
    labelKey: 'rule_detect_headings',
    hintKey: 'rule_detect_headings_hint',
    pdfOnly: false,
  },
];

/**
 * Default rule set when cleanup is switched on. Per the locked decision, "cleanup on"
 * means all applicable rules on — but PDF-oriented rules only default-on for PDFs.
 */
export function defaultRules(sourceFormat: string): Record<string, boolean> {
  const isPdf = (sourceFormat || '').toLowerCase().includes('pdf');
  const out: Record<string, boolean> = {};
  for (const r of CLEANUP_RULES) out[r.key] = r.pdfOnly ? isPdf : true;
  return out;
}

export interface CleanupRuleSummary {
  key: string;
  label: string;
  applied: boolean;
  changes: number;
}

export interface CleanupSummary {
  rules: CleanupRuleSummary[];
  char_delta: number;
  line_delta: number;
}

export interface CleanupResult {
  markdown: string;
  summary: CleanupSummary;
  llm_applied: boolean;
  llm_notice: string | null;
}

/** Total changes across applied rules — used for headline counts. */
export function totalChanges(summary: CleanupSummary | null): number {
  if (!summary) return 0;
  return summary.rules.filter((r) => r.applied).reduce((n, r) => n + r.changes, 0);
}

// ── Cleanup method + shared UI state ────────────────────────────────────────

export type CleanupMethod = 'none' | 'rules' | 'ai';
export type ViewMode = 'preview' | 'source' | 'split' | 'changes';

/**
 * Single-file cleanup state. Lifted to the page so it survives view changes.
 * Rule-based and AI results are cached separately so switching methods (or
 * toggling the diff) never silently re-runs a slow/costly AI pass.
 */
export interface CleanupUIState {
  method: CleanupMethod;
  rules: Record<string, boolean>;
  rulesCleaned: string | null;
  rulesSummary: CleanupSummary | null;
  aiCleaned: string | null;
  aiApplied: boolean;
  aiNotice: string | null;
  /** When true, rule list / AI panel details are expanded. */
  showAdvanced: boolean;
  /** How the content area renders the active markdown. */
  viewMode: ViewMode;
  /** True while a cleanup pass is in flight. */
  running: boolean;
}

export function freshCleanup(sourceFormat: string): CleanupUIState {
  return {
    method: 'none',
    rules: defaultRules(sourceFormat),
    rulesCleaned: null,
    rulesSummary: null,
    aiCleaned: null,
    aiApplied: false,
    aiNotice: null,
    showAdvanced: false,
    viewMode: 'preview',
    running: false,
  };
}
