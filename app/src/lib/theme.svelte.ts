export type ThemePreference = 'system' | 'light' | 'dark';
export type ResolvedTheme = 'light' | 'dark';

const STORAGE_KEY = 'mdflux_theme';

export const theme = $state({
  preference: 'system' as ThemePreference,
  resolved: 'dark' as ResolvedTheme,
});

function getSystemTheme(): ResolvedTheme {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
    return 'dark';
  }
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function resolve(pref: ThemePreference): ResolvedTheme {
  return pref === 'system' ? getSystemTheme() : pref;
}

function applyDom(resolved: ResolvedTheme) {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.theme = resolved;
  document.documentElement.style.colorScheme = resolved;
}

function persist(pref: ThemePreference) {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(STORAGE_KEY, pref);
  } catch {
    // Ignore DOMException / SecurityError in sandboxed environments
  }
}

export function setThemePreference(pref: ThemePreference) {
  theme.preference = pref;
  theme.resolved = resolve(pref);
  applyDom(theme.resolved);
  persist(pref);
}

// Boot: restore preference, paint theme, watch OS changes
if (typeof localStorage !== 'undefined') {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'system' || saved === 'light' || saved === 'dark') {
      theme.preference = saved;
    }
  } catch {
    // Ignore
  }
}

theme.resolved = resolve(theme.preference);
applyDom(theme.resolved);

if (typeof window !== 'undefined' && typeof window.matchMedia === 'function') {
  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  const onChange = () => {
    if (theme.preference !== 'system') return;
    theme.resolved = getSystemTheme();
    applyDom(theme.resolved);
  };
  if (typeof mq.addEventListener === 'function') {
    mq.addEventListener('change', onChange);
  } else if (typeof mq.addListener === 'function') {
    // Older WebViews
    mq.addListener(onChange);
  }
}
