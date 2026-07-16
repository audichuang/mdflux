import { afterEach, describe, expect, it } from 'vitest';
import { clearMarkdownCache, renderMarkdown } from './mdpreview';

afterEach(() => {
  clearMarkdownCache();
});

describe('renderMarkdown', () => {
  it('renders headings and paragraphs', () => {
    const html = renderMarkdown('# Title\n\nHello **world**');
    expect(html).toMatch(/<h1[^>]*>Title<\/h1>/);
    expect(html).toContain('<strong>world</strong>');
  });

  it('renders GFM tables', () => {
    const md = '| a | b |\n| --- | --- |\n| 1 | 2 |';
    const html = renderMarkdown(md);
    expect(html).toContain('<table');
    expect(html).toContain('<td');
  });

  it('strips script tags (XSS defense)', () => {
    const html = renderMarkdown('Hi<script>alert(1)</script>');
    expect(html.toLowerCase()).not.toContain('<script');
    expect(html.toLowerCase()).toContain('hi');
  });

  it('adds rel=noopener noreferrer on target=_blank links', () => {
    const html = renderMarkdown('<a href="https://example.com" target="_blank">x</a>');
    expect(html).toContain('target="_blank"');
    expect(html).toMatch(/rel=["'][^"']*noopener/);
    expect(html).toMatch(/noreferrer/);
  });

  it('returns empty string for nullish input without throwing', () => {
    expect(renderMarkdown(null as unknown as string)).toBe('');
    expect(renderMarkdown(undefined as unknown as string)).toBe('');
  });

  it('caches repeated renders of the same markdown', () => {
    const md = '# Cached\n\nbody text for cache';
    const a = renderMarkdown(md);
    const b = renderMarkdown(md);
    expect(a).toBe(b);
  });
});
