<script lang="ts">
  import { onMount } from 'svelte';
  import { listen } from '@tauri-apps/api/event';
  import { open } from '@tauri-apps/plugin-dialog';
  import type { ConvertError } from './ErrorCard.svelte';
  import ErrorCard from './ErrorCard.svelte';
  import { SUPPORTED_EXTS } from './formats';
  import { tr } from './locale.svelte';
  let {
    onAdd,
    error = null,
    onDismissError,
    onOpenDiagnostics,
  }: {
    onAdd: (paths: string[]) => void;
    error?: ConvertError | null;
    onDismissError?: () => void;
    onOpenDiagnostics?: (key: string) => void;
  } = $props();

  type LocalState = 'idle' | 'drag-hover';
  let localState = $state<LocalState>('idle');
  let dropState = $derived(error ? 'error' : localState);

  onMount(() => {
    let unlistenDrop: (() => void) | undefined;
    let unlistenEnter: (() => void) | undefined;
    let unlistenLeave: (() => void) | undefined;
    let dead = false;

    listen<{ paths: string[] }>('tauri://drag-drop', (e) => {
      localState = 'idle';
      const paths = e.payload.paths ?? [];
      if (paths.length) onAdd(paths);
    }).then((fn) => {
      if (dead) fn();
      else unlistenDrop = fn;
    });

    listen('tauri://drag-enter', () => {
      localState = 'drag-hover';
    }).then((fn) => {
      if (dead) fn();
      else unlistenEnter = fn;
    });

    listen('tauri://drag-leave', () => {
      if (localState === 'drag-hover') localState = 'idle';
    }).then((fn) => {
      if (dead) fn();
      else unlistenLeave = fn;
    });

    return () => {
      dead = true;
      unlistenDrop?.();
      unlistenEnter?.();
      unlistenLeave?.();
    };
  });

  async function browse() {
    if (error) return;
    const selected = await open({
      multiple: true,
      filters: [
        { name: tr('supported_files'), extensions: SUPPORTED_EXTS },
        { name: tr('all_files'), extensions: ['*'] },
      ],
    });
    if (!selected) return;
    const paths = Array.isArray(selected) ? (selected as string[]) : [selected as string];
    if (paths.length) onAdd(paths);
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      browse();
    }
  }
</script>

<div
  class="flex-1 relative rounded-[var(--radius-lg)] bg-[var(--surface-2)]/40 hover:bg-[var(--surface-2)]/70 transition-all duration-300 cursor-pointer outline-none flex items-center justify-center overflow-hidden min-h-[320px] group {localState ===
  'drag-hover'
    ? 'bg-[color-mix(in_srgb,var(--accent)_8%,var(--surface-2))]'
    : ''} {dropState === 'error' ? 'cursor-default drop-error-bg' : ''}"
  role="button"
  tabindex={0}
  aria-label={tr('drop_aria')}
  title={tr('drop_title')}
  onclick={browse}
  onkeydown={onKeyDown}
>
  <div
    class="border-ring"
    aria-hidden="true"
    class:ring-hover={localState === 'drag-hover'}
    class:ring-error={dropState === 'error'}
  ></div>

  {#if dropState === 'error' && error}
    <div
      class="relative w-full max-w-lg p-6 flex flex-col items-stretch cursor-default"
      role="presentation"
      onclick={(e) => e.stopPropagation()}
    >
      <ErrorCard {error} onDismiss={onDismissError ?? (() => {})} {onOpenDiagnostics} />
    </div>
  {:else}
    <div class="relative flex flex-col items-center gap-3.5 p-8 text-center select-none">
      <div
        class="text-zinc-500 group-hover:text-[var(--accent)] group-focus:text-[var(--accent)] transition-colors duration-300 mb-1"
        aria-hidden="true"
      >
        <svg
          width="36"
          height="36"
          viewBox="0 0 32 32"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M16 4v16M9 13l7-7 7 7"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M5 24h22"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            opacity=".4"
          />
          <path
            d="M5 28h12"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            opacity=".25"
          />
        </svg>
      </div>
      <p class="text-[length:var(--font-size-xs)] text-zinc-500 tracking-wide">
        {tr('drop_tagline')}
      </p>
      <p class="text-sm font-semibold text-zinc-200">{tr('drop_files')}</p>
      <p class="text-xs text-zinc-400">
        {tr('or')}
        <span
          class="text-[var(--accent)] group-hover:text-[var(--accent-hover)] underline underline-offset-2 transition-colors"
          >{tr('browse_choose')}</span
        >
      </p>
      <p
        class="text-[length:var(--font-size-2xs)] font-mono tracking-wider text-zinc-500 mt-2.5 uppercase"
      >
        {tr('supported_formats')}
      </p>
      <p
        class="text-[length:var(--font-size-2xs)] text-zinc-500 mt-1 max-w-[var(--measure-progress)] leading-relaxed"
      >
        {tr('drop_folder_hint')}
      </p>
      <p class="text-[length:var(--font-size-2xs)] text-zinc-600 mt-0.5">
        {tr('shortcut_open')}
      </p>
    </div>
  {/if}
</div>

<style>
  .drop-error-bg {
    background: color-mix(in srgb, var(--red) 5%, transparent);
  }
  .border-ring {
    position: absolute;
    inset: 0;
    border-radius: var(--radius-lg);
    padding: 1px;
    background: conic-gradient(
      from var(--angle, 0deg),
      var(--accent),
      transparent 30%,
      transparent 70%,
      var(--accent)
    );
    -webkit-mask:
      linear-gradient(#fff 0 0) content-box,
      linear-gradient(#fff 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    opacity: 0.15;
    transition: opacity var(--transition);
    animation: rotate-ring 6s linear infinite;
  }

  :global(.group:hover) .border-ring,
  .ring-hover {
    opacity: 0.65;
    animation-duration: 2.5s;
  }

  .ring-error {
    background: conic-gradient(
      from var(--angle, 0deg),
      var(--red),
      transparent 40%,
      transparent 60%,
      var(--red)
    ) !important;
    opacity: 0.35;
    animation: none;
  }

  @keyframes rotate-ring {
    to {
      --angle: 360deg;
    }
  }
  @property --angle {
    syntax: '<angle>';
    inherits: false;
    initial-value: 0deg;
  }
  @media (prefers-reduced-motion: reduce) {
    .border-ring {
      animation: none;
    }
  }
</style>
