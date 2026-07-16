<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { renderMarkdown } from './mdpreview';
  import { onDestroy } from 'svelte';
  import { tr } from './locale.svelte';

  let {
    name,
    markdown,
    path = '',
    onBack,
  }: {
    name: string;
    markdown: string;
    path?: string;
    onBack: () => void;
  } = $props();

  let view = $state<'preview' | 'source'>('preview');
  const previewHtml = $derived(view === 'preview' ? renderMarkdown(markdown) : '');

  let copyFlash = $state<'idle' | 'copied' | 'failed'>('idle');
  let copyTimer: ReturnType<typeof setTimeout>;
  let revealError = $state<string | null>(null);
  onDestroy(() => clearTimeout(copyTimer));

  async function copy() {
    try {
      await navigator.clipboard.writeText(markdown);
      clearTimeout(copyTimer);
      copyFlash = 'copied';
      copyTimer = setTimeout(() => (copyFlash = 'idle'), 1800);
    } catch {
      copyFlash = 'failed';
      copyTimer = setTimeout(() => (copyFlash = 'idle'), 1800);
    }
  }

  async function reveal() {
    if (!path) return;
    revealError = null;
    try {
      await invoke('open_folder', { path });
    } catch (e) {
      revealError = tr('reveal_failed', { error: String(e) });
    }
  }

  function onPreviewClick(e: MouseEvent) {
    const a = (e.target as HTMLElement)?.closest('a');
    if (a) e.preventDefault();
  }
</script>

<div class="doc-shell flex-1 flex flex-col min-h-0">
  <div class="doc-chrome flex items-center gap-3 px-5 py-3 hairline-b flex-shrink-0">
    <button class="btn-secondary btn-sm" onclick={onBack} title={tr('back')}>
      <svg width="12" height="12" viewBox="0 0 14 14" fill="none" aria-hidden="true">
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
    <span class="flex-1 min-w-0 text-xs font-semibold text-zinc-300 truncate" title={name}
      >{name}</span
    >

    <div class="seg" role="group" aria-label={tr('preview')}>
      <button
        class="seg-btn"
        class:active={view === 'preview'}
        title={tr('preview')}
        onclick={() => (view = 'preview')}>{tr('preview')}</button
      >
      <button
        class="seg-btn"
        class:active={view === 'source'}
        title={tr('source')}
        onclick={() => (view = 'source')}>{tr('source')}</button
      >
    </div>

    {#if path}
      <button class="btn-secondary btn-sm" onclick={reveal} title={tr('reveal_in_folder')}>
        {tr('reveal_in_folder')}
      </button>
    {/if}

    <button class="btn-secondary btn-sm" onclick={copy} title={tr('copy')}>
      {copyFlash === 'copied'
        ? tr('copied')
        : copyFlash === 'failed'
          ? tr('failed_short')
          : tr('copy')}
    </button>
  </div>

  {#if revealError}
    <p class="text-xs text-err px-5 py-2 flex-shrink-0" role="alert">{revealError}</p>
  {/if}

  <div
    class="doc-scroll flex-1 overflow-y-auto min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-[color-mix(in_srgb,var(--accent)_60%,transparent)]"
    tabindex="0"
    role="region"
    aria-label={tr('document')}
  >
    {#if view === 'preview'}
      <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
      <div class="md-preview doc-col" onclick={onPreviewClick}>
        {@html previewHtml}
      </div>
    {:else}
      <pre
        class="font-mono text-xs leading-relaxed text-zinc-300 whitespace-pre-wrap break-all select-text m-0 doc-col">{markdown}</pre>
    {/if}
  </div>
</div>

<style>
  .doc-shell,
  .doc-chrome {
    background: transparent;
  }
  .doc-scroll {
    background: transparent;
    padding: 24px clamp(20px, 3vw, 40px) 40px;
  }
  .doc-col {
    max-width: min(72rem, 100%);
    margin: 0 auto;
    width: 100%;
  }
  .text-err {
    color: var(--red);
  }

  @media (min-width: 1600px) {
    .doc-col {
      max-width: min(80rem, 100%);
    }
  }
</style>
