<script lang="ts">
  import { untrack } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { buildOutputFilename, type NamingCase } from './naming';
  import { tr } from './locale.svelte';
  import type { AppConfig } from './DiagnosticsView.svelte';

  // ── Props ──────────────────────────────────────────────────────────────────

  let {
    active,
    config,
    onConfigChange,
  }: {
    active: boolean;
    config: AppConfig;
    onConfigChange: (c: AppConfig) => Promise<void>;
  } = $props();

  // ── State ──────────────────────────────────────────────────────────────────

  // Stage 7 — output management. Template is edited locally for a live preview,
  // committed on change; rule/case/folder/toggle read config directly (reactive).
  let namingTemplate = $state(untrack(() => config.naming_template ?? '{stem}'));
  const namePreview = $derived(
    buildOutputFilename(
      'Annual Report.pdf',
      namingTemplate,
      (config.naming_case ?? 'keep') as NamingCase,
    ),
  );

  // ── Stage 7: output management ───────────────────────────────────────────────

  async function saveOutputRule(rule: string) {
    await onConfigChange({ ...config, output_rule: rule });
  }
  async function chooseOutputFolder() {
    const sel = await invoke<string | null>('pick_folder');
    if (sel) await onConfigChange({ ...config, output_folder: sel });
  }
  async function clearOutputFolder() {
    await onConfigChange({ ...config, output_folder: '' });
  }
  async function saveNamingTemplate() {
    const t = namingTemplate.trim() || '{stem}';
    namingTemplate = t;
    await onConfigChange({ ...config, naming_template: t });
  }
  function applyTemplatePreset(t: string) {
    namingTemplate = t;
    saveNamingTemplate();
  }
  async function saveNamingCase(c: string) {
    await onConfigChange({ ...config, naming_case: c });
  }
  async function toggleOpenAfter(v: boolean) {
    await onConfigChange({ ...config, open_after_convert: v });
  }
</script>

