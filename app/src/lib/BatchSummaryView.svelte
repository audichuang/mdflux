<script lang="ts">
  import type { BatchItemState } from './BatchQueueView.svelte';
  import { onDestroy } from 'svelte';
  import { tr } from './locale.svelte';

  let {
    items,
    onRetry,
    onClose,
    onOpen,
    onOpenFolder,
    cleanupApplied = false,
    cleanupChanges = 0,
    phase = 'done',
  }: {
    items: BatchItemState[];
    onRetry: () => void;
    onClose: () => void;
    onOpen?: (item: BatchItemState) => void;
    onOpenFolder?: () => void;
    cleanupApplied?: boolean;
    cleanupChanges?: number;
    phase?: string;
  } = $props();

  const done = $derived(items.filter((i) => i.status === 'done').length);
  const failed = $derived(items.filter((i) => i.status === 'failed').length);
  const cancelled = $derived(items.filter((i) => i.status === 'cancelled').length);
  const warned = $derived(
    items.filter((i) => i.status === 'done' && (i.warnings?.length ?? 0) > 0).length,
  );
  const hasFailed = $derived(failed > 0);

  let filter = $state<'all' | 'failed'>('all');
  const visible = $derived(
    filter === 'failed' ? items.filter((i) => i.status === 'failed') : items,
  );

  let copied = $state(false);
  let copyTimer: ReturnType<typeof setTimeout>;
  onDestroy(() => clearTimeout(copyTimer));

  function copyFailures() {
    const text = items
      .filter((i) => i.status === 'failed')
      .map((i) => `${i.filename}: ${i.error?.detail ?? 'unknown error'}`)
      .join('\n');
    navigator.clipboard
      .writeText(text)
      .then(() => {
        clearTimeout(copyTimer);
        copied = true;
        copyTimer = setTimeout(() => (copied = false), 1800);
      })
      .catch(() => {
        copied = false;
      });
  }
</script>

