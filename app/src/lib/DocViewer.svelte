<script lang="ts">
  import { renderMarkdown } from './mdpreview';
  import { onDestroy } from 'svelte';

  let {
    name,
    markdown,
    onBack,
  }: {
    name: string;
    markdown: string;
    onBack: () => void;
  } = $props();

  let view = $state<'preview' | 'source'>('preview');
  const previewHtml = $derived(view === 'preview' ? renderMarkdown(markdown) : '');

  let copyLabel = $state('Copy');
  let copyTimer: ReturnType<typeof setTimeout>;
  onDestroy(() => clearTimeout(copyTimer));
  async function copy() {
    try {
      await navigator.clipboard.writeText(markdown);
      clearTimeout(copyTimer);
      copyLabel = 'Copied!';
      copyTimer = setTimeout(() => (copyLabel = 'Copy'), 1800);
    } catch {
      copyLabel = 'Failed';
      copyTimer = setTimeout(() => (copyLabel = 'Copy'), 1800);
    }
  }

  function onPreviewClick(e: MouseEvent) {
    const a = (e.target as HTMLElement)?.closest('a');
    if (a) e.preventDefault();
  }
</script>

<div
  class="flex-1 flex flex-col min-h-0 bg-zinc-950 border border-zinc-800 rounded-lg overflow-hidden"
>
  <!-- Toolbar / Header -->
  <div
    class="flex items-center gap-3 px-4 py-2 border-b border-zinc-800 bg-zinc-900/50 flex-shrink-0"
  >
    <button
      class="inline-flex items-center gap-1.5 rounded-md text-xs font-semibold h-8 px-3 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors"
      onclick={onBack}
      title="Back to the batch summary"
    >
      <svg width="12" height="12" viewBox="0 0 14 14" fill="none" aria-hidden="true">
        <path
          d="M9 2L4 7l5 5"
          stroke="currentColor"
          stroke-width="1.75"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
      Back
    </button>
    <span class="flex-1 min-w-0 text-xs font-semibold text-zinc-300 truncate" title={name}
      >{name}</span
    >

    <div
      class="inline-flex h-8 items-center justify-start rounded-md bg-zinc-900 p-0.5 text-zinc-400 border border-zinc-800 w-fit"
      role="group"
      aria-label="View mode"
    >
      <button
        class="inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1 text-[11px] font-semibold transition-all duration-150 cursor-pointer {view ===
        'preview'
          ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
          : 'hover:text-zinc-200'}"
        title="Rendered Markdown"
        onclick={() => (view = 'preview')}>Preview</button
      >
      <button
        class="inline-flex items-center justify-center whitespace-nowrap rounded-sm px-3 py-1 text-[11px] font-semibold transition-all duration-150 cursor-pointer {view ===
        'source'
          ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
          : 'hover:text-zinc-200'}"
        title="Raw Markdown text"
        onclick={() => (view = 'source')}>Source</button
      >
    </div>

    <button
      class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-3.5 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors"
      onclick={copy}
      title="Copy the Markdown">{copyLabel}</button
    >
  </div>

  <!-- Document body -->
  <div
    class="flex-1 overflow-y-auto px-6 py-6 min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
    tabindex="0"
    role="region"
    aria-label="Document"
  >
    {#if view === 'preview'}
      <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
      <div
        class="preview text-zinc-300 text-sm leading-relaxed max-w-[760px] mx-auto"
        onclick={onPreviewClick}
      >
        {@html previewHtml}
      </div>
    {:else}
      <pre
        class="font-mono text-xs leading-relaxed text-zinc-300 whitespace-pre-wrap break-all select-text m-0 max-w-[760px] mx-auto">{markdown}</pre>
    {/if}
  </div>
</div>

<style>
  .preview :global(h1) {
    font-size: 26px;
    font-weight: 700;
    letter-spacing: -0.02em;
    margin: 0 0 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border);
  }
  .preview :global(h2) {
    font-size: 20px;
    font-weight: 700;
    margin: 24px 0 8px;
  }
  .preview :global(h3) {
    font-size: 16px;
    font-weight: 600;
    margin: 20px 0 8px;
  }
  .preview :global(h4),
  .preview :global(h5),
  .preview :global(h6) {
    font-size: 14px;
    font-weight: 600;
    margin: 16px 0 4px;
  }
  .preview :global(p) {
    margin: 0 0 12px;
  }
  .preview :global(ul),
  .preview :global(ol) {
    margin: 0 0 12px;
    padding-left: 24px;
  }
  .preview :global(li) {
    margin: 2px 0;
  }
  .preview :global(a) {
    color: var(--accent);
    text-decoration: underline;
    text-underline-offset: 2px;
  }
  .preview :global(strong) {
    font-weight: 700;
  }
  .preview :global(em) {
    font-style: italic;
  }
  .preview :global(blockquote) {
    margin: 0 0 12px;
    padding: 4px 16px;
    border-left: 3px solid var(--border);
    color: var(--text-secondary);
  }
  .preview :global(hr) {
    border: none;
    border-top: 1px solid var(--border);
    margin: 20px 0;
  }
  .preview :global(code) {
    font-family: var(--font-mono);
    font-size: 0.88em;
    background: var(--surface-2);
    padding: 1px 5px;
    border-radius: 4px;
  }
  .preview :global(pre) {
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 12px;
    overflow-x: auto;
    margin: 0 0 12px;
  }
  .preview :global(pre code) {
    background: none;
    padding: 0;
  }
  .preview :global(table) {
    border-collapse: collapse;
    margin: 0 0 12px;
    font-size: 13px;
    display: block;
    overflow-x: auto;
  }
  .preview :global(th),
  .preview :global(td) {
    border: 1px solid var(--border);
    padding: 5px 10px;
    text-align: left;
  }
  .preview :global(th) {
    background: var(--surface-2);
    font-weight: 600;
  }
  .preview :global(img) {
    max-width: 100%;
  }
</style>
