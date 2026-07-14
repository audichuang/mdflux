<script lang="ts">
  const MODE_LABELS: Record<string, string> = { off: 'Off', local: 'Local', api: 'API' };
  const MODE_TIPS: Record<string, string> = {
    off: 'No AI — fully offline. Only rule-based cleanup is available.',
    local: 'Use a local model (e.g. Ollama) for AI cleanup. Stays on your machine.',
    api: 'Use a cloud API model for AI cleanup. Sends text to your provider.',
  };

  let {
    mode = 'off',
    onModeChange,
  }: {
    mode?: string;
    onModeChange?: (m: string) => void;
  } = $props();
</script>

<div class="flex items-center gap-3 select-none" title="Intelligence mode">
  <span class="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider">Intelligence</span>
  <div class="seg" aria-label="Intelligence mode" role="group">
    {#each Object.keys(MODE_LABELS) as m}
      <button
        class="seg-btn"
        class:active={mode === m}
        title={MODE_TIPS[m]}
        onclick={() => onModeChange?.(m)}
      >
        {MODE_LABELS[m]}
      </button>
    {/each}
  </div>
</div>