<div class="w-full max-w-2xl self-center py-6 px-1 flex flex-col gap-5 h-full min-h-0">
  <div class="flex items-center justify-between gap-3 flex-wrap flex-shrink-0">
    <h2 class="text-sm font-semibold text-zinc-200">
      {phase === 'cancelled' ? tr('conv_cancelled_title') : tr('conv_complete')}
    </h2>
    {#if hasFailed}
      <div class="seg" role="group" aria-label={tr('filter_results')}>
        <button class="seg-btn" class:active={filter === 'all'} onclick={() => (filter = 'all')}
          >{tr('filter_all')}</button
        >
        <button
          class="seg-btn"
          class:active={filter === 'failed'}
          onclick={() => (filter = 'failed')}>{tr('filter_failed')}</button
        >
      </div>
    {/if}
  </div>

  <!-- Stats row -->
  <div class="flex gap-3 flex-wrap flex-shrink-0">
    {#if done > 0}
      <span class="stat-pill stat-ok">
        <span class="stat-n text-ok">{done}</span>
        <span class="stat-l">{tr('converted_label')}</span>
      </span>
    {/if}
    {#if failed > 0}
      <span class="stat-pill stat-err">
        <span class="stat-n text-err">{failed}</span>
        <span class="stat-l">{tr('failed_label')}</span>
      </span>
    {/if}
    {#if cancelled > 0}
      <span class="stat-pill stat-muted">
        <span class="stat-n text-zinc-400">{cancelled}</span>
        <span class="stat-l">{tr('cancelled_label')}</span>
      </span>
    {/if}
    {#if warned > 0}
      <span class="stat-pill stat-warn" title={tr('warn_empty_content')}>
        <span class="stat-n text-warn">{warned}</span>
        <span class="stat-l">{tr('notices_label')}</span>
      </span>
    {/if}
  </div>

  {#if cleanupApplied && done > 0}
    <div
      class="notice-bar flex items-center gap-2 rounded-xl px-3.5 py-2.5 text-xs text-zinc-300 leading-normal flex-shrink-0"
    >
      <svg
        class="text-accent flex-shrink-0"
        width="13"
        height="13"
        viewBox="0 0 14 14"
        fill="none"
        aria-hidden="true"
      >
        <path
          d="M2 7.5L5.5 11L12 3.5"
          stroke="currentColor"
          stroke-width="1.6"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
      <span>
        {tr('cleanup_batch_applied')}{cleanupChanges > 0
          ? cleanupChanges === 1
            ? tr('cleanup_batch_changes', { count: cleanupChanges })
            : tr('cleanup_batch_changes_plural', { count: cleanupChanges })
          : ''}.
      </span>
    </div>
  {/if}

  <ul
    class="panel-inset flex-1 overflow-y-auto divide-y divide-[var(--divider)]"
    aria-label={tr('conversion_results')}
  >
    {#each visible as item (item.id || item.path)}
      <li
        class="flex items-start gap-3 p-3 transition-colors row-hover {item.status === 'failed'
          ? 'row-failed'
          : ''} {item.status === 'cancelled' ? 'opacity-40' : ''}"
      >
        <span
          class="flex-shrink-0 w-2 h-2 rounded-full mt-2
          {item.status === 'done' && !item.warnings?.length ? 'dot-ok' : ''}
          {item.status === 'done' && !!item.warnings?.length ? 'dot-warn' : ''}
          {item.status === 'failed' ? 'dot-err' : ''}
          {item.status === 'cancelled' || item.status === 'pending' ? 'dot-muted' : ''}"
          aria-hidden="true"
        >
        </span>

        <div class="flex-1 min-w-0 flex flex-col gap-1">
          <span class="text-xs font-semibold text-zinc-200 truncate">{item.filename}</span>
          {#if item.status === 'done' && item.output_path}
            <span class="text-[10px] font-mono text-zinc-500 truncate" title={item.output_path}
              >→ {item.output_path}</span
            >
            {#if item.warnings?.length}
              <span class="text-[10px] text-warn mt-0.5 leading-normal"
                >⚠ {item.warnings.join(' · ')}</span
              >
            {/if}
          {:else if item.status === 'failed' && item.error}
            <span class="text-[10px] text-err mt-0.5 leading-normal"
              >{item.error.title} — {item.error.detail}</span
            >
          {:else if item.status === 'cancelled'}
            <span class="text-[10px] text-zinc-500 mt-0.5">{tr('cancelled')}</span>
          {/if}
        </div>

        {#if item.status === 'done' && onOpen}
          <button
            class="btn-secondary btn-sm flex-shrink-0 self-center ml-2"
            title={tr('view_md')}
            onclick={(e) => {
              e.stopPropagation();
              onOpen?.(item);
            }}>{tr('view_btn')}</button
          >
        {/if}
      </li>
    {/each}
  </ul>

  <div class="flex gap-2 items-center flex-wrap flex-shrink-0">
    {#if hasFailed}
      <button
        class="btn-primary btn-sm"
        title={tr('retry_failed_plural', { count: failed })}
        onclick={onRetry}
      >
        {failed === 1
          ? tr('retry_failed', { count: failed })
          : tr('retry_failed_plural', { count: failed })}
      </button>
      <button class="btn-secondary btn-sm" title={tr('copy_failures')} onclick={copyFailures}>
        {copied ? tr('copied') : tr('copy_failures')}
      </button>
    {/if}
    {#if done > 0 && onOpenFolder}
      <button class="btn-secondary btn-sm" title={tr('reveal_folder_desc')} onclick={onOpenFolder}>
        {tr('open_folder')}
      </button>
    {/if}
    <button class="btn-secondary btn-sm" title={tr('convert_more')} onclick={onClose}>
      {tr('convert_more')}
    </button>
  </div>
</div>

<style>
  .stat-pill {
    display: inline-flex;
    align-items: baseline;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 999px;
  }
  .stat-ok {
    background: color-mix(in srgb, var(--green) 12%, transparent);
  }
  .stat-err {
    background: color-mix(in srgb, var(--red) 12%, transparent);
  }
  .stat-warn {
    background: color-mix(in srgb, var(--amber) 12%, transparent);
  }
  .stat-muted {
    background: var(--surface-2);
  }
  .stat-n {
    font-size: 18px;
    font-weight: 700;
    font-family: var(--font-mono);
    line-height: 1;
  }
  .stat-l {
    font-size: 10px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .text-ok {
    color: var(--green);
  }
  .text-err {
    color: var(--red);
  }
  .text-warn {
    color: var(--amber);
  }
  .text-accent {
    color: var(--accent);
  }
  .dot-ok {
    background: var(--green);
  }
  .dot-err {
    background: var(--red);
  }
  .dot-warn {
    background: var(--amber);
  }
  .dot-muted {
    background: var(--text-muted);
  }
  .notice-bar {
    background: color-mix(in srgb, var(--accent) 10%, transparent);
  }
  .row-hover:hover {
    background: color-mix(in srgb, var(--text-primary) 3%, transparent);
  }
  .row-failed {
    background: color-mix(in srgb, var(--red) 5%, transparent);
  }
</style>
