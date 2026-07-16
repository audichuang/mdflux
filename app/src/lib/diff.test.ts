import { describe, expect, it } from 'vitest';
import { lineDiff } from './diff';

describe('lineDiff', () => {
  it('reports identical documents as full diff with no adds/dels', () => {
    const r = lineDiff('a\nb\nc', 'a\nb\nc');
    expect(r.kind).toBe('full');
    if (r.kind !== 'full') return;
    expect(r.added).toBe(0);
    expect(r.removed).toBe(0);
    expect(r.rows.every((row) => row.type === 'same')).toBe(true);
  });

  it('detects added and removed lines', () => {
    const r = lineDiff('one\ntwo\nthree', 'one\nTWO\nthree\nfour');
    expect(r.kind).toBe('full');
    if (r.kind !== 'full') return;
    expect(r.removed).toBe(1);
    expect(r.added).toBe(2);
    expect(r.rows.some((row) => row.type === 'del' && row.text === 'two')).toBe(true);
    expect(r.rows.some((row) => row.type === 'add' && row.text === 'TWO')).toBe(true);
    expect(r.rows.some((row) => row.type === 'add' && row.text === 'four')).toBe(true);
  });

  it('handles empty → content (split gives one empty line on left)', () => {
    // ''.split('\n') => [''], so the empty left line is a deletion
    const r = lineDiff('', 'hello');
    expect(r.kind).toBe('full');
    if (r.kind !== 'full') return;
    expect(r.added).toBe(1);
    expect(r.removed).toBe(1);
  });

  it('falls back to summary when over the line cap', () => {
    const a = Array.from({ length: 50 }, (_, i) => `L${i}`).join('\n');
    const b = Array.from({ length: 50 }, (_, i) => (i === 0 ? 'X' : `L${i}`)).join('\n');
    const r = lineDiff(a, b, 10);
    expect(r.kind).toBe('summary');
    if (r.kind !== 'summary') return;
    expect(r.added).toBeGreaterThan(0);
    expect(r.removed).toBeGreaterThan(0);
    expect(r.note.toLowerCase()).toContain('large');
  });

  it('summary multiset counts duplicates correctly', () => {
    // Over cap; same multiset except one extra "x"
    const a = Array.from({ length: 20 }, () => 'same').join('\n');
    const b = a + '\nx';
    const r = lineDiff(a, b, 5);
    expect(r.kind).toBe('summary');
    if (r.kind !== 'summary') return;
    expect(r.added).toBe(1);
    expect(r.removed).toBe(0);
  });
});
