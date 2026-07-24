<script module lang="ts">
  import { defaultRules } from './cleanup';
  import type { CleanupMethod } from './cleanup';
  import type { OutputRule } from './naming';

  export interface FileInfo {
    path: string;
    name: string;
    ext: string; // uppercase, e.g. "PDF"
    size: number; // bytes
  }

  export interface ConvertCleanup {
    method: CleanupMethod; // 'none' | 'rules' | 'ai'
    rules: Record<string, boolean>;
  }

  export interface StagingState {
    outputFolder: string | null;
    outputRule: OutputRule; // Stage 7 — per-run output location rule
    method: CleanupMethod;
    rules: Record<string, boolean>;
  }

  export function freshStaging(seed?: { rule?: string; folder?: string | null }): StagingState {
    return {
      outputFolder: seed?.folder ?? null,
      outputRule: (seed?.rule as OutputRule) ?? 'next_to_source',
      method: 'none',
      rules: defaultRules('pdf'),
    };
  }

  function fmtSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
</script>

<script lang="ts">
  import { onMount } from 'svelte';
  import { listen } from '@tauri-apps/api/event';
  import { open } from '@tauri-apps/plugin-dialog';
  import { CLEANUP_RULES } from './cleanup';
  import { SUPPORTED_EXTS, isHeavyExt } from './formats';
  import { buildOutputFilename, type NamingCase } from './naming';
  import { tr } from './locale.svelte';

  let {
    files,
    setup,
    llmMode = 'off',
    cleanupSeen = true,
    namingTemplate = '{stem}',
    namingCase = 'keep',
    onSeenCleanup,
    onAddFiles,
    onRemove,
    onClear,
    onConvert,
    onOpenDiagnostics,
  }: {
    files: FileInfo[];
    setup: StagingState;
    llmMode?: string;
    cleanupSeen?: boolean;
    namingTemplate?: string;
    namingCase?: string;
    onSeenCleanup?: () => void;
    onAddFiles: (rawPaths: string[]) => void;
    onRemove: (path: string) => void;
    onClear: () => void;
    onConvert: (outputFolder: string | null, outputRule: string, cleanup: ConvertCleanup) => void;
    onOpenDiagnostics?: () => void;
  } = $props();

  const isBatch = $derived(files.length > 1);
  const namePreview = $derived(
    files.length
      ? buildOutputFilename(files[0].name, namingTemplate, namingCase as NamingCase)
      : '',
  );
  const llmAvailable = $derived(llmMode === 'local' || llmMode === 'api');
  const heavyCount = $derived(files.filter((f) => isHeavyExt(f.ext)).length);
  const needsFolder = $derived(
    isBatch && setup.outputRule !== 'next_to_source' && !setup.outputFolder,
  );
  const canConvert = $derived(files.length > 0 && !needsFolder);

  let dragHover = $state(false);

  onMount(() => {
    let unDrop: (() => void) | undefined;
    let unEnter: (() => void) | undefined;
    let unLeave: (() => void) | undefined;
    let dead = false;
    listen<{ paths: string[] }>('tauri://drag-drop', (e) => {
      dragHover = false;
      const paths = e.payload.paths ?? [];
      if (paths.length) onAddFiles(paths);
    }).then((fn) => {
      if (dead) fn();
      else unDrop = fn;
    });
    listen('tauri://drag-enter', () => (dragHover = true)).then((fn) => {
      if (dead) fn();
      else unEnter = fn;
    });
    listen('tauri://drag-leave', () => (dragHover = false)).then((fn) => {
      if (dead) fn();
      else unLeave = fn;
    });
    return () => {
      dead = true;
      unDrop?.();
      unEnter?.();
      unLeave?.();
    };
  });

  async function browseFiles() {
    const sel = await open({
      multiple: true,
      filters: [
        { name: tr('supported_files'), extensions: SUPPORTED_EXTS },
        { name: tr('all_files'), extensions: ['*'] },
      ],
    });
    if (!sel) return;
    onAddFiles(Array.isArray(sel) ? (sel as string[]) : [sel as string]);
  }
  async function browseFolder() {
    const sel = await open({ directory: true, multiple: false });
    if (!sel) return;
    onAddFiles([typeof sel === 'string' ? sel : (sel as string[])[0]]);
  }

  async function chooseFolder() {
    const sel = await open({ directory: true, multiple: false });
    if (!sel) return;
    setup.outputFolder = typeof sel === 'string' ? sel : (sel as string[])[0];
  }

  function setRule(r: OutputRule) {
    setup.outputRule = r;
  }

  function selectMethod(m: CleanupMethod) {
    setup.method = m;
    if (m !== 'none' && !cleanupSeen) onSeenCleanup?.();
  }

  function convert() {
    if (!canConvert) return;
    onConvert(setup.outputFolder, setup.outputRule, { method: setup.method, rules: setup.rules });
  }
