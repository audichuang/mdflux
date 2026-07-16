<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';
  import { tr } from './locale.svelte';

  // ── Types ──────────────────────────────────────────────────────────────────

  interface FormatEntry {
    key: string;
    label: string;
    extensions: string[];
    module: string | null;
    module_version: string | null;
    converter: string | null;
    status: 'available' | 'missing' | 'broken' | 'coming_later';
    error: string | null;
    note?: string | null;
  }

  interface CapabilitiesReport {
    runtime: {
      python_version: string;
      sidecar_version: string;
      markitdown_version: string;
      venv_path: string;
    };
    formats: FormatEntry[];
    optional: {
      ocr: { status: string; engine: string; size_hint: string; note: string };
      audio: { status: string; engine: string; size_hint: string; note: string };
    };
  }

  interface EngineState {
    status: string; // "not_installed" | "installing" | "installed" | "failed"
    error?: string | null;
  }

  interface EngineInstallProgress {
    engine: string;
    step: string;
    message: string;
    pct: number;
  }

  // ── Props ──────────────────────────────────────────────────────────────────

  let {
    active,
    highlight = null,
    capsLoading = $bindable(true),
    onShowHealth,
  }: {
    active: boolean;
    highlight?: string | null;
    capsLoading?: boolean;
    onShowHealth?: () => void;
  } = $props();

  // ── State ──────────────────────────────────────────────────────────────────

  let caps = $state<CapabilitiesReport | null>(null);
  let capsError = $state<string | null>(null);

  // Stage 6: optional engine install state
  let ocrState = $state<EngineState>({ status: 'not_installed' });
  let audioState = $state<EngineState>({ status: 'not_installed' });
  let installing = $state<string | null>(null);
  let installMsg = $state('');
  let unlistenInstall: (() => void) | null = null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  onMount(async () => {
    let dead = false;
    loadCaps();

    // Load engine states from provision file (includes installing/failed states).
    const [ocr, audio] = await Promise.all([
      invoke<EngineState>('optional_engine_status', { engine: 'ocr' }).catch(() => ({
        status: 'not_installed',
      })),
      invoke<EngineState>('optional_engine_status', { engine: 'audio' }).catch(() => ({
        status: 'not_installed',
      })),
    ]);
    if (dead) return;
    ocrState = ocr as EngineState;
    audioState = audio as EngineState;

    listen<EngineInstallProgress>('engine:install-progress', ({ payload }) => {
      installMsg = payload.message;
      if (payload.step === 'installed') {
        if (payload.engine === 'ocr') ocrState = { status: 'installed' };
        else audioState = { status: 'installed' };
      }
    }).then((fn) => {
      if (dead) fn();
      else unlistenInstall = fn;
    });
  });

  onDestroy(() => {
    unlistenInstall?.();
  });

  // ── Capabilities ───────────────────────────────────────────────────────────

  export async function loadCaps() {
    capsLoading = true;
    capsError = null;
    try {
      caps = await invoke<CapabilitiesReport>('get_capabilities');
    } catch (e) {
      capsError = String(e);
    } finally {
      capsLoading = false;
      if (highlight) {
        onShowHealth?.();
        setTimeout(() => scrollToFormat(highlight!), 80);
      }
    }
  }

  function scrollToFormat(key: string) {
    const el = document.getElementById(`fmt-${key}`);
    el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  // ── Engine install ─────────────────────────────────────────────────────────

  async function installEngine(engine: string) {
    installing = engine;
    installMsg = tr('starting_install');
    if (engine === 'ocr') ocrState = { status: 'installing' };
    else audioState = { status: 'installing' };
    try {
      await invoke('install_engine', { engine });
      if (engine === 'ocr') ocrState = { status: 'installed' };
      else audioState = { status: 'installed' };
      loadCaps(); // refresh format table to show new OCR/audio rows as available
    } catch (e) {
      const err = String(e);
      if (engine === 'ocr') ocrState = { status: 'failed', error: err };
      else audioState = { status: 'failed', error: err };
    } finally {
      installing = null;
      installMsg = '';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  function dotColor(status: string) {
    if (status === 'available') return 'green';
    if (status === 'coming_later') return 'amber';
    return 'red';
  }

  function badgeLabel(status: string) {
    if (status === 'available') return tr('badge_available');
    if (status === 'coming_later') return tr('badge_later');
    if (status === 'missing') return tr('badge_missing');
    return tr('badge_broken');
  }

  function detailText(fmt: FormatEntry): string {
    if (fmt.status === 'available') {
      if (!fmt.module) return '';
      return fmt.module + (fmt.module_version ? ` ${fmt.module_version}` : '');
    }
    if (fmt.status === 'missing') return tr('fmt_repair_hint');
    if (fmt.status === 'broken') return fmt.error ?? tr('unknown_error');
    return fmt.note ?? '';
  }
</script>

{#if active}
  {#if capsLoading}
    <div class="loading-state">
      <div class="spinner-sm" aria-label={tr('checking_caps')}></div>
      <span>{tr('checking_caps')}</span>
    </div>
  {:else if capsError}
    <div class="load-error">
      <span>{tr('caps_load_error', { error: capsError })}</span>
      <button class="retry-btn" onclick={loadCaps}>{tr('retry')}</button>
    </div>
  {:else if caps}
    <section class="section">
      <h2 class="section-title">{tr('section_runtime')}</h2>
      <div class="runtime-grid">
        <div class="runtime-item">
          <span class="runtime-label">{tr('label_python')}</span>
          <span class="runtime-value">{caps.runtime.python_version}</span>
        </div>
        <div class="runtime-item">
          <span class="runtime-label">{tr('label_markitdown')}</span>
          <span class="runtime-value">{caps.runtime.markitdown_version}</span>
        </div>
        <div class="runtime-item">
          <span class="runtime-label">{tr('label_sidecar')}</span>
          <span class="runtime-value">{caps.runtime.sidecar_version}</span>
        </div>
        <div class="runtime-item span2">
          <span class="runtime-label">{tr('label_venv')}</span>
          <span class="runtime-value mono ellipsis" title={caps.runtime.venv_path}
            >{caps.runtime.venv_path}</span
          >
        </div>
      </div>
    </section>

    <section class="section">
      <h2 class="section-title">{tr('section_formats')}</h2>
      <div class="cap-list">
        {#each caps.formats as fmt}
          <div id="fmt-{fmt.key}" class="cap-row" class:highlighted={highlight === fmt.key}>
            <span class="dot dot-{dotColor(fmt.status)}" aria-hidden="true"></span>
            <span class="cap-label">{fmt.label}</span>
            <span class="cap-exts">{fmt.extensions.join(' · ')}</span>
            <span class="cap-badge badge-{dotColor(fmt.status)}">{badgeLabel(fmt.status)}</span>
            {#if detailText(fmt)}
              <span
                class="cap-detail"
                class:cap-detail-red={fmt.status === 'missing' || fmt.status === 'broken'}
              >
                {detailText(fmt)}
              </span>
            {/if}
          </div>
        {/each}
      </div>
    </section>

    <section class="section">
      <h2 class="section-title">{tr('section_optional')}</h2>
      <div class="cap-list">
        <div class="cap-row cap-row-wrap">
          <span
            class="dot dot-{ocrState.status === 'installed'
              ? 'green'
              : ocrState.status === 'failed'
                ? 'red'
                : 'amber'}"
            aria-hidden="true"
          ></span>
          <span class="cap-label">{tr('ocr_label')}</span>
          <span class="cap-exts">{caps.optional.ocr.engine}</span>
          {#if ocrState.status === 'installed'}
            <span class="cap-badge badge-green">{tr('badge_installed')}</span>
          {:else if ocrState.status === 'installing' && installing === 'ocr'}
            <span class="cap-badge badge-amber">{tr('badge_installing')}</span>
          {:else if ocrState.status === 'failed'}
            <span class="cap-badge badge-red">{tr('badge_failed')}</span>
          {:else}
            <span class="cap-badge badge-amber">{tr('badge_not_installed')}</span>
            <button
              class="install-btn"
              onclick={() => installEngine('ocr')}
              disabled={installing !== null}
            >
              {tr('install')} <span class="install-size">· {caps.optional.ocr.size_hint}</span>
            </button>
          {/if}
          {#if installing === 'ocr' && ocrState.status === 'installing'}
            <div class="install-progress-wrap">
              <div class="install-track"><div class="install-indet"></div></div>
              <span class="install-progress-msg">{installMsg}</span>
            </div>
          {:else if ocrState.status === 'failed' && ocrState.error}
            <div class="install-error">
              <span>{ocrState.error.split('\n')[0]}</span>
              <button
                class="install-btn"
                onclick={() => installEngine('ocr')}
                disabled={installing !== null}>{tr('retry')}</button
              >
            </div>
          {:else}
            <span class="cap-detail">{caps.optional.ocr.note}</span>
          {/if}
        </div>

        <div class="cap-row cap-row-wrap">
          <span
            class="dot dot-{audioState.status === 'installed'
              ? 'green'
              : audioState.status === 'failed'
                ? 'red'
                : 'amber'}"
            aria-hidden="true"
          ></span>
          <span class="cap-label">{tr('audio_label')}</span>
          <span class="cap-exts">{caps.optional.audio.engine}</span>
          {#if audioState.status === 'installed'}
            <span class="cap-badge badge-green">{tr('badge_installed')}</span>
          {:else if audioState.status === 'installing' && installing === 'audio'}
            <span class="cap-badge badge-amber">{tr('badge_installing')}</span>
          {:else if audioState.status === 'failed'}
            <span class="cap-badge badge-red">{tr('badge_failed')}</span>
          {:else}
            <span class="cap-badge badge-amber">{tr('badge_not_installed')}</span>
            <button
              class="install-btn"
              onclick={() => installEngine('audio')}
              disabled={installing !== null}
            >
              {tr('install')}
              <span class="install-size">· {caps.optional.audio.size_hint}</span>
            </button>
          {/if}
          {#if installing === 'audio' && audioState.status === 'installing'}
            <div class="install-progress-wrap">
              <div class="install-track"><div class="install-indet"></div></div>
              <span class="install-progress-msg">{installMsg}</span>
            </div>
          {:else if audioState.status === 'failed' && audioState.error}
            <div class="install-error">
              <span>{audioState.error.split('\n')[0]}</span>
              <button
                class="install-btn"
                onclick={() => installEngine('audio')}
                disabled={installing !== null}>{tr('retry')}</button
              >
            </div>
          {:else}
            <span class="cap-detail">{caps.optional.audio.note}</span>
          {/if}
        </div>
      </div>
      <p class="optional-note">{tr('optional_note')}</p>
    </section>
  {/if}
{/if}

<style>
  /* Loading / error states */
  .loading-state {
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    padding: var(--sp-6);
    color: var(--text-muted);
    font-size: 13px;
  }
  .spinner-sm {
    width: 16px;
    height: 16px;
    border: 2px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    flex-shrink: 0;
    animation: spin 0.7s linear infinite;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .spinner-sm {
      animation: none;
    }
  }
  .load-error {
    display: flex;
    align-items: center;
    gap: var(--sp-4);
    padding: var(--sp-4);
    font-size: 12px;
    color: var(--red);
    background: color-mix(in srgb, var(--red) 8%, var(--surface-1));
    border: 1px solid color-mix(in srgb, var(--red) 25%, transparent);
    border-radius: var(--radius-sm);
  }
  .retry-btn {
    background: var(--surface-2);
    border: 1px solid var(--border-strong);
    font-size: 11.5px;
    font-weight: 600;
    font-family: var(--font-ui);
    color: var(--text-primary);
    padding: 5px var(--sp-3);
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition:
      background var(--transition-fast),
      border-color var(--transition-fast);
  }
  .retry-btn:hover {
    background: var(--surface-3);
    border-color: var(--border-strong);
  }

  /* Section */
  .section {
    display: flex;
    flex-direction: column;
    gap: var(--sp-3);
  }
  .section-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-muted);
  }

  /* Runtime grid */
  .runtime-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1px;
    background: var(--divider);
    border: none;
    border-radius: var(--radius);
    overflow: hidden;
  }
  .runtime-item {
    background: var(--surface-1);
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: var(--sp-2) var(--sp-3);
  }
  .runtime-item.span2 {
    grid-column: span 2;
  }
  .runtime-label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
  }
  .runtime-value {
    font-size: 12px;
    color: var(--text-primary);
    font-family: var(--font-mono);
  }
  .runtime-value.ellipsis {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Capability list — elevation only, hairline rows */
  .cap-list {
    display: flex;
    flex-direction: column;
    gap: 0;
    background: var(--surface-2);
    border: none;
    border-radius: var(--radius);
    overflow: hidden;
  }
  .cap-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: 7px var(--sp-3);
    border-bottom: 1px solid var(--divider);
    transition: background var(--transition-fast);
  }
  .cap-row:last-child {
    border-bottom: none;
  }
  .cap-row.highlighted {
    background: color-mix(in srgb, var(--accent) 8%, var(--surface-1));
    animation: pulse-row 1.2s ease-out;
  }
  @keyframes pulse-row {
    0% {
      background: color-mix(in srgb, var(--accent) 20%, var(--surface-1));
    }
    100% {
      background: color-mix(in srgb, var(--accent) 8%, var(--surface-1));
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .cap-row.highlighted {
      animation: none;
    }
  }

  .dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .dot-green {
    background: var(--green);
  }
  .dot-amber {
    background: var(--amber);
  }
  .dot-red {
    background: var(--red);
  }

  .cap-label {
    font-size: 12px;
    color: var(--text-primary);
    flex: 1;
    min-width: 0;
  }
  .cap-exts {
    font-size: 10px;
    color: var(--text-muted);
    font-family: var(--font-mono);
    white-space: nowrap;
  }
  .cap-badge {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 99px;
    white-space: nowrap;
  }
  .badge-green {
    background: color-mix(in srgb, var(--green) 15%, transparent);
    color: var(--green);
  }
  .badge-amber {
    background: color-mix(in srgb, var(--amber) 15%, transparent);
    color: var(--amber);
  }
  .badge-red {
    background: color-mix(in srgb, var(--red) 15%, transparent);
    color: var(--red);
  }
  .cap-detail {
    font-size: 11px;
    color: var(--text-muted);
    font-family: var(--font-mono);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 180px;
  }
  .cap-detail-red {
    color: var(--red);
    font-family: var(--font-ui);
  }

  /* Optional engine install UI */
  .cap-row-wrap {
    flex-wrap: wrap;
    gap: var(--sp-2) var(--sp-2);
  }
  .install-btn {
    padding: 5px 12px;
    font-size: 11.5px;
    font-weight: 500;
    font-family: var(--font-ui);
    background: transparent;
    color: var(--text-primary);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    cursor: pointer;
    white-space: nowrap;
    transition: all var(--transition-fast);
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }
  .install-btn:hover:not(:disabled) {
    background: var(--surface-1);
    border-color: var(--border-strong);
  }
  .install-btn:disabled {
    opacity: 0.45;
    cursor: default;
  }
  .install-size {
    opacity: 0.75;
    font-weight: 400;
  }
  .install-progress-wrap {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 6px;
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--sp-2) var(--sp-3);
  }
  /* Install has no real percentage (uv pip install doesn't stream granular progress),
     so the bar is indeterminate — honest "working" feedback rather than a fake number. */
  .install-track {
    position: relative;
    height: 3px;
    background: var(--surface-2);
    border-radius: 99px;
    overflow: hidden;
  }
  .install-indet {
    position: absolute;
    top: 0;
    height: 100%;
    width: 35%;
    background: var(--accent);
    border-radius: 99px;
    animation: install-indet 1.1s ease-in-out infinite;
  }
  @keyframes install-indet {
    0% {
      left: -35%;
    }
    100% {
      left: 100%;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .install-indet {
      animation: none;
      left: 0;
      width: 100%;
      opacity: 0.45;
    }
  }
  .install-progress-msg {
    font-size: 11px;
    color: var(--text-muted);
  }
  .install-error {
    width: 100%;
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    font-size: 11px;
    color: var(--red);
    padding: var(--sp-1) 0;
  }
  .optional-note {
    font-size: 11px;
    color: var(--text-muted);
    padding: var(--sp-1) 0 0;
  }
</style>
