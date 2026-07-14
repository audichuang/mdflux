<script lang="ts">
  import { tr } from './locale.svelte';

  const MODE_TIPS = $derived<Record<string, string>>({
    off: 'No AI — fully offline. Only rule-based cleanup is available.',
    local: 'Use a local model (e.g. Ollama) for AI cleanup. Stays on your machine.',
    api: 'Use a cloud API model for AI cleanup. Sends text to your provider.',
  });

  let {
    mode = 'off',
    onModeChange,
  }: {
    mode?: string;
    onModeChange?: (m: string) => void;
  } = $props();
</script>

<div class="flex items-center gap-3 select-none" title={tr('intelligence')}>
  <span class="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider"
    >{tr('intelligence')}</span
  >
  <div class="seg" aria-label={tr('intelligence')} role="group">
    {#each ['off', 'local', 'api'] as m}
      <button
        class="seg-btn"
        class:active={mode === m}
        title={MODE_TIPS[m]}
        onclick={() => onModeChange?.(m)}
      >
        {m === 'off'
          ? tr('off')
          : m === 'local'
            ? tr('rule_based') === 'Rule-based'
              ? 'Local'
              : '本機 AI'
            : 'API'}
      </button>
    {/each}
  </div>
</div>
