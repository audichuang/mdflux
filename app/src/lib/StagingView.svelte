<script module lang="ts">
  import { defaultRules } from './cleanup';
  import type { CleanupMethod } from './cleanup';
  import type { OutputRule } from './naming';

  // Svelte module exports stay identical
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
        { name: 'Supported files', extensions: SUPPORTED_EXTS },
        { name: 'All files', extensions: ['*'] },
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
    onConvert(setup.outputFolder, setup.outputRule, { method: setup.method, rules: setup.rules });
  }
</script>

<div class="w-full max-w-2xl mx-auto py-6 px-1 flex flex-col gap-6 h-full min-h-0 overflow-y-auto">
  <!-- Header -->
  <div class="flex items-baseline justify-between border-b border-zinc-800 pb-4">
    <div class="flex items-baseline gap-2">
      <span class="text-3xl font-bold font-mono tracking-tight text-zinc-50">{files.length}</span>
      <span class="text-sm font-medium text-zinc-400"
        >file{files.length === 1 ? '' : 's'} ready</span
      >
    </div>
    <button
      class="text-sm font-medium text-zinc-400 hover:text-zinc-100 underline underline-offset-4 cursor-pointer transition-colors"
      onclick={onClear}
      title="Remove all staged files">Clear all</button
    >
  </div>

  <!-- File list (drop more anywhere on this view) -->
  <div
    class="flex flex-col gap-2 p-3 border border-dashed border-zinc-800 rounded-lg bg-zinc-950/40 min-h-[120px] max-h-[260px] overflow-y-auto transition-colors duration-200 {dragHover
      ? 'border-blue-500 bg-blue-950/10'
      : ''}"
  >
    {#each files as f (f.path)}
      <div
        class="flex items-center gap-3 p-2.5 bg-zinc-900/30 border border-zinc-800/40 rounded-lg hover:bg-zinc-900/60 hover:border-zinc-800 transition-all group"
      >
        <span
          class="flex-shrink-0 text-[10px] font-bold font-mono px-2 py-0.5 rounded-md border border-zinc-800 bg-zinc-950 text-zinc-400 group-hover:text-blue-400 group-hover:border-blue-950 min-w-[48px] text-center uppercase tracking-wider transition-colors"
          >{f.ext || 'FILE'}</span
        >
        <span class="flex-1 min-w-0 text-sm font-medium text-zinc-300 truncate" title={f.path}
          >{f.name}</span
        >
        <span class="flex-shrink-0 text-xs font-mono text-zinc-500">{fmtSize(f.size)}</span>
        <button
          class="flex-shrink-0 flex items-center justify-center w-7 h-7 rounded-md border border-transparent hover:border-zinc-800 hover:bg-zinc-950 text-zinc-500 hover:text-red-400 transition-all cursor-pointer"
          title="Remove {f.name}"
          aria-label="Remove {f.name}"
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
    <span>Add more — drop files anywhere, or</span>
    <button
      class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-3.5 border border-zinc-800 bg-zinc-900/80 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors"
      onclick={browseFiles}>Choose files…</button
    >
    <button
      class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-3.5 border border-zinc-800 bg-zinc-900/80 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors"
      onclick={browseFolder}>Choose folder…</button
    >
  </div>

  {#if isBatch}
    <!-- Output destination (batch only; a single file is saved from the result view) -->
    <div class="flex flex-col gap-3 border-t border-zinc-800/60 pt-5">
      <span class="text-xs font-semibold tracking-wider text-zinc-400 uppercase"
        >Save output to</span
      >
      <div
        class="inline-flex h-10 items-center justify-start rounded-lg bg-zinc-900/60 p-1 text-zinc-400 border border-zinc-850 w-fit"
        role="group"
        aria-label="Output location"
      >
        <button
          class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-3.5 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.outputRule ===
          'next_to_source'
            ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
            : 'hover:text-zinc-200'}"
          title="Each .md is saved beside its source file"
          onclick={() => setRule('next_to_source')}>Next to source</button
        >
        <button
          class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-3.5 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.outputRule ===
          'fixed_folder'
            ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
            : 'hover:text-zinc-200'}"
          title="All .md files go into one chosen folder"
          onclick={() => setRule('fixed_folder')}>One folder</button
        >
        <button
          class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-3.5 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.outputRule ===
          'mirror_tree'
            ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
            : 'hover:text-zinc-200'}"
          title="Recreate the source folder structure under a chosen root"
          onclick={() => setRule('mirror_tree')}>Mirror folders</button
        >
      </div>

      {#if setup.outputRule !== 'next_to_source'}
        <div class="flex items-center gap-3 p-3 bg-zinc-900/20 border border-zinc-800 rounded-lg">
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
            title={setup.outputFolder ?? 'Choose a folder'}
          >
            {setup.outputFolder ?? 'No folder chosen'}
          </span>
          {#if setup.outputFolder}
            <button
              class="flex items-center justify-center w-5 h-5 rounded-full hover:bg-zinc-850 text-zinc-500 hover:text-zinc-200 cursor-pointer"
              title="Clear"
              aria-label="Clear folder"
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
            class="inline-flex items-center justify-center rounded-md text-xs font-semibold h-8 px-3 border border-zinc-800 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:text-zinc-50 cursor-pointer transition-colors"
            title="Pick the folder to save into"
            onclick={chooseFolder}>{setup.outputFolder ? 'Change…' : 'Choose folder…'}</button
          >
        </div>
        {#if setup.outputRule === 'mirror_tree'}
          <span class="text-xs text-zinc-500 leading-normal"
            >Sub-folders of the dropped folder are recreated under this root.</span
          >
        {/if}
      {/if}

      {#if namePreview}
        <div class="flex items-center gap-2 text-xs text-zinc-400">
          <span class="font-semibold tracking-wider text-[10px] text-zinc-500 uppercase">Named</span
          >
          <span class="font-mono text-zinc-300 font-semibold truncate max-w-[320px]"
            >{namePreview}</span
          >
          {#if onOpenDiagnostics}
            <button
              class="text-[11px] text-blue-400 hover:text-blue-300 underline underline-offset-2 transition-colors cursor-pointer bg-transparent border-none p-0"
              title="Change the naming convention in Diagnostics"
              onclick={onOpenDiagnostics}>Change…</button
            >
          {/if}
        </div>
      {/if}
    </div>

    <!-- Cleanup method (batch applies one choice to every file) -->
    <div class="flex flex-col gap-3 border-t border-zinc-800/60 pt-5">
      <div class="flex items-center gap-3 justify-between">
        <span class="text-xs font-semibold tracking-wider text-zinc-400 uppercase">Clean up</span>
        <div
          class="inline-flex h-10 items-center justify-start rounded-lg bg-zinc-900/60 p-1 text-zinc-400 border border-zinc-850"
          role="group"
          aria-label="Cleanup method"
        >
          <button
            class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-4 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.method ===
            'none'
              ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
              : 'hover:text-zinc-200'}"
            title="Convert files as-is, no cleanup"
            onclick={() => selectMethod('none')}>Off</button
          >
          <button
            class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-4 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.method ===
            'rules'
              ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
              : 'hover:text-zinc-200'}"
            title="Clean every file with fast, offline rules"
            onclick={() => selectMethod('rules')}>Rule-based</button
          >
          <button
            class="inline-flex items-center justify-center whitespace-nowrap rounded-md px-4 py-1.5 text-xs font-semibold transition-all duration-150 cursor-pointer {setup.method ===
            'ai'
              ? 'bg-zinc-950 text-zinc-50 shadow-sm border border-zinc-800'
              : 'hover:text-zinc-200'} disabled:pointer-events-none disabled:opacity-40"
            disabled={!llmAvailable}
            title={llmAvailable
              ? 'Clean every file with your configured AI model'
              : 'Switch to Local or API mode to enable AI cleanup'}
            onclick={() => selectMethod('ai')}>AI</button
          >
        </div>
      </div>

      {#if setup.method === 'rules'}
        <div class="flex flex-col gap-1 p-2 bg-zinc-950 border border-zinc-850 rounded-lg">
          {#each CLEANUP_RULES as rule}
            <label
              class="flex items-start gap-3 p-2.5 rounded-md hover:bg-zinc-900/40 transition-colors cursor-pointer"
              title="{rule.hint}. {setup.rules[rule.key] ? 'On' : 'Off'} — click to toggle."
            >
              <input
                type="checkbox"
                class="mt-1 accent-blue-500 rounded border-zinc-700 bg-zinc-900 text-blue-500 focus:ring-0 cursor-pointer"
                bind:checked={setup.rules[rule.key]}
              />
              <div class="flex flex-col gap-0.5">
                <span class="text-xs font-medium text-zinc-200">{rule.label}</span>
                <span class="text-[10px] text-zinc-500">{rule.hint}</span>
              </div>
            </label>
          {/each}
        </div>
      {:else if setup.method === 'ai' && llmMode === 'api'}
        <p
          class="text-xs text-amber-400 bg-amber-950/20 border border-amber-900/30 rounded-lg p-3 leading-relaxed"
        >
          ⚠ AI cleanup sends the text of all {files.length} files to your configured API provider — cost
          and privacy implications, once per file.
        </p>
      {/if}
    </div>
  {/if}

  {#if heavyCount > 0}
    <div
      class="flex items-start gap-3 rounded-lg border border-blue-950/60 bg-blue-950/15 px-4 py-3.5 text-xs text-blue-400 leading-normal"
    >
      <svg
        class="flex-shrink-0 mt-0.5 text-blue-400"
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
        {heavyCount}
        {heavyCount === 1 ? 'file needs' : 'files need'} OCR or transcription — expect a longer run{isBatch
          ? ' across the batch'
          : ''}, and the engine's model loads on first use.
      </span>
    </div>
  {/if}

  <button
    class="w-full flex items-center justify-center gap-2 h-12 rounded-lg text-sm font-semibold bg-zinc-50 hover:bg-zinc-200/90 text-zinc-950 shadow-sm transition-all cursor-pointer font-ui mt-2 active:translate-y-[1px]"
    onclick={convert}
  >
    <svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true">
      <path
        d="M10 2.5l1.6 4.1 4.4.3-3.4 2.8 1.1 4.3L10 11.8 6.3 14l1.1-4.3L4 6.9l4.4-.3L10 2.5z"
        fill="currentColor"
      />
    </svg>
    Convert to AI-Ready Markdown
  </button>
</div>
