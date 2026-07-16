<script lang="ts" module>
  export interface DownloadDetail {
    label: string;
    received: number;
    total?: number | null;
    speed: number; // bytes per second
  }
  export interface ProvisionProgress {
    step: string;
    message: string;
    pct: number;
    detail?: DownloadDetail | null;
  }
</script>

<script lang="ts">
  import Stepper, { type Step } from '$lib/Stepper.svelte';
  import { tr } from './locale.svelte';

  let { progress }: { progress: ProvisionProgress } = $props();

  const STEPS = $derived<Step[]>([
    { title: tr('step_tools'), description: tr('step_tools_desc') },
    { title: tr('step_python'), description: tr('step_python_desc') },
    { title: tr('step_packages'), description: tr('step_packages_desc') },
  ]);

  // Map the backend step key onto the stepper index.
  const STEP_INDEX: Record<string, number> = {
    downloading_uv: 0,
    creating_env: 1,
    installing_packages: 2,
    done: 3,
  };

  let current = $derived(STEP_INDEX[progress.step] ?? 0);
  let done = $derived(progress.step === 'done' || progress.pct >= 1);
  let detail = $derived(progress.detail ?? null);
  // A determinate bar only when we know the total size (the uv download). Other
  // steps are driven by uv and report no byte totals, so they stay indeterminate.
  let hasTotal = $derived(!!detail && typeof detail.total === 'number' && detail.total! > 0);
  let frac = $derived(hasTotal ? Math.min(1, detail!.received / detail!.total!) : 0);

  const PACKAGES = $derived([
    { name: tr('pkg_markitdown'), note: tr('pkg_markitdown_note') },
    { name: tr('pkg_formats'), note: tr('pkg_formats_note') },
    { name: tr('pkg_openai'), note: tr('pkg_openai_note') },
  ]);

  function formatBytes(n: number): string {
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
    if (n < 1024 * 1024 * 1024) return `${(n / (1024 * 1024)).toFixed(1)} MB`;
    return `${(n / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }
  function formatSpeed(bps: number): string {
    if (bps <= 0) return '';
    if (bps < 1024 * 1024) return `${(bps / 1024).toFixed(0)} KB/s`;
    return `${(bps / (1024 * 1024)).toFixed(1)} MB/s`;
  }

  let sizeText = $derived(
    detail
      ? hasTotal
        ? `${formatBytes(detail.received)} / ${formatBytes(detail.total!)}`
        : detail.received > 0
          ? formatBytes(detail.received)
          : ''
      : '',
  );
  let speedText = $derived(detail ? formatSpeed(detail.speed) : '');
</script>

<div
  class="flex-1 flex flex-col items-center justify-center gap-6 w-full max-w-[500px] self-center py-8"
>
  <header class="text-center select-none">
    <h1 class="text-lg font-bold text-zinc-50">{tr('setup_title')}</h1>
    <p class="text-xs text-zinc-400 mt-1">{tr('setup_subtitle')}</p>
  </header>

  <Stepper steps={STEPS} {current} {done} />

  <div class="panel w-full p-5 flex flex-col gap-3.5 select-text" aria-live="polite">
    <p class="text-xs font-semibold text-zinc-200">
      {done ? tr('setup_complete') : progress.message}
    </p>

    {#if detail && !done}
      <p class="text-[10px] font-mono text-zinc-400 break-all leading-normal">{detail.label}</p>
    {/if}

    {#if hasTotal && !done}
      <div
        class="h-2 bg-[var(--surface-2)] rounded-full overflow-hidden"
        role="progressbar"
        aria-valuenow={Math.round(frac * 100)}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div
          class="h-full progress-fill rounded-full transition-all duration-150"
          style="width: {frac * 100}%"
        ></div>
      </div>
    {:else if !done}
      <div
        class="h-2 bg-[var(--surface-2)] rounded-full overflow-hidden relative"
        role="progressbar"
        aria-busy="true"
        aria-label={progress.message}
      >
        <div
          class="shimmer-fill animate-indeterminate absolute h-full w-[45%] progress-fill rounded-full"
        ></div>
      </div>
    {/if}

    {#if !done && (sizeText || speedText)}
      <div class="flex items-center gap-4 text-[10px] text-zinc-400 font-mono select-none">
        {#if sizeText}<span>{sizeText}</span>{/if}
        {#if hasTotal}<span>{Math.round(frac * 100)}%</span>{/if}
        {#if speedText}<span class="speed-text font-semibold ml-auto">↓ {speedText}</span>{/if}
      </div>
    {/if}

    {#if current === 2 && !done}
      <ul class="flex flex-col gap-2 pt-3.5 mt-1.5 hairline-t list-none select-none">
        {#each PACKAGES as p}
          <li class="flex items-baseline gap-2 text-xs">
            <span class="font-semibold text-zinc-200">{p.name}</span>
            <span class="text-[10px] text-zinc-500">{p.note}</span>
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <p class="text-[11px] text-zinc-500 select-none">{tr('setup_footer')}</p>
</div>

<style>
  .progress-fill {
    background: var(--accent);
  }
  .speed-text {
    color: var(--accent);
  }
  .animate-indeterminate {
    animation: indeterminate 1.5s ease-in-out infinite;
  }
  @keyframes indeterminate {
    0% {
      transform: translateX(-120%);
    }
    100% {
      transform: translateX(260%);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .shimmer-fill {
      animation: none;
      width: 100%;
      opacity: 0.35;
    }
  }
</style>