</script>

<div
  class="w-full max-w-2xl self-center py-6 px-1 flex flex-col gap-6 h-full min-h-0 overflow-y-auto"
>
  <!-- Header -->
  <div class="flex items-baseline justify-between hairline-b pb-4">
    <div class="flex items-baseline gap-2">
      <span class="text-3xl font-bold font-mono tracking-tight text-zinc-50">{files.length}</span>
      <span class="text-sm font-medium text-zinc-400"
        >{files.length === 1 ? tr('file_ready') : tr('files_ready')}</span
      >
    </div>
    <button
      class="text-sm font-medium text-zinc-400 hover:text-zinc-100 underline underline-offset-4 cursor-pointer transition-colors"
      onclick={onClear}
      title={tr('clear_all')}>{tr('clear_all')}</button
    >
  </div>

  <!-- File list -->
  <div
    class="panel-inset flex flex-col gap-1.5 p-2 min-h-[120px] max-h-[300px] overflow-y-auto transition-colors duration-200 {dragHover
      ? 'bg-[var(--accent-dim)] ring-2 ring-[color-mix(in_srgb,var(--accent)_35%,transparent)]'
      : ''}"
  >
    {#each files as f (f.path)}
      <div
        class="flex items-center gap-3 px-2.5 py-2 rounded-xl hover:bg-[color-mix(in_srgb,var(--text-primary)_4%,transparent)] transition-all group"
      >
        <span
          class="flex-shrink-0 text-[length:var(--font-size-2xs)] font-bold font-mono px-2 py-0.5 rounded-full bg-[var(--canvas)] text-zinc-400 group-hover:text-[var(--accent)] min-w-[48px] text-center uppercase tracking-wider transition-colors"
          >{f.ext || 'FILE'}</span
        >
        <span class="flex-1 min-w-0 text-sm font-medium text-zinc-300 truncate" title={f.path}
          >{f.name}</span
        >
        <span class="flex-shrink-0 text-xs font-mono text-zinc-500">{fmtSize(f.size)}</span>
        <button
          class="btn-tertiary btn-sm btn-icon flex-shrink-0 icon-circle icon-remove"
          title={tr('remove_file', { name: f.name })}
          aria-label={tr('remove_file', { name: f.name })}
          onclick={() => onRemove(f.path)}
        >
          <svg width="12" height="12" viewBox="0 0 11 11" fill="none" aria-hidden="true">
            <path
              d="M2 2l7 7M9 2l-7 7"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
            />
          </svg>
        </button>
      </div>
    {/each}
  </div>

  <!-- Add more -->
  <div class="flex items-center gap-3 flex-wrap text-xs text-zinc-400">
    <span>{tr('add_more')}</span>
    <button class="btn-secondary btn-sm" onclick={browseFiles}>{tr('choose_files')}</button>
    <button class="btn-secondary btn-sm" onclick={browseFolder}>{tr('choose_folder')}</button>
  </div>

  {#if !isBatch}
    <p class="text-xs text-zinc-500 leading-relaxed">{tr('single_cleanup_hint')}</p>
  {/if}

  {#if isBatch}
    <!-- Output destination (batch only) -->
    <div class="flex flex-col gap-3 hairline-t pt-5">
      <span class="text-xs font-semibold tracking-wider text-zinc-400 uppercase"
        >{tr('save_output_to')}</span
      >
      <div class="seg w-full sm:w-auto" role="group" aria-label={tr('output_location')}>
        <button
          class="seg-btn flex-1 min-w-0"
          class:active={setup.outputRule === 'next_to_source'}
          title={tr('tip_next_to_source')}
          onclick={() => setRule('next_to_source')}>{tr('next_to_source')}</button
        >
        <button
          class="seg-btn flex-1 min-w-0"
          class:active={setup.outputRule === 'fixed_folder'}
          title={tr('tip_one_folder')}
          onclick={() => setRule('fixed_folder')}>{tr('one_folder')}</button
        >
        <button
          class="seg-btn flex-1 min-w-0"
          class:active={setup.outputRule === 'mirror_tree'}
          title={tr('tip_mirror')}
          onclick={() => setRule('mirror_tree')}>{tr('mirror_folders')}</button
        >
      </div>

      {#if setup.outputRule !== 'next_to_source'}
        <div class="flex items-center gap-3 p-3 panel-inset">
          <svg
            class="text-zinc-500 flex-shrink-0"
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            aria-hidden="true"
          >
            <path
              d="M1.5 4.5A1 1 0 0 1 2.5 3.5h3.086a1 1 0 0 1 .707.293l.914.914H13.5a1 1 0 0 1 1 1V12a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1V4.5z"
              stroke="currentColor"
              stroke-width="1.25"
              fill="none"
            />
          </svg>
          <span
            class="flex-1 font-mono text-xs text-zinc-300 truncate {!setup.outputFolder
              ? 'text-zinc-500 font-sans italic'
              : ''}"
            title={setup.outputFolder ?? tr('no_folder_chosen')}
          >
            {setup.outputFolder ?? tr('no_folder_chosen')}
          </span>
          {#if setup.outputFolder}
            <button
              class="btn-tertiary btn-sm btn-icon flex-shrink-0 icon-circle"
              title={tr('clear_folder')}
              aria-label={tr('clear_folder')}
              onclick={() => (setup.outputFolder = null)}
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true">
                <path
                  d="M2 2l6 6M8 2l-6 6"
                  stroke="currentColor"
                  stroke-width="1.5"
                  stroke-linecap="round"
                />
              </svg>
            </button>
          {/if}
          <button
            class="btn-secondary btn-sm"
            title={tr('pick_output_folder')}
            onclick={chooseFolder}>{setup.outputFolder ? tr('change') : tr('choose_folder')}</button
          >
        </div>
        {#if needsFolder}
          <p class="text-xs text-[var(--amber)] leading-normal">{tr('need_folder')}</p>
        {/if}
        {#if setup.outputRule === 'mirror_tree'}
          <span class="text-xs text-zinc-500 leading-normal">{tr('mirror_tree_hint')}</span>
        {/if}
      {/if}

      {#if namePreview}
        <div class="flex items-center gap-2 text-xs text-zinc-400">
          <span
            class="font-semibold tracking-wider text-[length:var(--font-size-2xs)] text-zinc-500 uppercase"
            >{tr('named_as')}</span
          >
          <span class="text-zinc-500">{tr('name_example')}</span>
          <span
            class="flex-1 min-w-0 font-mono text-zinc-300 font-semibold truncate"
            title={namePreview}>{namePreview}</span
          >
          {#if onOpenDiagnostics}
            <button
              class="text-[length:var(--font-size-xs)] text-[var(--accent)] hover:text-[var(--accent-hover)] underline underline-offset-2 transition-colors cursor-pointer bg-transparent border-none p-0"
              title={tr('file_name')}
              onclick={onOpenDiagnostics}>{tr('change_naming')}</button
            >
          {/if}
        </div>
      {/if}
    </div>

    <!-- Cleanup method (batch) -->
    <div class="flex flex-col gap-3 hairline-t pt-5">
      <div class="flex flex-wrap items-center gap-3 justify-between">
        <span class="text-xs font-semibold tracking-wider text-zinc-400 uppercase"
          >{tr('clean_up')}</span
        >
        <div class="seg w-full sm:w-auto" role="group" aria-label={tr('cleanup_method')}>
          <button
            class="seg-btn flex-1 min-w-0"
            class:active={setup.method === 'none'}
            title={tr('tip_cleanup_off')}
            onclick={() => selectMethod('none')}>{tr('off')}</button
          >
          <button
            class="seg-btn flex-1 min-w-0"
            class:active={setup.method === 'rules'}
            title={tr('tip_cleanup_rules')}
            onclick={() => selectMethod('rules')}>{tr('rule_based')}</button
          >
          <button
            class="seg-btn flex-1 min-w-0"
            class:active={setup.method === 'ai'}
            disabled={!llmAvailable}
            title={llmAvailable ? tr('tip_cleanup_ai') : tr('tip_cleanup_ai_disabled')}
            onclick={() => selectMethod('ai')}>{tr('ai')}</button
          >
        </div>
      </div>

      {#if setup.method === 'rules'}
        <div class="panel-inset flex flex-col gap-0.5 p-1.5">
          {#each CLEANUP_RULES as rule}
            <label
              class="flex items-start gap-3 px-3 py-2.5 rounded-xl hover:bg-[color-mix(in_srgb,var(--text-primary)_3%,transparent)] transition-colors cursor-pointer"
              title={tr('rule_toggle_hint', {
                hint: tr(rule.hintKey),
                state: setup.rules[rule.key] ? tr('rule_on') : tr('rule_off'),
              })}
            >
              <input
                type="checkbox"
                class="mt-1 accent-[var(--accent)] rounded border-zinc-700 bg-zinc-900 cursor-pointer"
                bind:checked={setup.rules[rule.key]}
              />
              <div class="flex flex-col gap-0.5">
                <span class="text-xs font-medium text-zinc-200">{tr(rule.labelKey)}</span>
                <span class="text-[length:var(--font-size-2xs)] text-zinc-500"
                  >{tr(rule.hintKey)}</span
                >
              </div>
            </label>
          {/each}
        </div>
      {:else if setup.method === 'ai' && llmMode === 'api'}
        <p
          class="text-xs text-[var(--amber)] rounded-xl px-3 py-3 leading-relaxed"
          style="background: color-mix(in srgb, var(--amber) 12%, transparent)"
        >
          {tr('batch_ai_warn', { count: files.length })}
        </p>
      {/if}
    </div>
  {/if}

  {#if heavyCount > 0}
    <div
      class="flex items-start gap-3 rounded-xl px-4 py-3.5 text-xs leading-normal"
      style="background: color-mix(in srgb, var(--accent) 10%, transparent); color: var(--text-primary)"
    >
      <svg
        class="flex-shrink-0 mt-0.5"
        width="14"
        height="14"
        viewBox="0 0 16 16"
        fill="none"
        aria-hidden="true"
      >
        <circle cx="8" cy="8" r="6.3" stroke="currentColor" stroke-width="1.3" />
        <path
          d="M8 4.5V8l2.3 1.5"
          stroke="currentColor"
          stroke-width="1.3"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
      <span>
        {heavyCount === 1
          ? tr('ocr_notice_1', { count: heavyCount })
          : tr('ocr_notice_n', { count: heavyCount })}
      </span>
    </div>
  {/if}

  <button
    class="btn-primary btn-cta"
    onclick={convert}
    disabled={!canConvert}
    title={needsFolder ? tr('need_folder') : tr('convert_btn')}
  >
    <svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true">
      <path
        d="M10 2.5l1.6 4.1 4.4.3-3.4 2.8 1.1 4.3L10 11.8 6.3 14l1.1-4.3L4 6.9l4.4-.3L10 2.5z"
        fill="currentColor"
      />
    </svg>
    {tr('convert_btn')}
  </button>
</div>

<style>
  /* Canonical .btn-* live outside any @layer (unlayered), so Tailwind's
     @layer utilities can't override them. Restore the circular shape and the
     destructive red hover via scoped rules — scoped styles are also unlayered
     and win on specificity. */
  .icon-circle {
    border-radius: 999px;
  }
  .icon-remove:hover:not(:disabled) {
    color: var(--red);
  }
</style>
