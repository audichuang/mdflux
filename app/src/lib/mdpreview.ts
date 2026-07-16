// Stage 5 — Markdown → safe HTML for the Preview tab.
// marked parses GFM (incl. tables); DOMPurify strips any scripts/handlers that a
// converted document might carry. DOMPurify needs `window`, so callers must only
// invoke this in the browser (it's only ever used at runtime in the webview).
import { marked } from 'marked';
import DOMPurify from 'dompurify';

marked.setOptions({ gfm: true, breaks: false });

// Defense-in-depth: force rel="noopener noreferrer" on any target="_blank" link so a
// link inside the user's own converted preview can't reach back via window.opener
// (tab-nabbing). Modern Chromium/WebView2 already defaults to this, but the hook also
// covers older engines and costs nothing. Registered once at module load; guarded for
// SSR, where DOMPurify is a stub without addHook.
if (typeof DOMPurify.addHook === 'function') {
  DOMPurify.addHook('afterSanitizeAttributes', (node) => {
    if (node.nodeName === 'A' && node.getAttribute('target') === '_blank') {
      node.setAttribute('rel', 'noopener noreferrer');
    }
  });
}

// Small LRU cache — split view renders before+after; toggling tabs reuses results.
// Keyed by the full source string: collision-free, and holding a dozen preview-sized
// docs is cheap. (A lossy fingerprint key would risk returning stale HTML.)
const CACHE_MAX = 12;
const cache = new Map<string, string>();

export function renderMarkdown(md: string): string {
  const raw = md ?? '';
  const hit = cache.get(raw);
  if (hit !== undefined) {
    // Refresh LRU order
    cache.delete(raw);
    cache.set(raw, hit);
    return hit;
  }

  const html = marked.parse(raw, { async: false }) as string;
  if (typeof DOMPurify.sanitize !== 'function') return ''; // SSR guard
  const result = DOMPurify.sanitize(html, { ADD_ATTR: ['target'] });

  if (cache.size >= CACHE_MAX) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(raw, result);
  return result;
}

/** Drop cached HTML (e.g. after language change is not needed; for tests). */
export function clearMarkdownCache(): void {
  cache.clear();
}
