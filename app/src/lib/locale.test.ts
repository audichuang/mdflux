import { afterEach, describe, expect, it } from 'vitest';
import { locale, setLang, tr } from './locale.svelte';

afterEach(() => {
  setLang('en');
});

describe('tr / setLang', () => {
  it('returns English strings by default', () => {
    setLang('en');
    expect(tr('ready')).toBe('Ready');
    expect(tr('diagnostics')).toBe('Settings');
    expect(tr('convert_btn')).toMatch(/Markdown/i);
  });

  it('switches to Traditional Chinese', () => {
    setLang('zh');
    expect(locale.current).toBe('zh');
    expect(tr('ready')).toBe('就緒');
    expect(tr('diagnostics')).toBe('設定');
    expect(tr('drop_files')).toContain('拖');
  });

  it('interpolates template variables', () => {
    setLang('en');
    expect(tr('from_format', { format: 'PDF' })).toBe('From: PDF');
    expect(tr('retry_failed', { count: 3 })).toBe('Retry 3 failed file');
    setLang('zh');
    expect(tr('from_format', { format: 'DOCX' })).toContain('DOCX');
  });

  it('falls back to the key when missing', () => {
    expect(tr('this_key_does_not_exist_xyz')).toBe('this_key_does_not_exist_xyz');
  });

  it('keeps en and zh key sets aligned', () => {
    // Access via known keys that must exist in both locales
    const keys = [
      'ready',
      'partial',
      'drop_files',
      'convert_btn',
      'preview',
      'save_md',
      'diag_tab_health',
      'diag_tab_output',
      'diag_tab_intelligence',
      'rule_strip_cid',
      'mode_local',
      'need_folder',
      'filter_failed',
    ];
    for (const key of keys) {
      setLang('en');
      const en = tr(key);
      setLang('zh');
      const zh = tr(key);
      expect(en, `en missing: ${key}`).not.toBe(key);
      expect(zh, `zh missing: ${key}`).not.toBe(key);
      expect(en).not.toBe(zh); // translations should differ for these keys
    }
  });
});
