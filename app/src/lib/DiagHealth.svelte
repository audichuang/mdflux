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
      <span class="error-text">{tr('caps_load_error', { error: capsError })}</span>
      <button class="btn-secondary btn-sm" onclick={loadCaps}>{tr('retry')}</button>
    </div>
  {:else if caps}
    <section class="section">
      <h2 class="section-title">{tr('section_runtime')}</h2>
      <div class="runtime-grid panel-inset">
        <div class="runtime-item hairline-b">
          <span class="runtime-label">{tr('label_python')}</span>
          <span class="runtime-value">{caps.runtime.python_version}</span>
        </div>
        <div class="runtime-item hairline-b">
          <span class="runtime-label">{tr('label_markitdown')}</span>
          <span class="runtime-value">{caps.runtime.markitdown_version}</span>
        </div>
        <div class="runtime-item hairline-b">
          <span class="runtime-label">{tr('label_sidecar')}</span>
          <span class="runtime-value">{caps.runtime.sidecar_version}</span>
        </div>
        <div class="runtime-item">
          <span class="runtime-label">{tr('label_venv')}</span>
          <span class="runtime-value mono ellipsis" title={caps.runtime.venv_path}
            >{caps.runtime.venv_path}</span
          >
        </div>
      </div>
    </section>

    <section class="section">
      <h2 class="section-title">{tr('section_formats')}</h2>
      <div class="cap-list panel-inset">
        {#each caps.formats as fmt}
          <div
            id="fmt-{fmt.key}"
            class="cap-row hairline-b"
            class:highlighted={highlight === fmt.key}
          >
            <span class="dot dot-{dotColor(fmt.status)}" aria-hidden="true"></span>
            <span class="cap-label">{fmt.label}</span>
            <span class="cap-exts">{fmt.extensions.join(' · ')}</span>
            <span class="cap-badge badge-{dotColor(fmt.status)}">{badgeLabel(fmt.status)}</span>
            {#if detailText(fmt)}
              <span
                class="cap-detail"
                class:cap-detail-red={fmt.status === 'missing' || fmt.status === 'broken'}
                title={detailText(fmt)}
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
      <div class="cap-list panel-inset">
        <div class="cap-row cap-row-wrap hairline-b">
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
              class="btn-secondary btn-sm"
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
              <span class="error-text">{ocrState.error.split('\n')[0]}</span>
              <button
                class="btn-secondary btn-sm"
                onclick={() => installEngine('ocr')}
                disabled={installing !== null}>{tr('retry')}</button
              >
            </div>
          {:else}
            <span class="cap-detail" title={caps.optional.ocr.note}>{caps.optional.ocr.note}</span>
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
              class="btn-secondary btn-sm"
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
              <span class="error-text">{audioState.error.split('\n')[0]}</span>
              <button
                class="btn-secondary btn-sm"
                onclick={() => installEngine('audio')}
                disabled={installing !== null}>{tr('retry')}</button
              >
            </div>
          {:else}
            <span class="cap-detail" title={caps.optional.audio.note}
              >{caps.optional.audio.note}</span
            >
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
    border: var(--stroke-strong) solid var(--border);
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
    font-size: var(--font-size-sm);
    color: var(--red);
    background: color-mix(in srgb, var(--red) 8%, var(--surface-1));
    border: var(--stroke-hairline) solid color-mix(in srgb, var(--red) 25%, transparent);
    border-radius: var(--radius-sm);
    flex-wrap: wrap;
  }
  .error-text {
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
  }
  .load-error > :global(button),
  .install-error > :global(button) {
    flex-shrink: 0;
  }

  /* Section */
  .section {
    display: flex;
    flex-direction: column;
    gap: var(--sp-3);
  }
  .section-title {
    font-size: var(--font-size-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-muted);
  }

  /* Runtime grid */
  .runtime-grid {
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
  .runtime-item {
    display: flex;
    align-items: baseline;
    gap: var(--sp-3);
    padding: var(--sp-2) var(--sp-3);
  }
  .runtime-item:last-child {
    border-bottom: none;
  }
  .runtime-label {
    font-size: var(--font-size-2xs);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    flex: 0 0 30%;
  }
  .runtime-value {
    font-size: var(--font-size-sm);
    color: var(--text-primary);
    font-family: var(--font-mono);
    min-width: 0;
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
    overflow: hidden;
  }
  .cap-row {
    display: grid;
    grid-template-columns:
      var(--indicator-sm) minmax(0, 1fr) auto auto
      minmax(0, 180px);
    align-items: center;
    gap: var(--sp-2);
    padding: var(--sp-2) var(--sp-3);
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
    width: var(--indicator-sm);
    height: var(--indicator-sm);
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
    font-size: var(--font-size-sm);
    color: var(--text-primary);
    flex: 1;
    min-width: 0;
  }
  .cap-exts {
    font-size: var(--font-size-2xs);
    color: var(--text-muted);
    font-family: var(--font-mono);
    white-space: nowrap;
  }
  .cap-badge {
    font-size: var(--font-size-2xs);
    font-weight: 500;
    padding: var(--stroke-hairline) var(--indicator-sm);
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
    font-size: var(--font-size-xs);
    color: var(--text-muted);
    font-family: var(--font-mono);
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .cap-detail-red {
    color: var(--red);
    font-family: var(--font-ui);
  }

  /* Optional engine install UI */
  .cap-row-wrap {
    row-gap: var(--sp-2);
  }
  .cap-row-wrap > .cap-detail {
    grid-column: 2 / -1;
    white-space: normal;
    overflow-wrap: anywhere;
  }
  .cap-row-wrap > :global(.btn-secondary) {
    grid-column: 5;
  }
  .install-size {
    opacity: 0.75;
    font-weight: 400;
  }
  .install-progress-wrap {
    grid-column: 2 / -1;
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: var(--control-gap);
    background: var(--surface-1);
    border: var(--stroke-hairline) solid var(--border);
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
    font-size: var(--font-size-xs);
    color: var(--text-muted);
  }
  .install-error {
    grid-column: 2 / -1;
    width: 100%;
    display: flex;
    align-items: center;
    gap: var(--sp-3);
    font-size: var(--font-size-xs);
    color: var(--red);
    padding: var(--sp-1) 0;
  }
  .optional-note {
    font-size: var(--font-size-xs);
    color: var(--text-muted);
    padding: var(--sp-1) 0 0;
  }

  @media (max-width: 700px) {
    .cap-row {
      grid-template-columns: var(--indicator-sm) minmax(0, 1fr) auto;
    }
    .cap-row > .dot {
      grid-column: 1;
      grid-row: 1;
    }
    .cap-label {
      grid-column: 2;
      grid-row: 1;
    }
    .cap-badge {
      grid-column: 3;
      grid-row: 1;
    }
    .cap-exts {
      grid-column: 2;
      grid-row: 2;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .cap-detail,
    .cap-row-wrap > .cap-detail,
    .install-progress-wrap,
    .install-error {
      grid-column: 2 / -1;
      white-space: normal;
      overflow-wrap: anywhere;
    }
    .cap-row-wrap > :global(.btn-secondary) {
      grid-column: 3;
      grid-row: 2;
    }
  }
</style>
