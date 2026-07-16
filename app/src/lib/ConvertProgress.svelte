<script lang="ts">
  import { tr } from './locale.svelte';

  let {
    stage = 'converting',
    sourceName = '',
    onCancel,
  }: {
    stage?: string;
    sourceName?: string;
    onCancel: () => void;
  } = $props();

  const STAGE_KEYS: Record<string, string> = {
    downloading: 'stage_downloading',
    preflight: 'stage_preflight',
    extracting: 'stage_extracting',
    formatting: 'stage_formatting',
  };

  let cancelPending = $state(false);

  function handleCancel() {
    cancelPending = true;
    onCancel();
  }

  const stageLabel = $derived(tr(STAGE_KEYS[stage] ?? 'stage_converting'));
</script>

<div class="flex-1 flex flex-col items-center justify-center gap-5">
  {#if sourceName}
    <p class="text-xs font-mono text-zinc-500 max-w-[min(420px,90vw)] truncate" title={sourceName}>
      {sourceName}
    </p>
  {/if}
  <p class="text-sm font-semibold text-zinc-300 min-h-[1.4em]">
    {stageLabel}
  </p>

  <div
    class="w-full max-w-[280px] h-2 bg-[var(--surface-2)] rounded-full overflow-hidden"
    role="progressbar"
    aria-label={tr('conversion_progress')}
    aria-busy="true"
  >
    <div class="fill h-full rounded-full"></div>
  </div>

  <button
    class="btn-secondary btn-sm"
    onclick={handleCancel}
    disabled={cancelPending}
    aria-label={tr('cancel_conversion')}
  >
    {cancelPending ? tr('cancelling') : tr('cancel')}
  </button>
</div>

<style>
  .fill {
    background: var(--accent);
    transform-origin: left center;
    animation: indeterminate 1.6s ease-in-out infinite;
  }

  @keyframes indeterminate {
    0% {
      transform: translateX(-100%) scaleX(0.4);
    }
    50% {
      transform: translateX(60%) scaleX(0.6);
    }
    100% {
      transform: translateX(200%) scaleX(0.4);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .fill {
      animation: none;
      width: 100%;
      opacity: 0.35;
    }
  }
</style>
