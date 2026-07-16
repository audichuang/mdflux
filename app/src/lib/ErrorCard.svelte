<script lang="ts">
  import { tr } from './locale.svelte';

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

<div class="error-card" role="alert">
  <div class="head">
    <span class="icon" aria-hidden="true">✕</span>
    <span class="title">{error.title}</span>
    <button class="dismiss" onclick={onDismiss} aria-label={tr('dismiss_error')}>✕</button>
  </div>
  <p class="detail">{error.detail}</p>
  <div class="actions">
    <p class="hint">{error.suggested_action}</p>
    {#if error.diagnostics_key && onOpenDiagnostics}
      <button
        class="btn-secondary btn-sm"
        onclick={() => onOpenDiagnostics!(error.diagnostics_key!)}
      >
        {tr('view_diagnostics')}
      </button>
    {/if}
  </div>
</div>

<style>
  .error-card {
    background: color-mix(in srgb, var(--red) 10%, transparent);
    border: 1px solid color-mix(in srgb, var(--red) 22%, transparent);
    border-radius: var(--radius);
    padding: var(--sp-4);
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
    user-select: text;
  }
  .head {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    user-select: none;
  }
  .icon {
    font-size: 12px;
    font-weight: 700;
    color: var(--red);
    flex-shrink: 0;
  }
  .title {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary);
    flex: 1;
  }
  .dismiss {
    color: var(--text-muted);
    cursor: pointer;
    font-size: 12px;
    padding: 0 4px;
    border: none;
    background: transparent;
  }
  .dismiss:hover {
    color: var(--text-primary);
  }
  .detail {
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.55;
    margin: 0;
  }
  .actions {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: var(--sp-4);
    flex-wrap: wrap;
    user-select: none;
    margin-top: 4px;
  }
  .hint {
    font-size: 12px;
    color: var(--accent);
    font-weight: 600;
    margin: 0;
  }
</style>
