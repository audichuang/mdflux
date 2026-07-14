<script lang="ts">
  import type { ConvertError } from './ErrorCard.svelte';

  export interface BatchItemState {
    id: string;
    path: string;
    filename: string;
    status: string;
    frac: number | null;
    output_path: string | null;
    error: ConvertError | null;
    warnings?: string[];
  }

  let {
    items,
    phase,
    onCancel,
    onOpen,
  }: {
    items: BatchItemState[];
    phase: string;
    onCancel: () => void;
    onOpen?: (item: BatchItemState) => void;
  } = $props();

  const done = $derived(items.filter((i) => i.status === 'done').length);
  const failed = $derived(items.filter((i) => i.status === 'failed').length);
  const finished = $derived(
    items.filter((i) => i.status !== 'pending' && i.status !== 'running').length,
  );
  const total = $derived(items.length);
  const progress = $derived(total > 0 ? finished / total : 0);
  const isCancelling = $derived(phase === 'cancelling');

  const STATUS_LABELS: Record<string, string> = {
    pending: 'Queued',
    running: 'Converting…',
    done: 'Done',
    failed: 'Failed',
    cancelled: 'Cancelled',
  };
</script>

<div class="w-full max-w-2xl self-center py-6 px-1 flex flex-col gap-5 h-full min-h-0">
  <!-- Header -->
  <div class="flex flex-col gap-3 border-b border-zinc-800 pb-4 flex-shrink-0">
    <div class="flex items-baseline justify-between">
      <span class="text-sm font-semibold text-zinc-200"
        >Converting {total} file{total === 1 ? '' : 's'}</span
      >
      <span class="text-xs font-mono text-zinc-400"
        >{done} done{failed > 0 ? ` · ${failed} failed` : ''}</span
      >
    </div>

    <!-- Overall progress bar -->
    <div
      class="h-1 bg-zinc-900 rounded-full overflow-hidden"
      role="progressbar"
      aria-valuenow={Math.round(progress * 100)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label="Overall batch progress"
    >
      <div
        class="h-full bg-blue-500 rounded-full transition-all duration-300"
        style="width: {progress * 100}%"
      ></div>
    </div>

    <!-- Cancel -->
    <button
      class="self-end btn-danger btn-sm"
      onclick={onCancel}
      disabled={isCancelling}
      aria-label={isCancelling ? 'Cancelling…' : 'Cancel batch'}
      title="Stop the whole batch. Files already finished are kept."
    >
      {isCancelling ? 'Cancelling…' : 'Cancel'}
    </button>
  </div>

  <!-- File list -->
  <ul
    class="flex-1 overflow-y-auto bg-zinc-950/30 border border-zinc-800 rounded-lg divide-y divide-zinc-900/50"
    aria-label="Conversion queue"
  >
    {#each items as item (item.id)}
      <li
        class="flex items-start gap-3 p-3 transition-colors hover:bg-zinc-900/25 {item.status ===
        'failed'
          ? 'bg-red-950/5'
          : ''} {item.status === 'cancelled' ? 'opacity-40' : ''}"
      >
        <!-- Status icon -->
        <span
          class="flex-shrink-0 w-4 h-4 mt-0.5 flex items-center justify-center"
          aria-hidden="true"
        >
          {#if item.status === 'done'}
            <svg class="text-green-400" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle
                cx="7"
                cy="7"
                r="6"
                fill="rgba(34, 197, 94, 0.15)"
                stroke="currentColor"
                stroke-width="1"
              />
              <path
                d="M4.5 7l1.8 1.8L9.5 5"
                stroke="currentColor"
                stroke-width="1.3"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          {:else if item.status === 'failed'}
            <svg class="text-red-400" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle
                cx="7"
                cy="7"
                r="6"
                fill="rgba(239, 68, 68, 0.15)"
                stroke="currentColor"
                stroke-width="1"
              />
              <path
                d="M5 5l4 4M9 5l-4 4"
                stroke="currentColor"
                stroke-width="1.3"
                stroke-linecap="round"
              />
            </svg>
          {:else if item.status === 'cancelled'}
            <svg class="text-zinc-500" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="6" stroke="currentColor" stroke-width="1" />
              <path d="M5 7h4" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" />
            </svg>
          {:else if item.status === 'running'}
            <span
              class="w-3.5 h-3.5 border-1.5 border-zinc-800 border-t-blue-500 rounded-full animate-spin"
              aria-label="Converting"
            ></span>
          {:else}
            <svg class="text-zinc-850" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="6" stroke="currentColor" stroke-width="1" />
              <circle cx="7" cy="7" r="2" fill="currentColor" />
            </svg>
          {/if}
        </span>

        <!-- Filename + status -->
        <div class="flex-1 min-w-0 flex flex-col gap-1.5">
          <span class="text-xs font-semibold text-zinc-200 truncate">{item.filename}</span>

          {#if item.status === 'running' && item.frac !== null}
            <div
              class="h-1 bg-zinc-900 rounded-full overflow-hidden"
              role="progressbar"
              aria-valuenow={Math.round((item.frac ?? 0) * 100)}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <div
                class="h-full bg-blue-500 rounded-full transition-all duration-300"
                style="width: {(item.frac ?? 0) * 100}%"
              ></div>
            </div>
          {:else if item.status === 'running'}
            <div
              class="h-1 bg-zinc-900 rounded-full overflow-hidden relative"
              role="progressbar"
              aria-label="Converting"
            >
              <div
                class="shimmer-fill absolute inset-0 bg-gradient-to-r from-zinc-900 via-blue-500 to-zinc-900 bg-[size:200%_100%] animate-[shimmer_1.4s_infinite]"
              ></div>
            </div>
          {:else if item.status === 'failed' && item.error}
            <span class="text-[10px] text-red-400 truncate"
              >{item.error.title} — {item.error.detail}</span
            >
          {:else}
            <span class="text-[10px] text-zinc-500"
              >{STATUS_LABELS[item.status] ?? item.status}</span
            >
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
</div>

<style>
  @keyframes shimmer {
    to {
      background-position: -200% 0;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .shimmer-fill {
      animation: none;
      background: var(--border);
    }
  }
</style>
