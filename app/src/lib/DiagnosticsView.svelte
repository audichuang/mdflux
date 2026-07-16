<script lang="ts">
  import { tr } from './locale.svelte';
  import DiagHealth from './DiagHealth.svelte';
  import DiagOutput from './DiagOutput.svelte';
  import DiagLlm from './DiagLlm.svelte';

  // ── Types ──────────────────────────────────────────────────────────────────

  export interface AppConfig {
    llm_mode: string;
    local_base_url: string;
    api_type: string;
    api_base_url: string;
    api_key: string;
    cleanup_model: string;
    cleanup_seen: boolean;
    // Stage 6
    conversion_model: string;
    llm_conversion: boolean;
    extract_images: boolean;
    audio_model: string;
    // Stage 7 — output management
    output_rule: string; // 'next_to_source' | 'fixed_folder' | 'mirror_tree'
    output_folder: string; // default folder for fixed_folder / mirror_tree
    naming_template: string; // tokens: {stem} {ext} {date}
    naming_case: string; // 'keep' | 'lower' | 'slug'
    open_after_convert: boolean;
  }

  // ── Props ──────────────────────────────────────────────────────────────────

  let {
    onBack,
    highlight = null,
    config,
    onConfigChange,
  }: {
    onBack: () => void;
    highlight?: string | null;
    config: AppConfig;
    onConfigChange: (c: AppConfig) => Promise<void>;
  } = $props();

  // ── State ──────────────────────────────────────────────────────────────────

  type DiagTab = 'health' | 'output' | 'intelligence';
  let diagTab = $state<DiagTab>('health');

  // Health owns capability loading; the header refresh button drives it.
  let capsLoading = $state(true);
  let health = $state<ReturnType<typeof DiagHealth>>();
</script>

<div class="diag-wrap">
  <!-- Header -->
  <div class="diag-header">
    <button class="back-btn" onclick={onBack} aria-label={tr('diag_back')}>
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
        <path
          d="M9 2L4 7l5 5"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
      {tr('back')}
    </button>
    <span class="diag-title">{tr('diag_title')}</span>
    <button
      class="refresh-btn"
      onclick={() => health?.loadCaps()}
      disabled={capsLoading}
      aria-label={tr('diag_refresh')}
      title={tr('diag_refresh')}
    >
      <svg
        width="14"
        height="14"
        viewBox="0 0 14 14"
        fill="none"
        aria-hidden="true"
        class:spinning={capsLoading}
      >
        <path
          d="M12 7A5 5 0 1 1 7 2a5 5 0 0 1 3.54 1.46L12 2v4H8l1.59-1.59A3 3 0 1 0 10 7"
          stroke="currentColor"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>
  </div>

  <div class="diag-tabs" role="tablist" aria-label={tr('diag_title')}>
    <button
      class="diag-tab"
      class:active={diagTab === 'health'}
      role="tab"
      aria-selected={diagTab === 'health'}
      onclick={() => (diagTab = 'health')}>{tr('diag_tab_health')}</button
    >
    <button
      class="diag-tab"
      class:active={diagTab === 'output'}
      role="tab"
      aria-selected={diagTab === 'output'}
      onclick={() => (diagTab = 'output')}>{tr('diag_tab_output')}</button
    >
    <button
      class="diag-tab"
      class:active={diagTab === 'intelligence'}
      role="tab"
      aria-selected={diagTab === 'intelligence'}
      onclick={() => (diagTab = 'intelligence')}>{tr('diag_tab_intelligence')}</button
    >
  </div>

  <!-- Scrollable body -->
  <div class="diag-body">
    <DiagHealth
      bind:this={health}
      bind:capsLoading
      active={diagTab === 'health'}
      {highlight}
      onShowHealth={() => (diagTab = 'health')}
    />
    <DiagOutput active={diagTab === 'output'} {config} {onConfigChange} />
    <DiagLlm active={diagTab === 'intelligence'} {config} {onConfigChange} />
  </div>
</div>

<style>
  .diag-wrap {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
  }

  /* Header */
  .diag-header {
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    padding-bottom: var(--sp-4);
    border-bottom: 1px solid var(--divider);
    margin-bottom: var(--sp-4);
    flex-shrink: 0;
  }
  .back-btn {
    display: flex;
    align-items: center;
    gap: var(--sp-1);
    background: var(--surface-2);
    border: 1px solid transparent;
    color: var(--text-primary);
    font-size: 12.5px;
    font-weight: 600;
    font-family: var(--font-ui);
    cursor: pointer;
    padding: 6px 12px;
    border-radius: var(--radius-sm);
    box-shadow: var(--seg-shadow);
    transition:
      color var(--transition-fast),
      background var(--transition-fast),
      border-color var(--transition-fast);
  }
  .back-btn:hover {
    background: var(--surface-3);
  }
  .back-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--accent) 60%, transparent);
  }
  .diag-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    flex: 1;
  }
  .refresh-btn {
    background: var(--surface-2);
    border: 1px solid transparent;
    color: var(--text-secondary);
    box-shadow: var(--seg-shadow);
    cursor: pointer;
    width: 32px;
    height: 32px;
    border-radius: var(--radius-sm);
    display: flex;
    align-items: center;
    justify-content: center;
    transition:
      color var(--transition-fast),
      background var(--transition-fast),
      border-color var(--transition-fast);
  }
  .refresh-btn:hover {
    color: var(--text-primary);
    background: var(--surface-3);
  }
  .refresh-btn:disabled {
    opacity: 0.4;
    cursor: default;
  }
  .refresh-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--accent) 60%, transparent);
  }
  .spinning {
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .spinning {
      animation: none;
    }
  }

  /* Body */
  .diag-body {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: var(--sp-6);
    padding-right: var(--sp-1);
  }

  /* Tab nav */
  .diag-tabs {
    display: flex;
    gap: 4px;
    flex-shrink: 0;
    margin-bottom: var(--sp-4);
    padding-bottom: var(--sp-3);
    border-bottom: 1px solid var(--divider);
  }
  .diag-tab {
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 500;
    font-family: var(--font-ui);
    color: var(--text-muted);
    background: transparent;
    border: 1px solid transparent;
    border-radius: 999px;
    cursor: pointer;
    transition: all var(--transition-fast);
  }
  .diag-tab:hover {
    color: var(--text-secondary);
    background: color-mix(in srgb, var(--text-primary) 4%, transparent);
  }
  .diag-tab.active {
    color: var(--text-primary);
    background: var(--surface-1);
    box-shadow: var(--seg-shadow);
  }
  :root[data-theme='dark'] .diag-tab.active {
    background: var(--surface-2);
  }
</style>
