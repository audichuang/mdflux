<script lang="ts">
  let {
    stage = 'converting',
    onCancel,
  }: {
    stage?: string;
    onCancel: () => void;
  } = $props();

  const STAGE_LABELS: Record<string, string> = {
    downloading: 'Downloading from the cloud…',
    preflight: 'Checking file…',
    extracting: 'Extracting content…',
    formatting: 'Finishing up…',
  };

  let cancelPending = $state(false);

  function handleCancel() {
    cancelPending = true;
    onCancel();
  }
</script>

<div class="flex-1 flex flex-col items-center justify-center gap-5">
  <p class="text-sm font-semibold text-zinc-300 min-h-[1.4em]">
    {STAGE_LABELS[stage] ?? 'Converting…'}
  </p>

  <div
    class="w-full max-w-[280px] h-2 bg-[var(--surface-2)] rounded-full overflow-hidden"
    role="progressbar"
    aria-label="Conversion in progress"
    aria-busy="true"
  >
    <div class="fill h-full bg-blue-500 rounded-full"></div>
  </div>

  <button
    class="btn-secondary btn-sm"
    onclick={handleCancel}
    disabled={cancelPending}
    aria-label="Cancel conversion"
  >
    {cancelPending ? 'Cancelling…' : 'Cancel'}
  </button>
</div>

<style>
  .fill {
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
