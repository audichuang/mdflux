<script lang="ts">
  export interface ConvertError {
    code: string;
    title: string;
    detail: string;
    suggested_action: string;
    diagnostics_key?: string;
  }

  let {
    error,
    onDismiss,
    onOpenDiagnostics,
  }: {
    error: ConvertError;
    onDismiss: () => void;
    onOpenDiagnostics?: (key: string) => void;
  } = $props();
</script>

<div
  class="bg-red-950/10 border border-red-900/30 rounded-lg p-4 flex flex-col gap-2 select-text"
  role="alert"
>
  <div class="flex items-center gap-2 select-none">
    <span class="text-xs font-bold text-red-400 flex-shrink-0" aria-hidden="true">✕</span>
    <span class="text-xs font-semibold text-zinc-100 flex-1">{error.title}</span>
    <button
      class="text-zinc-500 hover:text-zinc-200 cursor-pointer text-xs px-1 border-none bg-transparent"
      onclick={onDismiss}
      aria-label="Dismiss error">✕</button
    >
  </div>
  <p class="text-xs text-zinc-300 leading-relaxed">{error.detail}</p>
  <div class="flex items-baseline justify-between gap-4 flex-wrap select-none mt-1">
    <p class="text-xs text-blue-400 font-semibold">{error.suggested_action}</p>
    {#if error.diagnostics_key && onOpenDiagnostics}
      <button
        class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-7 px-3 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-850 hover:text-zinc-50 cursor-pointer transition-colors"
        onclick={() => onOpenDiagnostics!(error.diagnostics_key!)}
      >
        View in Diagnostics →
      </button>
    {/if}
  </div>
</div>
