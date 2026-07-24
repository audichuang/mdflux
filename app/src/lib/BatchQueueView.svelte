<script lang="ts">
  import type { ConvertError } from './ErrorCard.svelte';
  import { tr } from './locale.svelte';

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

  // Static status→i18n-key map (tr() resolves live per locale at the call site).
  const STATUS_KEYS: Record<string, string> = {
    pending: 'queued',
    running: 'converting',
    done: 'done',
    failed: 'failed',
    cancelled: 'cancelled',
  };
  function statusLabel(status: string): string {
    return tr(STATUS_KEYS[status] ?? status);
  }
</script>

<div class="w-full max-w-2xl self-center py-6 px-1 flex flex-col gap-5 h-full min-h-0">
  <!-- Header -->
  <div class="flex flex-col gap-3 hairline-b pb-4 flex-shrink-0">
    <div class="flex items-baseline justify-between">
      <span class="text-sm font-semibold text-zinc-200">
        {total === 1
          ? tr('converting_n', { count: total })
          : tr('converting_n_plural', { count: total })}
      </span>
      <span class="text-xs font-mono text-zinc-400">
        {tr('done_count', { count: done })}{failed > 0
          ? ` · ${tr('failed_count', { count: failed })}`
          : ''}
      </span>
    </div>

    <div
      class="h-2 bg-[var(--surface-2)] rounded-full overflow-hidden"
      role="progressbar"
      aria-valuenow={Math.round(progress * 100)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={tr('overall_progress')}
    >
      <div
        class="h-full progress-fill rounded-full transition-all duration-300"
        style="width: {progress * 100}%"
      ></div>
    </div>

    <button
      class="self-end btn-danger btn-sm"
      onclick={onCancel}
      disabled={isCancelling}
      aria-label={isCancelling ? tr('cancelling') : tr('cancel_batch')}
      title={tr('stop_batch_hint')}
    >
      {isCancelling ? tr('cancelling') : tr('cancel')}
    </button>
  </div>

  <ul class="panel-inset flex-1 overflow-y-auto" aria-label={tr('conversion_queue')}>
    {#each items as item (item.id || item.path)}
      <li
        class="hairline-b flex items-start gap-3 p-3 transition-colors row-hover {item.status ===
        'failed'
          ? 'row-failed'
          : ''}"
      >
        <span
          class="flex-shrink-0 w-4 h-4 mt-0.5 flex items-center justify-center"
          aria-hidden="true"
        >
          {#if item.status === 'done'}
            <svg class="icon-ok" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle
                cx="7"
                cy="7"
                r="6"
                fill="color-mix(in srgb, var(--green) 15%, transparent)"
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
            <svg class="icon-err" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle
                cx="7"
                cy="7"
                r="6"
                fill="color-mix(in srgb, var(--red) 15%, transparent)"
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
            <span class="spinner" aria-label={tr('converting')}></span>
          {:else}
            <svg class="text-zinc-500" width="14" height="14" viewBox="0 0 14 14" fill="none">
              <circle cx="7" cy="7" r="6" stroke="currentColor" stroke-width="1" />
              <circle cx="7" cy="7" r="2" fill="currentColor" />
            </svg>
          {/if}
        </span>

        <div class="flex-1 min-w-0 flex flex-col gap-1.5">
          <span
            class="text-xs font-semibold truncate {item.status === 'cancelled'
              ? 'text-zinc-400'
              : 'text-zinc-200'}"
            title={item.path}>{item.filename}</span
          >

          {#if item.status === 'running' && item.frac !== null}
            <div
              class="h-1.5 bg-[var(--surface-2)] rounded-full overflow-hidden"
              role="progressbar"
              aria-valuenow={Math.round((item.frac ?? 0) * 100)}
              aria-valuemin={0}
              aria-valuemax={100}
            >
              <div
                class="h-full progress-fill rounded-full transition-all duration-300"
                style="width: {(item.frac ?? 0) * 100}%"
              ></div>
            </div>
          {:else if item.status === 'running'}
            <div
              class="h-1.5 bg-[var(--surface-2)] rounded-full overflow-hidden relative"
              role="progressbar"
              aria-label={tr('converting')}
            >
              <div class="shimmer-fill absolute inset-0"></div>
            </div>
          {:else if item.status === 'failed' && item.error}
            <span
              class="text-[length:var(--font-size-2xs)] text-err truncate"
              title="{item.error.title} — {item.error.detail}"
              >{item.error.title} — {item.error.detail}</span
            >
          {:else}
            <span class="text-[length:var(--font-size-2xs)] text-zinc-500"
              >{statusLabel(item.status)}</span
            >
          {/if}
        </div>

        {#if item.status === 'done' && onOpen}
          <button
            class="btn-secondary btn-sm flex-shrink-0 self-center"
            title={tr('view_md')}
            onclick={() => onOpen?.(item)}>{tr('view_btn')}</button
          >
        {/if}
      </li>
    {/each}
  </ul>
</div>

<style>
  /* .hairline-b is unlayered; a layered `last:border-b-0` utility can't cancel
     it, so strip the trailing row border with a scoped rule instead. */
  li:last-child {
    border-bottom: none;
  }
  .progress-fill {
    background: var(--accent);
  }
  .icon-ok {
    color: var(--green);
  }
  .icon-err,
  .text-err {
    color: var(--red);
  }
  .row-hover:hover {
    background: color-mix(in srgb, var(--text-primary) 3%, transparent);
  }
  .row-failed {
    background: color-mix(in srgb, var(--red) 5%, transparent);
  }
  .spinner {
    width: 14px;
    height: 14px;
    border: 1.5px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }
  .shimmer-fill {
    background: linear-gradient(
      90deg,
      transparent,
      color-mix(in srgb, var(--accent) 55%, transparent),
      transparent
    );
    background-size: 200% 100%;
    animation: shimmer 1.4s infinite;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
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
    .spinner {
      animation: none;
      opacity: 0.5;
    }
  }
</style>
