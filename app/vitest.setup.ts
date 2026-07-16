// Minimal polyfills for Svelte 5 runes used in pure unit tests of .svelte.ts modules.
// Components are not mounted here — we only need $state to hold plain values.
if (typeof (globalThis as { $state?: unknown }).$state !== 'function') {
  (globalThis as { $state: <T>(v: T) => T }).$state = <T>(v: T) => v;
}
