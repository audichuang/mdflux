<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { CLEANUP_RULES, totalChanges } from './cleanup';
  import type { CleanupResult, CleanupMethod, CleanupUIState, ViewMode } from './cleanup';
  import { lineDiff } from './diff';
  import type { DiffResult } from './diff';
  import { renderMarkdown } from './mdpreview';
  import { buildOutputFilename, type NamingCase } from './naming';
  import { onDestroy } from 'svelte';
  import { tr } from './locale';

  let {
    markdown,
    detectedFormat,
    converterPath,
    warnings = [],
    sourceStem = 'output',
    sourcePath = '',
    extractImages = true,
    namingTemplate = '{stem}',
    namingCase = 'keep',
    onClear,
    onOpenFile,
    llmMode = 'off',
    cleanupSeen = true,
    onSeenCleanup,
    cleanup,
  }: {
    markdown: string;
    detectedFormat: string;
    converterPath: string;
    warnings?: string[];
    sourceStem?: string;
    sourcePath?: string;
    extractImages?: boolean;
    namingTemplate?: string;
    namingCase?: string;
    onClear: () => void;
    onOpenFile: () => Promise<void>;
    llmMode?: string;
    cleanupSeen?: boolean;
    onSeenCleanup?: () => void;
    cleanup: CleanupUIState;
  } = $props();

  const outName = $derived(
    buildOutputFilename(
      `${sourceStem}.${(detectedFormat || '').toLowerCase()}`,
      namingTemplate,
      namingCase as NamingCase,
    ),
  );

  const running = $derived(cleanup.running);
  const llmAvailable = $derived(llmMode === 'local' || llmMode === 'api');

  const activeCleaned = $derived(
    cleanup.method === 'rules'
      ? cleanup.rulesCleaned
      : cleanup.method === 'ai'
        ? cleanup.aiCleaned
        : null,
  );
  const activeMarkdown = $derived(activeCleaned ?? markdown);
  const hasChanges = $derived(cleanup.method !== 'none' && activeCleaned !== null);

  const diff = $derived<DiffResult | null>(
    hasChanges && cleanup.viewMode === 'changes'
      ? lineDiff(markdown, activeCleaned as string)
      : null,
  );
  const previewHtml = $derived(
    cleanup.viewMode === 'preview' ? renderMarkdown(activeMarkdown) : '',
  );
  const beforeHtml = $derived(cleanup.viewMode === 'split' ? renderMarkdown(markdown) : '');
  const afterHtml = $derived(cleanup.viewMode === 'split' ? renderMarkdown(activeMarkdown) : '');

  let saved = $state(false);

  let splitSrcEl = $state<HTMLElement | null>(null);
  let splitPrevEl = $state<HTMLElement | null>(null);
  let syncing = false;
  function syncScroll(from: 'src' | 'prev') {
    if (syncing) return;
    const a = from === 'src' ? splitSrcEl : splitPrevEl;
    const b = from === 'src' ? splitPrevEl : splitSrcEl;
    if (!a || !b) return;
    const ratio = a.scrollTop / Math.max(1, a.scrollHeight - a.clientHeight);
    syncing = true;
    b.scrollTop = ratio * Math.max(1, b.scrollHeight - b.clientHeight);
    requestAnimationFrame(() => {
      syncing = false;
    });
  }

  const ruleChanges = $derived(totalChanges(cleanup.rulesSummary));
  const ruleCounts = $derived(
    Object.fromEntries((cleanup.rulesSummary?.rules ?? []).map((r) => [r.key, r.changes])),
  );

  function setView(v: ViewMode) {
    cleanup.viewMode = v;
  }

  async function selectMethod(m: CleanupMethod) {
    if (cleanup.method === m) return;
    cleanup.method = m;
    saved = false;
    if (m === 'none' && (cleanup.viewMode === 'split' || cleanup.viewMode === 'changes')) {
      cleanup.viewMode = 'preview';
    }
    if (m !== 'none' && !cleanupSeen) onSeenCleanup?.();
    if (m === 'rules' && cleanup.rulesCleaned === null) await runRules();
  }

  async function runRules() {
    cleanup.running = true;
    saved = false;
    try {
      const res = await invoke<CleanupResult>('cleanup_markdown', {
        markdown,
        sourceFormat: detectedFormat,
        method: 'rules',
        rules: cleanup.rules,
      });
      cleanup.rulesCleaned = res.markdown;
      cleanup.rulesSummary = res.summary;
    } catch {
      cleanup.rulesCleaned = markdown;
      cleanup.rulesSummary = null;
    } finally {
      cleanup.running = false;
    }
  }

  let cancelRequested = $state(false);

  async function runAi() {
    cleanup.running = true;
    cancelRequested = false;
    saved = false;
    try {
      const res = await invoke<CleanupResult>('cleanup_markdown', {
        markdown,
        sourceFormat: detectedFormat,
        method: 'ai',
        rules: {},
      });
      cleanup.aiCleaned = res.markdown;
      cleanup.aiApplied = res.llm_applied;
      cleanup.aiNotice = res.llm_notice;
    } catch (e) {
      if (cancelRequested) {
        cleanup.aiCleaned = null;
        cleanup.aiApplied = false;
        cleanup.aiNotice = 'AI cleanup cancelled — kept the original text.';
      } else {
        cleanup.aiCleaned = markdown;
        cleanup.aiApplied = false;
        cleanup.aiNotice = `AI cleanup failed: ${e}`;
      }
    } finally {
      cleanup.running = false;
      cancelRequested = false;
    }
  }

  async function cancelAi() {
    cancelRequested = true;
    try {
      await invoke('cancel_conversion');
    } catch {
      /* ignored */
    }
  }

  async function toggleRule(key: string) {
    cleanup.rules = { ...cleanup.rules, [key]: !cleanup.rules[key] };
    saved = false;
    await runRules();
  }

  let copyStatus = $state<'copy' | 'copied' | 'failed'>('copy');
  let copyTimeout: ReturnType<typeof setTimeout>;
  let confirming = $state(false);

  onDestroy(() => clearTimeout(copyTimeout));

  async function copyMarkdown() {
    try {
      await navigator.clipboard.writeText(activeMarkdown);
      clearTimeout(copyTimeout);
      copyStatus = 'copied';
      copyTimeout = setTimeout(() => (copyStatus = 'copy'), 2000);
    } catch {
      copyStatus = 'failed';
      copyTimeout = setTimeout(() => (copyStatus = 'copy'), 2000);
    }
  }
  let saveError = $state<string | null>(null);

  async function saveMarkdown(): Promise<boolean> {
    saveError = null;
    try {
      const ok = await invoke<boolean>('save_markdown', {
        content: activeMarkdown,
        suggestedName: outName,
        sourcePath: sourcePath || null,
        extractImages,
      });
      if (ok) saved = true;
      return ok;
    } catch (e) {
      saveError = `Could not save: ${e}`;
      return false;
    }
  }
  async function saveAndOpen() {
    const ok = await saveMarkdown();
    if (ok) {
      confirming = false;
      await onOpenFile();
    }
  }
  function discardAndOpen() {
    confirming = false;
    onClear();
  }

  function requestOpenNew() {
    if (saved) onOpenFile();
    else confirming = true;
  }

  let modalEl = $state<HTMLElement | null>(null);
  let openNewBtnEl = $state<HTMLButtonElement | null>(null);

  $effect(() => {
    if (confirming && modalEl) {
      modalEl.focus();
    }
  });

  function onModalKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault();
      confirming = false;
      openNewBtnEl?.focus();
      return;
    }
    if (e.key === 'Tab' && modalEl) {
      const focusable = modalEl.querySelectorAll<HTMLElement>(
        'button, [tabindex]:not([tabindex="-1"])',
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (document.activeElement === modalEl) {
        e.preventDefault();
        if (e.shiftKey) last.focus();
        else first.focus();
      } else if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
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
  <!-- Header: filename + view toggle -->
  <div
    class="flex items-center justify-between gap-3 px-4 py-2 border-b border-zinc-800 bg-zinc-900/50 flex-shrink-0"
  >
    <div class="flex items-center gap-2 min-w-0 text-zinc-400" title={sourceStem}>
      <svg width="14" height="14" viewBox="0 0 15 15" fill="none" aria-hidden="true">
        <path
          d="M3 1.5h6L12 4.5V13a.5.5 0 0 1-.5.5h-8A.5.5 0 0 1 3 13V1.5z"
          stroke="currentColor"
          stroke-width="1.1"
          stroke-linejoin="round"
        />
        <path d="M8.5 1.5V5h3.5" stroke="currentColor" stroke-width="1.1" stroke-linejoin="round" />
      </svg>
      <span class="text-xs font-semibold text-zinc-300 truncate">{sourceStem}</span>
    </div>

    <div class="seg" role="group" aria-label="View mode">
      <button
        class="seg-btn"
        class:active={cleanup.viewMode === 'preview'}
        onclick={() => setView('preview')}>{tr('preview')}</button
      >
      <button
        class="seg-btn"
        class:active={cleanup.viewMode === 'source'}
        onclick={() => setView('source')}>{tr('source')}</button
      >
      {#if hasChanges}
        <button
          class="seg-btn"
          class:active={cleanup.viewMode === 'split'}
          onclick={() => setView('split')}>{tr('split')}</button
        >
        <button
          class="seg-btn"
          class:active={cleanup.viewMode === 'changes'}
          onclick={() => setView('changes')}>{tr('changes')}</button
        >
      {/if}
    </div>
  </div>

  <!-- Cleanup bar -->
  <div class="flex-shrink-0 flex flex-col gap-2.5 px-4 py-3 border-b border-zinc-800 bg-zinc-950">
    <div class="flex items-center gap-3">
      <span class="text-xs font-semibold tracking-wider text-zinc-500 uppercase">{tr('clean_up')}</span>
      <div class="seg" role="group" aria-label="Cleanup method">
        <button
          class="seg-btn"
          class:active={cleanup.method === 'none'}
          title="Show the raw conversion, unchanged"
          onclick={() => selectMethod('none')}>{tr('off')}</button
        >
        <button
          class="seg-btn"
          class:active={cleanup.method === 'rules'}
          title="Clean up using fast, offline rules"
          onclick={() => selectMethod('rules')}>{tr('rule_based')}</button
        >
        <button
          class="seg-btn"
          class:active={cleanup.method === 'ai'}
          onclick={() => selectMethod('ai')}
          disabled={!llmAvailable}
          title={llmAvailable
            ? 'Clean up with your configured AI model'
            : 'Switch to Local or API mode to enable AI cleanup'}>{tr('ai')}</button
        >
      </div>
      {#if !cleanupSeen && cleanup.method === 'none'}
        <span
          class="text-[9px] font-bold text-white bg-blue-500 px-2 py-0.5 rounded-full tracking-wider uppercase animate-pulse"
          >New</span
        >
      {/if}
    </div>

    {#if cleanup.method === 'rules'}
      <div class="flex flex-col gap-2">
        <p class="text-xs text-zinc-400">
          Fast, offline rules — nothing leaves your machine. Toggle any rule to re-run.
          {#if running}
            <span class="text-zinc-500 ml-1">Cleaning…</span>
          {:else if cleanup.rulesSummary}
            <span class="text-zinc-500 ml-1" title="Total edits across all enabled rules"
              >{ruleChanges === 0
                ? 'No changes needed.'
                : `${ruleChanges.toLocaleString()} change${ruleChanges === 1 ? '' : 's'} total.`}</span
            >
          {/if}
        </p>
        <div class="flex flex-col gap-1 p-2 bg-zinc-900/30 border border-zinc-850 rounded-lg">
          {#each CLEANUP_RULES as rule}
            <label
              class="flex items-start gap-3 p-2.5 rounded-md hover:bg-zinc-900/40 transition-colors cursor-pointer"
              title="{rule.hint}. {cleanup.rules[rule.key] ? 'On' : 'Off'} — click to toggle."
            >
              <input
                type="checkbox"
                class="mt-1 accent-blue-500 rounded border-zinc-700 bg-zinc-900 text-blue-500 focus:ring-0 cursor-pointer"
                checked={cleanup.rules[rule.key]}
                onchange={() => toggleRule(rule.key)}
                disabled={running}
              />
              <div class="flex-1 flex flex-col gap-0.5">
                <span class="text-xs font-medium text-zinc-200">{rule.label}</span>
                <span class="text-[10px] text-zinc-500">{rule.hint}</span>
              </div>
              {#if cleanup.rulesSummary && cleanup.rules[rule.key]}
                {@const c = ruleCounts[rule.key] ?? 0}
                <span
                  class="flex-shrink-0 align-self-center text-[10px] font-mono font-semibold text-blue-400 bg-blue-950/45 px-2 py-0.5 rounded-full min-w-[22px] text-center {c ===
                  0
                    ? 'text-zinc-500 bg-zinc-900 border border-zinc-800'
                    : ''}"
                  title="{c.toLocaleString()} {c === 1 ? 'edit' : 'edits'} this rule made"
                  >{c.toLocaleString()}</span
                >
              {/if}
            </label>
          {/each}
        </div>
      </div>
    {:else if cleanup.method === 'ai'}
      {#if running}
        <div
          class="flex items-center justify-between gap-3 p-2 border border-zinc-800 rounded-lg bg-zinc-900/20"
        >
          <p class="text-xs text-zinc-400 flex items-center gap-2">
            <span
              class="inline-block w-3.5 h-3.5 border-2 border-zinc-700 border-t-blue-500 rounded-full animate-spin"
            ></span>
            Cleaning with AI… large documents on a local model can take a few minutes.
          </p>
          <button
            class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-3.5 border border-zinc-800 bg-red-950/20 hover:bg-red-950/45 text-red-450 hover:text-red-300 cursor-pointer transition-colors"
            onclick={cancelAi}
            disabled={cancelRequested}
            title="Stop the AI cleanup and keep the original text"
          >
            {cancelRequested ? 'Cancelling…' : 'Cancel'}
          </button>
        </div>
      {:else if cleanup.aiCleaned === null}
        <div class="flex flex-col gap-2.5 p-3 border border-zinc-850 rounded-lg bg-zinc-900/25">
          <p class="text-xs text-zinc-400">
            Cleans the document with your {llmMode === 'api'
              ? 'configured API model'
              : 'local model'}, in one pass. Your raw result is kept.
          </p>
          {#if llmMode === 'api'}
            <p
              class="text-[11px] text-amber-400 bg-amber-950/25 border border-amber-900/30 rounded p-2"
            >
              ⚠ This sends the document text to your configured API provider.
            </p>
          {/if}
          <button
            class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-4 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors w-fit"
            title="Send the document to your AI model and clean it up"
            onclick={runAi}>Run AI cleanup</button
          >
        </div>
      {:else}
        <div class="flex flex-col gap-1">
          <p class="text-xs text-zinc-400 flex items-center gap-2">
            {#if cleanup.aiApplied}
              <span class="text-green-400 font-semibold">✓ AI cleanup applied.</span>
            {/if}
            <button
              class="text-blue-400 hover:text-blue-300 underline underline-offset-2 bg-transparent border-none p-0 cursor-pointer text-xs"
              title="Run the AI cleanup again on the original text"
              onclick={runAi}>Run again</button
            >
          </p>
          {#if cleanup.aiNotice}
            <p class="text-xs text-amber-400 mt-1">{cleanup.aiNotice}</p>
          {/if}
        </div>
      {/if}
    {/if}
  </div>

  <!-- Content -->
  {#if cleanup.viewMode === 'split' && hasChanges}
    <div class="flex-1 flex min-h-0 divide-x divide-zinc-800 flex-col md:flex-row">
      <div class="flex-1 min-w-0 flex flex-col min-h-0">
        <div
          class="flex-shrink-0 px-6 py-1.5 text-[9px] font-semibold text-zinc-550 uppercase tracking-wider bg-zinc-900/60 border-b border-zinc-800"
        >
          Before cleanup
        </div>
        <div
          class="flex-1 min-w-0 overflow-y-auto px-6 py-5 min-h-0 bg-zinc-950 outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
          bind:this={splitSrcEl}
          onscroll={() => syncScroll('src')}
          tabindex="0"
          role="region"
          aria-label="Before cleanup"
        >
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="preview" style="max-width: 768px; margin: 0 auto;" onclick={onPreviewClick}>{@html beforeHtml}</div>
        </div>
      </div>
      <div class="flex-1 min-w-0 flex flex-col min-h-0">
        <div
          class="flex-shrink-0 px-6 py-1.5 text-[9px] font-semibold text-zinc-550 uppercase tracking-wider bg-zinc-900/60 border-b border-zinc-800"
        >
          After cleanup
        </div>
        <div
          class="flex-1 min-w-0 overflow-y-auto px-6 py-5 min-h-0 bg-zinc-950 outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
          bind:this={splitPrevEl}
          onscroll={() => syncScroll('prev')}
          tabindex="0"
          role="region"
          aria-label="After cleanup"
        >
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="preview" style="max-width: 768px; margin: 0 auto;" onclick={onPreviewClick}>{@html afterHtml}</div>
        </div>
      </div>
    </div>
  {:else}
    <div
      class="flex-1 overflow-y-auto px-6 py-6 min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-blue-500 bg-zinc-950"
      tabindex="0"
      role="region"
      aria-label="Markdown result"
    >
      {#if cleanup.viewMode === 'changes' && diff}
        {#if diff.kind === 'summary'}
          <div class="text-sm text-zinc-300 flex flex-col gap-2" style="max-width: 768px; margin: 0 auto;">
            <p>{diff.note}</p>
            <p class="font-mono text-xs">
              <span class="text-green-400">+{diff.added.toLocaleString()}</span>
              <span class="text-red-400">−{diff.removed.toLocaleString()}</span> lines
            </p>
          </div>
        {:else}
          <div class="font-mono text-xs leading-relaxed select-text" style="max-width: 768px; margin: 0 auto;">
            {#each diff.rows as row}
              <div
                class="flex gap-2 px-1 rounded-sm {row.type === 'add'
                  ? 'bg-green-950/20 text-green-405'
                  : row.type === 'del'
                    ? 'bg-red-950/20 text-red-405'
                    : 'text-zinc-400'}"
              >
                <span
                  class="flex-shrink-0 w-3 text-center text-[10px] text-zinc-600 select-none"
                  aria-hidden="true"
                  >{row.type === 'add' ? '+' : row.type === 'del' ? '−' : ''}</span
                >
                <span class="flex-1 min-w-0 break-all whitespace-pre-wrap">{row.text || ' '}</span>
              </div>
            {/each}
          </div>
        {/if}
      {:else if cleanup.viewMode === 'preview'}
        <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
        <div
          class="preview text-zinc-300 text-sm leading-relaxed"
          style="max-width: 768px; margin: 0 auto;"
          onclick={onPreviewClick}
        >
          {@html previewHtml}
        </div>
      {:else}
        <pre
          class="font-mono text-xs leading-relaxed text-zinc-300 whitespace-pre-wrap break-all select-text m-0"
          style="max-width: 768px; margin: 0 auto;">{activeMarkdown}</pre>
      {/if}
    </div>
  {/if}

  <!-- Bottom bar -->
  <div
    class="flex items-center justify-between gap-3 px-4 py-3 border-t border-zinc-800 bg-zinc-900/50 flex-shrink-0"
  >
    <span
      class="inline-flex items-center gap-1.5 text-[10px] font-mono text-zinc-400 bg-zinc-900 border border-zinc-850 px-2.5 py-1 rounded-full"
      title="Source format · {converterPath}"
    >
      {tr('from_format', { format: detectedFormat })}{#if warnings.length}<span
          class="text-amber-500 cursor-help"
          title={warnings.join('\n')}>⚠</span
        >{/if}
    </span>
    <div class="flex gap-2 items-center flex-wrap">
      {#if saveError}<p class="text-xs text-red-400 mr-2">{saveError}</p>{/if}
      <button
        class="btn-secondary"
        title="Discard this result and convert a different file"
        onclick={requestOpenNew}
        bind:this={openNewBtnEl}
      >
        <svg width="12" height="12" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <path
            d="M3 1.5h5L11 4.5V12a.5.5 0 0 1-.5.5h-7A.5.5 0 0 1 3 12V1.5z"
            stroke="currentColor"
            stroke-width="1.2"
            stroke-linejoin="round"
          />
          <path
            d="M7 6.2v3.6M5.2 8h3.6"
            stroke="currentColor"
            stroke-width="1.2"
            stroke-linecap="round"
          />
        </svg>
        {tr('open_new')}
      </button>
      <button
        class="btn-secondary"
        title="Copy the current Markdown to the clipboard"
        onclick={copyMarkdown}
      >
        <svg width="12" height="12" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <rect
            x="4.5"
            y="4.5"
            width="7.5"
            height="7.5"
            rx="1.3"
            stroke="currentColor"
            stroke-width="1.2"
          />
          <path
            d="M9.5 4.5V3a1 1 0 0 0-1-1h-5a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1H4.5"
            stroke="currentColor"
            stroke-width="1.2"
          />
        </svg>
        {copyStatus === 'copy' ? tr('copy') : copyStatus === 'copied' ? tr('copied') : 'Failed'}
      </button>
      <button
        class="btn-primary"
        title="Save the current Markdown to a .md file"
        onclick={saveMarkdown}
      >
        <svg width="12" height="12" viewBox="0 0 14 14" fill="none" aria-hidden="true">
          <path
            d="M7 1.5v7M4 6l3 3 3-3"
            stroke="currentColor"
            stroke-width="1.4"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path d="M2.5 11.5h9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" />
        </svg>
        {tr('save_md')}
      </button>
    </div>
  </div>
</div>

{#if confirming}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div
    class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[100]"
    onclick={() => {
      confirming = false;
      openNewBtnEl?.focus();
    }}
  >
    <div
      class="bg-zinc-900 border border-zinc-800 rounded-lg p-5 w-[340px] flex flex-col gap-3 shadow-xl max-w-full outline-none"
      bind:this={modalEl}
      onclick={(e) => e.stopPropagation()}
      onkeydown={onModalKeydown}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      tabindex="-1"
    >
      <p id="modal-title" class="text-sm font-semibold text-zinc-50">{tr('modal_title')}</p>
      <p class="text-xs text-zinc-400 leading-relaxed">
        {tr('modal_desc')}
      </p>
      <div class="flex justify-end gap-2 mt-2">
        <button
          class="btn-secondary btn-sm"
          onclick={() => {
            confirming = false;
            openNewBtnEl?.focus();
          }}>{tr('cancel')}</button
        >
        <button
          class="btn-danger btn-sm"
          onclick={discardAndOpen}>{tr('discard')}</button
        >
        <button
          class="btn-primary btn-sm"
          onclick={saveAndOpen}>{tr('save_open')}</button
        >
      </div>
    </div>
  </div>
{/if}

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
    color: var(--text-primary);
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
