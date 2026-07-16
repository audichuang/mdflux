<script lang="ts">
  import { tr } from './locale.svelte';

  let {
    mode = 'off',
    onModeChange,
  }: {
    mode?: string;
    onModeChange?: (m: string) => void;
  } = $props();

  const MODES = [
    { id: 'off', labelKey: 'mode_off', tipKey: 'mode_off_tip' },
    { id: 'local', labelKey: 'mode_local', tipKey: 'mode_local_tip' },
    { id: 'api', labelKey: 'mode_api', tipKey: 'mode_api_tip' },
  ] as const;
</script>

<div class="flex items-center gap-3 select-none" title={tr('intelligence')}>
  <span class="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mode-label"
    >{tr('intelligence')}</span
  >
  <div class="seg" aria-label={tr('intelligence')} role="group">
    {#each MODES as m}
      <button
        class="seg-btn"
        class:active={mode === m.id}
        title={tr(m.tipKey)}
        aria-pressed={mode === m.id}
        onclick={() => onModeChange?.(m.id)}
      >
        {tr(m.labelKey)}
      </button>
    {/each}
  </div>
</div>

<style>
  @media (max-width: 1100px) {
    .mode-label {
      display: none;
    }
  }
</style>
