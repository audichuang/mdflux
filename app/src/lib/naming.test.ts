import { describe, expect, it } from 'vitest';
import {
  buildOutputFilename,
  buildOutputName,
  fileExt,
  fileStem,
  ruleLabel,
  type NamingCase,
} from './naming';

describe('fileStem', () => {
  it('strips directory and extension (posix)', () => {
    expect(fileStem('/home/u/docs/Report.pdf')).toBe('Report');
  });

  it('handles Windows paths', () => {
    expect(fileStem('C:\\Users\\a\\notes.final.docx')).toBe('notes.final');
  });

  it('returns output for empty names; keeps dotfiles without extension as stem', () => {
    expect(fileStem('')).toBe('output');
    // lastIndexOf('.') === 0 is not treated as extension (dot > 0 guard)
    expect(fileStem('.gitignore')).toBe('.gitignore');
  });

  it('keeps name without extension', () => {
    expect(fileStem('README')).toBe('README');
  });
});

describe('fileExt', () => {
  it('returns lowercase extension without the dot', () => {
    expect(fileExt('/a/b/File.PDF')).toBe('pdf');
  });

  it('returns empty string when missing', () => {
    expect(fileExt('noext')).toBe('');
    expect(fileExt('.hidden')).toBe('');
  });
});

describe('buildOutputName / buildOutputFilename', () => {
  const path = '/docs/Annual Report.pdf';

  it('defaults empty template to {stem}', () => {
    expect(buildOutputName(path, '', 'keep')).toBe('Annual Report');
    expect(buildOutputFilename(path, '  ', 'keep')).toBe('Annual Report.md');
  });

  it('substitutes stem, ext, and date tokens', () => {
    const name = buildOutputName(path, '{stem}_{ext}_{date}', 'keep');
    expect(name.startsWith('Annual Report_pdf_')).toBe(true);
    // UTC YYYY-MM-DD
    expect(name).toMatch(/_pdf_\d{4}-\d{2}-\d{2}$/);
  });

  it('applies lower and slug cases', () => {
    expect(buildOutputName(path, '{stem}', 'lower')).toBe('annual report');
    expect(buildOutputName(path, '{stem}', 'slug')).toBe('annual-report');
  });

  it('sanitizes illegal filename characters', () => {
    expect(buildOutputName('/a/x.pdf', 'a:b*c?', 'keep')).toBe('a-b-c-');
  });

  // These vectors are mirrored in the Rust test `naming_template_and_case` (lib.rs) —
  // keep both sides in sync.
  it('slugifies Unicode (CJK) text, matching Rust is_alphanumeric', () => {
    expect(buildOutputName('/docs/年度報告.pdf', '{stem}', 'slug')).toBe('年度報告');
    expect(buildOutputName('/docs/My 報告 2.pdf', '{stem}', 'slug')).toBe('my-報告-2');
  });

  it('appends _ to Windows reserved device names', () => {
    expect(buildOutputName('/a/con.pdf', '{stem}', 'keep')).toBe('con_');
  });

  it('always appends .md for previews', () => {
    expect(buildOutputFilename(path, '{stem}', 'keep')).toBe('Annual Report.md');
  });

  it('covers all NamingCase values without throwing', () => {
    const cases: NamingCase[] = ['keep', 'lower', 'slug'];
    for (const c of cases) {
      expect(buildOutputFilename(path, '{stem}-{date}', c).endsWith('.md')).toBe(true);
    }
  });
});

describe('ruleLabel', () => {
  it('returns human labels for each output rule', () => {
    expect(ruleLabel('next_to_source')).toContain('Next');
    expect(ruleLabel('fixed_folder')).toContain('folder');
    expect(ruleLabel('mirror_tree')).toContain('Mirror');
  });
});
