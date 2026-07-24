<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { CLEANUP_RULES, totalChanges } from './cleanup';
  import type { CleanupResult, CleanupMethod, CleanupUIState, ViewMode } from './cleanup';
  import { lineDiff } from './diff';
  import type { DiffResult } from './diff';
  import { renderMarkdown } from './mdpreview';
  import { buildOutputFilename, type NamingCase } from './naming';
  import { onDestroy, onMount } from 'svelte';
  import { tr } from './locale.svelte';

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
  let rulesError = $state<string | null>(null);

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

  // Auto-expand details when switching to rules/ai so first interaction is clear;
  // collapse when back to none to give preview space.
  async function selectMethod(m: CleanupMethod) {
    if (cleanup.method === m) return;
    cleanup.method = m;
    saved = false;
    rulesError = null;
    if (m === 'none') {
      if (cleanup.viewMode === 'split' || cleanup.viewMode === 'changes') {
        cleanup.viewMode = 'preview';
      }
      cleanup.showAdvanced = false;
    } else {
      cleanup.showAdvanced = true;
    }
    if (m !== 'none' && !cleanupSeen) onSeenCleanup?.();
    if (m === 'rules' && cleanup.rulesCleaned === null) await runRules();
  }

  async function runRules() {
    cleanup.running = true;
    saved = false;
    rulesError = null;
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
      rulesError = tr('cleanup_failed_silent');
    } finally {
      cleanup.running = false;
    }
  }

  let cancelRequested = $state(false);
  let rulesDebounce: ReturnType<typeof setTimeout> | null = null;

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
        cleanup.aiNotice = tr('ai_cancelled');
      } else {
        cleanup.aiCleaned = markdown;
        cleanup.aiApplied = false;
        cleanup.aiNotice = tr('ai_failed', { error: String(e) });
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

  function toggleRule(key: string) {
    cleanup.rules = { ...cleanup.rules, [key]: !cleanup.rules[key] };
    saved = false;
    if (rulesDebounce) clearTimeout(rulesDebounce);
    rulesDebounce = setTimeout(() => {
      rulesDebounce = null;
      runRules();
    }, 280);
  }

  let copyStatus = $state<'copy' | 'copied' | 'failed'>('copy');
  let copyTimeout: ReturnType<typeof setTimeout>;
  let confirming = $state(false);

  onDestroy(() => {
    clearTimeout(copyTimeout);
    if (rulesDebounce) clearTimeout(rulesDebounce);
  });

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
      saveError = tr('save_failed', { error: String(e) });
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

  // Cmd/Ctrl+S to save while viewing result
  onMount(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        if (!confirming) saveMarkdown();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const summaryLine = $derived.by(() => {
    if (running) return tr('cleaning');
    if (cleanup.method === 'rules' && cleanup.rulesSummary) {
      if (ruleChanges === 0) return tr('no_changes_needed');
      return ruleChanges === 1
        ? tr('changes_total', { count: ruleChanges.toLocaleString() })
        : tr('changes_total_plural', { count: ruleChanges.toLocaleString() });
    }
    if (cleanup.method === 'ai' && cleanup.aiApplied) return tr('ai_applied');
    return '';
  });
</script>

<div class="result-shell flex-1 flex flex-col min-h-0">
  <!-- Header: filename + view toggle -->
  <div
    class="result-chrome flex flex-wrap items-center justify-between gap-3 px-5 py-3 hairline-b flex-shrink-0"
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

    <div class="seg w-full sm:w-auto" role="group" aria-label={tr('view_mode')}>
      <button
        class="seg-btn flex-1 min-w-0 sm:flex-none"
        class:active={cleanup.viewMode === 'preview'}
        onclick={() => setView('preview')}>{tr('preview')}</button
      >
      <button
        class="seg-btn flex-1 min-w-0 sm:flex-none"
        class:active={cleanup.viewMode === 'source'}
        onclick={() => setView('source')}>{tr('source')}</button
      >
      {#if hasChanges}
        <button
          class="seg-btn flex-1 min-w-0 sm:flex-none"
          class:active={cleanup.viewMode === 'split'}
          onclick={() => setView('split')}>{tr('split')}</button
        >
        <button
          class="seg-btn flex-1 min-w-0 sm:flex-none"
          class:active={cleanup.viewMode === 'changes'}
          onclick={() => setView('changes')}>{tr('changes')}</button
        >
      {/if}
    </div>
  </div>

  <!-- Compact cleanup chrome -->
  <div class="result-chrome flex-shrink-0 flex flex-col gap-2 px-5 py-2.5 hairline-b">
    <div class="flex items-center gap-3 flex-wrap">
      <span class="text-xs font-semibold tracking-wider text-zinc-500 uppercase"
        >{tr('clean_up')}</span
      >
      <div class="seg" role="group" aria-label={tr('cleanup_method')}>
        <button
          class="seg-btn"
          class:active={cleanup.method === 'none'}
          title={tr('tip_raw')}
          onclick={() => selectMethod('none')}>{tr('off')}</button
        >
        <button
          class="seg-btn"
          class:active={cleanup.method === 'rules'}
          title={tr('tip_rules')}
          onclick={() => selectMethod('rules')}>{tr('rule_based')}</button
        >
        <button
          class="seg-btn"
          class:active={cleanup.method === 'ai'}
          onclick={() => selectMethod('ai')}
          disabled={!llmAvailable}
          title={llmAvailable ? tr('tip_ai') : tr('tip_ai_off')}>{tr('ai')}</button
        >
      </div>

      {#if summaryLine}
        <span class="text-[length:var(--font-size-xs)] text-zinc-500 truncate max-w-[240px]"
          >{summaryLine}</span
        >
      {/if}

      {#if !cleanupSeen && cleanup.method === 'none'}
        <span class="new-badge">{tr('badge_new')}</span>
      {/if}

      {#if cleanup.method !== 'none'}
        <button
          class="btn-tertiary btn-sm ml-auto"
          onclick={() => (cleanup.showAdvanced = !cleanup.showAdvanced)}
          aria-expanded={cleanup.showAdvanced}
          title={cleanup.showAdvanced ? tr('cleanup_collapse') : tr('cleanup_expand')}
        >
          {cleanup.showAdvanced ? tr('cleanup_collapse') : tr('cleanup_expand')}
        </button>
      {/if}
    </div>

    {#if cleanup.showAdvanced && cleanup.method === 'rules'}
      <div class="flex flex-col gap-2">
        <p class="text-xs text-zinc-400">
          {tr('rules_intro')}
          {#if running}
            <span class="text-zinc-500 ml-1">{tr('cleaning')}</span>
          {:else if cleanup.rulesSummary}
            <span class="text-zinc-500 ml-1" title={summaryLine}>
              {summaryLine}
            </span>
          {/if}
        </p>
        {#if rulesError}
          <p class="text-xs text-[var(--amber)]" role="status">{rulesError}</p>
        {/if}
        <div class="panel-inset flex flex-col gap-0.5 p-1.5 max-h-[220px] overflow-y-auto">
          {#each CLEANUP_RULES as rule}
            <label
              class="flex items-start gap-3 px-3 py-2 rounded-xl hover:bg-[color-mix(in_srgb,var(--text-primary)_3%,transparent)] transition-colors cursor-pointer"
              title={tr('rule_toggle_hint', {
                hint: tr(rule.hintKey),
                state: cleanup.rules[rule.key] ? tr('rule_on') : tr('rule_off'),
              })}
            >
              <input
                type="checkbox"
                class="mt-1 accent-[var(--accent)] rounded cursor-pointer"
                checked={cleanup.rules[rule.key]}
                onchange={() => toggleRule(rule.key)}
                disabled={running}
              />
              <div class="flex-1 flex flex-col gap-0.5">
                <span class="text-xs font-medium text-zinc-200">{tr(rule.labelKey)}</span>
                <span class="text-[length:var(--font-size-2xs)] text-zinc-500"
                  >{tr(rule.hintKey)}</span
                >
              </div>
              {#if cleanup.rulesSummary && cleanup.rules[rule.key]}
                {@const c = ruleCounts[rule.key] ?? 0}
                <span
                  class="count-pill flex-shrink-0 text-[length:var(--font-size-2xs)] font-mono font-semibold px-2 py-0.5 rounded-full min-w-[22px] text-center {c ===
                  0
                    ? 'count-zero'
                    : ''}"
                  title={c === 1
                    ? tr('edits_one', { count: c.toLocaleString() })
                    : tr('edits_many', { count: c.toLocaleString() })}>{c.toLocaleString()}</span
                >
              {/if}
            </label>
          {/each}
        </div>
      </div>
    {:else if cleanup.showAdvanced && cleanup.method === 'ai'}
      {#if running}
        <div class="flex items-center justify-between gap-3 p-3 panel-inset">
          <p class="text-xs text-zinc-400 flex items-center gap-2">
            <span class="spin" aria-hidden="true"></span>
            {tr('ai_cleaning')}
          </p>
          <button
            class="btn-danger btn-sm"
            onclick={cancelAi}
            disabled={cancelRequested}
            title={tr('cancel')}
          >
            {cancelRequested ? tr('cancelling') : tr('cancel')}
          </button>
        </div>
      {:else if cleanup.aiCleaned === null}
        <div class="flex flex-col gap-2.5 p-3 panel-inset">
          <p class="text-xs text-zinc-400">
            {llmMode === 'api' ? tr('ai_intro_api') : tr('ai_intro_local')}
          </p>
          {#if llmMode === 'api'}
            <p
              class="text-[length:var(--font-size-xs)] text-[var(--amber)] rounded-xl px-3 py-2"
              style="background: color-mix(in srgb, var(--amber) 12%, transparent)"
            >
              {tr('ai_api_warn')}
            </p>
          {/if}
          <button class="btn-secondary btn-sm w-fit" title={tr('run_ai_cleanup')} onclick={runAi}
            >{tr('run_ai_cleanup')}</button
          >
        </div>
      {:else}
        <div class="flex flex-col gap-1">
          <p class="text-xs text-zinc-400 flex items-center gap-2">
            {#if cleanup.aiApplied}
              <span class="text-[var(--green)] font-semibold">{tr('ai_applied')}</span>
            {/if}
            <button
              class="text-[var(--accent)] hover:text-[var(--accent-hover)] underline underline-offset-2 bg-transparent border-none p-0 cursor-pointer text-xs"
              title={tr('run_again')}
              onclick={runAi}>{tr('run_again')}</button
            >
          </p>
          {#if cleanup.aiNotice}
            <p class="text-xs text-[var(--amber)] mt-1">{cleanup.aiNotice}</p>
          {/if}
        </div>
      {/if}
    {/if}
  </div>

  <!-- Content -->
  {#if cleanup.viewMode === 'split' && hasChanges}
    <div
      class="result-body flex-1 flex min-h-0 divide-y divide-[var(--divider)] md:divide-y-0 md:divide-x flex-col md:flex-row"
    >
      <div class="flex-1 min-w-0 flex flex-col min-h-0">
        <div
          class="split-label flex-shrink-0 py-2 text-[length:var(--font-size-2xs)] font-semibold text-zinc-500 uppercase tracking-wider hairline-b"
        >
          {tr('before_cleanup')}
        </div>
        <div
          class="result-scroll flex-1 min-w-0 overflow-y-auto min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-[color-mix(in_srgb,var(--accent)_60%,transparent)]"
          bind:this={splitSrcEl}
          onscroll={() => syncScroll('src')}
          tabindex="0"
          role="region"
          aria-label={tr('before_cleanup')}
        >
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="md-preview result-col" onclick={onPreviewClick}>
            {@html beforeHtml}
          </div>
        </div>
      </div>
      <div class="flex-1 min-w-0 flex flex-col min-h-0">
        <div
          class="split-label flex-shrink-0 py-2 text-[length:var(--font-size-2xs)] font-semibold text-zinc-500 uppercase tracking-wider hairline-b"
        >
          {tr('after_cleanup')}
        </div>
        <div
          class="result-scroll flex-1 min-w-0 overflow-y-auto min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-[color-mix(in_srgb,var(--accent)_60%,transparent)]"
          bind:this={splitPrevEl}
          onscroll={() => syncScroll('prev')}
          tabindex="0"
          role="region"
          aria-label={tr('after_cleanup')}
        >
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
          <div class="md-preview result-col" onclick={onPreviewClick}>
            {@html afterHtml}
          </div>
        </div>
      </div>
    </div>
  {:else}
    <div
      class="result-scroll flex-1 overflow-y-auto min-h-0 outline-none focus-visible:ring-2 focus-visible:ring-[color-mix(in_srgb,var(--accent)_60%,transparent)]"
      tabindex="0"
      role="region"
      aria-label={tr('markdown_result')}
    >
      {#if cleanup.viewMode === 'changes' && diff}
        {#if diff.kind === 'summary'}
          <div class="text-sm text-zinc-300 flex flex-col gap-2 result-col">
            <p>{diff.note}</p>
            <p class="font-mono text-xs">
              <span class="text-[var(--green)]">+{diff.added.toLocaleString()}</span>
              <span class="text-[var(--red)]">−{diff.removed.toLocaleString()}</span>
              {tr('lines_diff')}
            </p>
          </div>
        {:else}
          <div class="font-mono text-xs leading-relaxed select-text result-col">
            {#each diff.rows as row}
              <div
                class="flex gap-2 px-1 rounded-sm {row.type === 'add'
                  ? 'diff-add'
                  : row.type === 'del'
                    ? 'diff-del'
                    : 'text-zinc-400'}"
              >
                <span
                  class="flex-shrink-0 w-3 text-center text-[length:var(--font-size-2xs)] text-zinc-600 select-none"
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
        <div class="md-preview result-col" onclick={onPreviewClick}>
          {@html previewHtml}
        </div>
      {:else}
        <pre
          class="font-mono text-xs leading-relaxed text-zinc-300 whitespace-pre overflow-x-auto break-normal select-text m-0 result-col">{activeMarkdown}</pre>
      {/if}
    </div>
  {/if}

  <!-- Bottom bar -->
  <div
    class="result-chrome flex items-center justify-between gap-3 px-5 py-3 hairline-t flex-shrink-0"
  >
    <span
      class="inline-flex items-center gap-1.5 text-[length:var(--font-size-2xs)] font-mono text-zinc-400 px-1 min-w-0"
      title={tr('source_format_path', { path: converterPath })}
    >
      <span class="truncate">{tr('from_format', { format: detectedFormat })}</span>
      {#if warnings.length}<span
          class="text-[var(--amber)] cursor-help flex-shrink-0"
          title={warnings.join('\n')}>⚠</span
        >{/if}
    </span>
    <div class="flex gap-2 items-center flex-wrap justify-end">
      {#if saveError}<p
          class="text-xs text-[var(--red)] mr-1 max-w-[200px] truncate"
          title={saveError}
        >
          {saveError}
        </p>{/if}
      <button
        class="btn-secondary"
        title={tr('tip_open_new')}
        onclick={requestOpenNew}
        bind:this={openNewBtnEl}
      >
        {tr('open_new')}
      </button>
      <button class="btn-secondary" title={tr('tip_copy')} onclick={copyMarkdown}>
        {copyStatus === 'copy'
          ? tr('copy')
          : copyStatus === 'copied'
            ? tr('copied')
            : tr('failed_short')}
      </button>
      <button class="btn-primary" title={tr('tip_save')} onclick={saveMarkdown}>
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
      class="panel p-5 w-[340px] flex flex-col gap-3 max-w-full outline-none"
      style="background: var(--surface-1)"
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
        <button class="btn-danger btn-sm" onclick={discardAndOpen}>{tr('discard')}</button>
        <button class="btn-primary btn-sm" onclick={saveAndOpen}>{tr('save_open')}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .result-shell {
    background: transparent;
  }
  .result-chrome {
    background: transparent;
  }
  .result-scroll {
    background: transparent;
    padding: var(--sp-6) var(--reader-gutter) calc(var(--sp-5) * 2);
  }
  .split-label {
    padding-inline: var(--reader-gutter);
  }
  .result-col {
    max-width: min(var(--reader-max-width), 100%);
    margin: 0 auto;
    width: 100%;
  }

  @media (min-width: 1600px) {
    .result-col {
      max-width: min(var(--reader-max-width-wide), 100%);
    }
  }

  .new-badge {
    font-size: 9px;
    font-weight: 700;
    color: var(--on-accent);
    background: var(--accent);
    padding: 2px 8px;
    border-radius: 999px;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }
  @media (prefers-reduced-motion: no-preference) {
    .new-badge {
      animation: pulse-soft 2s ease-in-out infinite;
    }
  }
  @keyframes pulse-soft {
    0%,
    100% {
      opacity: 1;
    }
    50% {
      opacity: 0.7;
    }
  }

  .count-pill {
    /* text-primary, not --accent: accent-on-accent-tint fails AA on its own tint. */
    color: var(--text-primary);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
  }
  .count-zero {
    color: var(--text-secondary);
    background: color-mix(in srgb, var(--text-primary) 6%, transparent);
  }

  .diff-add {
    background: color-mix(in srgb, var(--green) 12%, transparent);
    color: var(--green);
  }
  .diff-del {
    background: color-mix(in srgb, var(--red) 12%, transparent);
    color: var(--red);
  }

  .spin {
    display: inline-block;
    width: 14px;
    height: 14px;
    border: 2px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .spin {
      animation: none;
      opacity: 0.5;
    }
  }
</style>
