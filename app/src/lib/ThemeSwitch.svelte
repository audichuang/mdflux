<script lang="ts">
  import { theme, setThemePreference, type ThemePreference } from './theme.svelte';
  import { tr } from './locale.svelte';

  const OPTIONS: {
    id: ThemePreference;
    labelKey: string;
    titleKey: string;
  }[] = [
    { id: 'system', labelKey: 'theme_system', titleKey: 'theme_system_hint' },
    { id: 'light', labelKey: 'theme_light', titleKey: 'theme_light_hint' },
    { id: 'dark', labelKey: 'theme_dark', titleKey: 'theme_dark_hint' },
  ];
</script>

<div class="seg theme-seg" role="group" aria-label={tr('theme')}>
  {#each OPTIONS as opt}
    <button
      type="button"
      class="seg-btn theme-btn"
      class:active={theme.preference === opt.id}
      title={tr(opt.titleKey)}
      aria-pressed={theme.preference === opt.id}
      onclick={() => setThemePreference(opt.id)}
    >
      {#if opt.id === 'system'}
        <!-- Half light / half dark window (matches Claude "系統") -->
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <rect
            x="1.5"
            y="2.5"
            width="11"
            height="9"
            rx="1.5"
            stroke="currentColor"
            stroke-width="1.25"
          />
          <path d="M7 2.5V11.5" stroke="currentColor" stroke-width="1.25" />
          <path d="M7 3.25H11.25V10.75H7V3.25Z" fill="currentColor" opacity="0.35" />
        </svg>
      {:else if opt.id === 'light'}
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <circle cx="7" cy="7" r="2.25" stroke="currentColor" stroke-width="1.25" />
          <path
            d="M7 1.5V2.75M7 11.25V12.5M1.5 7H2.75M11.25 7H12.5M3.05 3.05L3.93 3.93M10.07 10.07L10.95 10.95M10.95 3.05L10.07 3.93M3.93 10.07L3.05 10.95"
            stroke="currentColor"
            stroke-width="1.25"
            stroke-linecap="round"
          />
        </svg>
      {:else}
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <path
            d="M11.2 8.35A4.75 4.75 0 0 1 5.65 2.8 4.75 4.75 0 1 0 11.2 8.35Z"
            stroke="currentColor"
            stroke-width="1.25"
            stroke-linejoin="round"
          />
        </svg>
      {/if}
      <span class="theme-label">{tr(opt.labelKey)}</span>
    </button>
  {/each}
</div>

<style>
  .theme-seg {
    flex-shrink: 0;
  }
  .theme-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 4px 8px;
  }
  .theme-label {
    font-size: 11px;
    line-height: 1;
  }

  /* Compact: icon-only when header is tight */
  @media (max-width: 900px) {
    .theme-label {
      display: none;
    }
    .theme-btn {
      padding: 4px 7px;
    }
  }
</style>
