<script lang="ts">
  import type { BatchItemState } from './BatchQueueView.svelte';
  import { onDestroy } from 'svelte';

  let {
    items,
    onRetry,
    onClose,
    onOpen,
    onOpenFolder,
    cleanupApplied = false,
    cleanupChanges = 0,
  }: {
    items: BatchItemState[];
    onRetry: () => void;
    onClose: () => void;
    onOpen?: (item: BatchItemState) => void;
    onOpenFolder?: () => void;
    cleanupApplied?: boolean;
    cleanupChanges?: number;
  } = $props();

  const done = $derived(items.filter((i) => i.status === 'done').length);
  const failed = $derived(items.filter((i) => i.status === 'failed').length);
  const cancelled = $derived(items.filter((i) => i.status === 'cancelled').length);
  const warned = $derived(
    items.filter((i) => i.status === 'done' && (i.warnings?.length ?? 0) > 0).length,
  );
  const hasFailed = $derived(failed > 0);

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
  <!-- Stats row -->
  <div class="flex gap-3 flex-wrap flex-shrink-0">
    {#if done > 0}
      <span
        class="inline-flex items-baseline gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-800 bg-green-950/10"
      >
        <span class="text-lg font-bold font-mono text-green-400 leading-none">{done}</span>
        <span class="text-[10px] font-semibold text-zinc-400 uppercase tracking-wider"
          >converted</span
        >
      </span>
    {/if}
    {#if failed > 0}
      <span
        class="inline-flex items-baseline gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-800 bg-red-950/10"
      >
        <span class="text-lg font-bold font-mono text-red-400 leading-none">{failed}</span>
        <span class="text-[10px] font-semibold text-zinc-400 uppercase tracking-wider">failed</span>
      </span>
    {/if}
    {#if cancelled > 0}
      <span
        class="inline-flex items-baseline gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-800 bg-zinc-900/40"
      >
        <span class="text-lg font-bold font-mono text-zinc-400 leading-none">{cancelled}</span>
        <span class="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider"
          >cancelled</span
        >
      </span>
    {/if}
    {#if warned > 0}
      <span
        class="inline-flex items-baseline gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-800 bg-amber-950/10"
        title="Converted, but the file had no extractable content"
      >
        <span class="text-lg font-bold font-mono text-amber-400 leading-none">{warned}</span>
        <span class="text-[10px] font-semibold text-zinc-400 uppercase tracking-wider">notices</span
        >
      </span>
    {/if}
  </div>

  {#if cleanupApplied && done > 0}
    <div
      class="flex items-center gap-2 rounded-lg border border-blue-950/60 bg-blue-950/10 px-3.5 py-2.5 text-xs text-zinc-300 leading-normal flex-shrink-0"
    >
      <svg
        class="text-blue-400 flex-shrink-0"
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
        Cleanup applied to every converted file{cleanupChanges > 0
          ? ` — ${cleanupChanges.toLocaleString()} change${cleanupChanges === 1 ? '' : 's'} in total`
          : ''}.
      </span>
    </div>
  {/if}

  <!-- Results list -->
  <ul
    class="flex-1 overflow-y-auto bg-zinc-950/30 border border-zinc-800 rounded-lg divide-y divide-zinc-900/50"
    aria-label="Conversion results"
  >
    {#each items as item (item.id)}
      <li
        class="flex items-start gap-3 p-3 transition-colors hover:bg-zinc-900/25 {item.status ===
        'failed'
          ? 'bg-red-950/5'
          : ''} {item.status === 'cancelled' ? 'opacity-40' : ''}"
      >
        <!-- Status dot -->
        <span
          class="flex-shrink-0 w-2 h-2 rounded-full mt-2
          {item.status === 'done' && !item.warnings?.length ? 'bg-green-500' : ''}
          {item.status === 'done' && !!item.warnings?.length ? 'bg-amber-500' : ''}
          {item.status === 'failed' ? 'bg-red-500' : ''}
          {item.status === 'cancelled' || item.status === 'pending' ? 'bg-zinc-600' : ''}"
          aria-hidden="true"
        >
        </span>

        <!-- File info -->
        <div class="flex-1 min-w-0 flex flex-col gap-1">
          <span class="text-xs font-semibold text-zinc-200 truncate">{item.filename}</span>
          {#if item.status === 'done' && item.output_path}
            <span class="text-[10px] font-mono text-zinc-500 truncate" title={item.output_path}
              >→ {item.output_path}</span
            >
            {#if item.warnings?.length}
              <span class="text-[10px] text-amber-500 mt-0.5 leading-normal"
                >⚠ {item.warnings.join(' · ')}</span
              >
            {/if}
          {:else if item.status === 'failed' && item.error}
            <span class="text-[10px] text-red-400 mt-0.5 leading-normal"
              >{item.error.title} — {item.error.detail}</span
            >
          {:else if item.status === 'cancelled'}
            <span class="text-[10px] text-zinc-500 mt-0.5">Cancelled</span>
          {/if}
        </div>

        {#if item.status === 'done' && onOpen}
          <button
            class="flex-shrink-0 inline-flex items-center justify-center rounded-md text-[11px] font-semibold h-6 px-2.5 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors self-center ml-2"
            title="View the converted Markdown"
            onclick={() => onOpen?.(item)}>View</button
          >
        {/if}
      </li>
    {/each}
  </ul>

  <!-- Actions -->
  <div class="flex gap-2 items-center flex-wrap flex-shrink-0">
    {#if hasFailed}
      <button
        class="btn-primary btn-sm"
        title="Re-run only the files that failed, with the same settings"
        onclick={onRetry}
      >
        Retry {failed} failed file{failed === 1 ? '' : 's'}
      </button>
      <button
        class="btn-secondary btn-sm"
        title="Copy the list of failed files and their errors"
        onclick={copyFailures}
      >
        {copied ? 'Copied!' : 'Copy failures'}
      </button>
    {/if}
    {#if done > 0 && onOpenFolder}
      <button
        class="btn-secondary btn-sm"
        title="Reveal the converted files in your file manager"
        onclick={onOpenFolder}
      >
        Open folder
      </button>
    {/if}
    <button
      class="btn-secondary btn-sm"
      title="Clear this summary and start a new conversion"
      onclick={onClose}
    >
      Convert more files
    </button>
  </div>
</div>