{#if active}
  <section class="section">
    <h2 class="section-title">{tr('section_output')}</h2>

    <div class="provider-fields">
      <span class="field-label">{tr('where_to_save')}</span>
      <div class="seg" role="group" aria-label={tr('output_destination')}>
        <button
          class="seg-btn"
          class:active={config.output_rule === 'next_to_source'}
          aria-pressed={config.output_rule === 'next_to_source'}
          title={tr('tip_write_next')}
          onclick={() => saveOutputRule('next_to_source')}>{tr('next_to_source')}</button
        >
        <button
          class="seg-btn"
          class:active={config.output_rule === 'fixed_folder'}
          aria-pressed={config.output_rule === 'fixed_folder'}
          title={tr('tip_write_folder')}
          onclick={() => saveOutputRule('fixed_folder')}>{tr('one_folder')}</button
        >
        <button
          class="seg-btn"
          class:active={config.output_rule === 'mirror_tree'}
          aria-pressed={config.output_rule === 'mirror_tree'}
          title={tr('tip_write_mirror')}
          onclick={() => saveOutputRule('mirror_tree')}>{tr('mirror_folders')}</button
        >
      </div>

      {#if config.output_rule !== 'next_to_source'}
        <div class="folder-row">
          <svg
            class="folder-icon"
            width="15"
            height="15"
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
            class="folder-value"
            class:folder-unset={!config.output_folder}
            title={config.output_folder || tr('no_folder_yet')}
          >
            {config.output_folder || tr('no_folder_chosen')}
          </span>
          {#if config.output_folder}
            <button
              class="mini-x"
              title={tr('clear_folder')}
              aria-label={tr('clear_folder')}
              onclick={clearOutputFolder}
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true"
                ><path
                  d="M2 2l6 6M8 2l-6 6"
                  stroke="currentColor"
                  stroke-width="1.5"
                  stroke-linecap="round"
                /></svg
              >
            </button>
          {/if}
          <button class="change-btn" onclick={chooseOutputFolder}
            >{config.output_folder ? tr('change') : tr('choose_folder')}</button
          >
        </div>
        {#if config.output_rule === 'mirror_tree'}
          <p class="field-hint">{tr('mirror_tree_hint')}</p>
        {/if}
      {/if}
      <p class="field-hint">{tr('save_naming_hint')}</p>
    </div>

    <div class="provider-fields cleanup-model-block">
      <label class="field-label" for="naming-template">{tr('file_name')}</label>
      <input
        id="naming-template"
        class="field-input"
        bind:value={namingTemplate}
        onchange={saveNamingTemplate}
        spellcheck="false"
        autocomplete="off"
        placeholder={'{stem}'}
      />
      <div class="preset-row">
        <button class="preset" title={tr('tip_stem')} onclick={() => applyTemplatePreset('{stem}')}
          >{'{stem}'}</button
        >
        <button
          class="preset"
          title={tr('tip_stem_ext')}
          onclick={() => applyTemplatePreset('{stem}_{ext}')}>{'{stem}_{ext}'}</button
        >
        <button
          class="preset"
          title={tr('tip_stem_date')}
          onclick={() => applyTemplatePreset('{stem}-{date}')}>{'{stem}-{date}'}</button
        >
      </div>
      <p class="field-hint">{tr('naming_tokens_hint')}</p>

      <span class="field-label">{tr('letter_case')}</span>
      <div class="seg" role="group" aria-label={tr('letter_case')}>
        <button
          class="seg-btn"
          class:active={config.naming_case === 'keep'}
          aria-pressed={config.naming_case === 'keep'}
          title={tr('tip_keep')}
          onclick={() => saveNamingCase('keep')}>{tr('naming_case_keep')}</button
        >
        <button
          class="seg-btn"
          class:active={config.naming_case === 'lower'}
          aria-pressed={config.naming_case === 'lower'}
          title={tr('tip_lower')}
          onclick={() => saveNamingCase('lower')}>{tr('naming_case_lower')}</button
        >
        <button
          class="seg-btn"
          class:active={config.naming_case === 'slug'}
          aria-pressed={config.naming_case === 'slug'}
          title={tr('tip_slug')}
          onclick={() => saveNamingCase('slug')}>{tr('naming_case_slug')}</button
        >
      </div>

      <p class="name-preview">
        <span class="np-from">Annual Report.pdf</span>
        <span class="np-arrow" aria-hidden="true">→</span>
        <span class="np-to">{namePreview}</span>
      </p>
    </div>

    <div class="provider-fields cleanup-model-block">
      <div class="toggle-row">
        <label class="toggle-label" for="open-after">{tr('open_after_batch')}</label>
        <button
          id="open-after"
          role="switch"
          aria-checked={config.open_after_convert}
          class="toggle-btn"
          class:toggle-on={config.open_after_convert}
          onclick={() => toggleOpenAfter(!config.open_after_convert)}
          title={tr('reveal_folder_desc')}
        >
          <span class="toggle-thumb"></span>
        </button>
      </div>
    </div>
  </section>
{/if}

<style>
  /* Section */
  .section {
    display: flex;
    flex-direction: column;
    gap: var(--sp-3);
  }
  .section-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-muted);
  }

  .provider-fields {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }
  .field-label {
    font-size: 10.5px;
    font-weight: 500;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .field-input {
    flex: 1;
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 6px var(--sp-3);
    font-size: 12px;
    font-family: var(--font-mono);
    color: var(--text-primary);
    outline: none;
    transition: all var(--transition-fast);
  }
  .field-input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 2px var(--accent-dim);
  }
  .field-input::placeholder {
    color: var(--text-muted);
  }
  .field-hint {
    font-size: 11px;
    color: var(--text-muted);
    line-height: 1.5;
  }

  .cleanup-model-block {
    margin-top: var(--sp-3);
    padding-top: var(--sp-3);
    border-top: 1px solid var(--border);
  }
  /* Stage 7 — output management */
  .folder-row {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    padding: var(--sp-2) var(--sp-3);
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }
  .folder-icon {
    flex-shrink: 0;
    color: var(--accent);
  }
  .folder-value {
    flex: 1;
    min-width: 0;
    font-size: 12px;
    color: var(--text-primary);
    font-family: var(--font-mono);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .folder-unset {
    color: var(--text-muted);
    font-family: var(--font-ui);
    font-style: italic;
  }
  .mini-x {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    border: none;
    background: var(--surface-2);
    color: var(--text-muted);
    cursor: pointer;
  }
  .mini-x:hover {
    color: var(--text-primary);
    background: var(--border);
  }
  .change-btn {
    flex-shrink: 0;
    padding: 6px 13px;
    font-size: 12px;
    font-weight: 600;
    font-family: var(--font-ui);
    color: var(--accent);
    background: color-mix(in srgb, var(--accent) 18%, transparent);
    border: 1px solid color-mix(in srgb, var(--accent) 50%, transparent);
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition:
      background var(--transition-fast),
      color var(--transition-fast),
      border-color var(--transition-fast);
  }
  .change-btn:hover {
    background: var(--accent);
    color: var(--on-accent);
    border-color: var(--accent);
  }

  .preset-row {
    display: flex;
    gap: var(--sp-2);
    flex-wrap: wrap;
  }
  .preset {
    font-size: 11px;
    font-family: var(--font-mono);
    color: var(--text-secondary);
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 3px 9px;
    cursor: pointer;
    transition:
      color var(--transition-fast),
      border-color var(--transition-fast);
  }
  .preset:hover {
    color: var(--text-primary);
    border-color: var(--border-strong);
  }
  .preset:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--accent) 60%, transparent);
  }
  .name-preview {
    display: flex;
    align-items: center;
    gap: var(--sp-2);
    font-size: 12px;
    font-family: var(--font-mono);
    margin-top: var(--sp-1);
    padding: var(--sp-2) var(--sp-3);
    background: var(--surface-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }
  .np-from {
    color: var(--text-muted);
  }
  .np-arrow {
    color: var(--text-muted);
  }
  .np-to {
    color: var(--accent);
    font-weight: 600;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  /* Open-after toggle */
  .toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-3);
  }
  .toggle-label {
    font-size: 12px;
    color: var(--text-primary);
    cursor: pointer;
    flex: 1;
  }
  .toggle-btn {
    position: relative;
    width: 36px;
    height: 20px;
    background: var(--surface-3);
    border: 1px solid transparent;
    border-radius: 99px;
    cursor: pointer;
    flex-shrink: 0;
    transition: background var(--transition-fast);
  }
  .toggle-btn.toggle-on {
    background: var(--accent);
  }
  .toggle-thumb {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 14px;
    height: 14px;
    background: var(--on-accent);
    border-radius: 50%;
    transition: transform var(--transition-fast);
    box-shadow: var(--seg-shadow);
  }
  .toggle-btn.toggle-on .toggle-thumb {
    transform: translateX(16px);
  }
  .toggle-btn:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--accent) 60%, transparent);
    outline-offset: 2px;
  }
</style>
