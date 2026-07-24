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

  // Tab list — id/label + a ref slot for roving tabindex focus management.
  const tabs: { key: DiagTab; labelKey: string }[] = [
    { key: 'health', labelKey: 'diag_tab_health' },
    { key: 'output', labelKey: 'diag_tab_output' },
    { key: 'intelligence', labelKey: 'diag_tab_intelligence' },
  ];
  let tabEls: Partial<Record<DiagTab, HTMLButtonElement>> = {};

  function selectTab(key: DiagTab) {
    diagTab = key;
  }

  // WAI-ARIA tabs pattern: ArrowLeft/Right + Home/End move focus and selection.
  function onTabsKeydown(e: KeyboardEvent) {
    const idx = tabs.findIndex((t) => t.key === diagTab);
    let nextIdx: number;
    if (e.key === 'ArrowRight') nextIdx = (idx + 1) % tabs.length;
    else if (e.key === 'ArrowLeft') nextIdx = (idx - 1 + tabs.length) % tabs.length;
    else if (e.key === 'Home') nextIdx = 0;
    else if (e.key === 'End') nextIdx = tabs.length - 1;
    else return;
    e.preventDefault();
    const next = tabs[nextIdx].key;
    diagTab = next;
    tabEls[next]?.focus();
  }
</script>

<div class="diag-wrap">
  <!-- Header -->
  <div class="diag-header hairline-b">
    <button class="btn-secondary btn-sm" onclick={onBack} aria-label={tr('diag_back')}>
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
      class="btn-tertiary btn-sm btn-icon"
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

  <div class="diag-tabs hairline-b">
    <div
      class="seg"
      role="tablist"
      tabindex="-1"
      aria-label={tr('diag_title')}
      onkeydown={onTabsKeydown}
    >
      {#each tabs as t (t.key)}
        <button
          bind:this={tabEls[t.key]}
          class="seg-btn"
          class:active={diagTab === t.key}
          role="tab"
          id={`diag-tab-${t.key}`}
          aria-controls={`diag-panel-${t.key}`}
          aria-selected={diagTab === t.key}
          tabindex={diagTab === t.key ? 0 : -1}
          onclick={() => selectTab(t.key)}>{tr(t.labelKey)}</button
        >
      {/each}
    </div>
  </div>

  <!-- Scrollable body -->
  <div class="diag-body">
    <div
      id="diag-panel-health"
      role="tabpanel"
      aria-labelledby="diag-tab-health"
      tabindex="0"
      hidden={diagTab !== 'health'}
    >
      <DiagHealth
        bind:this={health}
        bind:capsLoading
        active={diagTab === 'health'}
        {highlight}
        onShowHealth={() => (diagTab = 'health')}
      />
    </div>
    <div
      id="diag-panel-output"
      role="tabpanel"
      aria-labelledby="diag-tab-output"
      tabindex="0"
      hidden={diagTab !== 'output'}
    >
      <DiagOutput active={diagTab === 'output'} {config} {onConfigChange} />
    </div>
    <div
      id="diag-panel-intelligence"
      role="tabpanel"
      aria-labelledby="diag-tab-intelligence"
      tabindex="0"
      hidden={diagTab !== 'intelligence'}
    >
      <DiagLlm active={diagTab === 'intelligence'} {config} {onConfigChange} />
    </div>
  </div>
</div>

<style>
  .diag-wrap {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    min-width: 0;
  }

  /* Header */
  .diag-header {
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    padding-bottom: var(--sp-4);
    margin-bottom: var(--sp-4);
    flex-shrink: 0;
  }
  .diag-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    flex: 1;
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
  /* Tabpanel wrapper: reproduces the flex column + gap that used to sit directly on
     .diag-body's children (DiagHealth can render several sibling <section>s). Only
     applied while visible — must not fight the [hidden] attribute's display:none. */
  .diag-body > [role='tabpanel']:not([hidden]) {
    display: flex;
    flex-direction: column;
    gap: var(--sp-6);
    min-width: 0;
  }

  /* Tab nav */
  .diag-tabs {
    flex-shrink: 0;
    min-width: 0;
    overflow-x: auto;
    margin-bottom: var(--sp-4);
    padding-bottom: var(--sp-3);
  }
  /* Inactive-tab text sits on the seg track (canvas + translucent wash); nudge it
     off --text-muted to keep a comfortable AA margin in light theme (~4.6:1 is thin). */
  .diag-tabs :global(.seg-btn) {
    color: var(--text-secondary);
  }
  .diag-tabs :global(.seg-btn.active) {
    color: var(--text-primary);
  }
  .diag-tabs > :global(.seg) {
    flex-shrink: 0;
  }
</style>
