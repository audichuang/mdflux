<script lang="ts">
  import { untrack } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { tr } from './locale.svelte';
  import type { AppConfig } from './DiagnosticsView.svelte';

  // ── Types ──────────────────────────────────────────────────────────────────

  interface ProviderCheckResult {
    server?: string;
    reachable: boolean;
    detail: string;
    models?: string[];
    usable: boolean;
  }

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

  let providerResult = $state<ProviderCheckResult | null>(null);
  let providerChecking = $state(false);

  // Editable copies of config fields (committed on Check/Test).
  // untrack: intentionally capturing initial prop value only.
  let localBaseUrl = $state(untrack(() => config.local_base_url));
  let apiType = $state(untrack(() => config.api_type));
  let apiBaseUrl = $state(untrack(() => config.api_base_url));
  let apiKey = $state(untrack(() => config.api_key));
  let cleanupModel = $state(untrack(() => config.cleanup_model));
  let conversionModel = $state(untrack(() => config.conversion_model ?? ''));

  // Models offered in the cleanup-model dropdown: the currently-saved one plus
  // whatever the latest provider check returned.
  const modelOptions = $derived.by(() => {
    const arr: string[] = [];
    if (cleanupModel) arr.push(cleanupModel);
    for (const m of providerResult?.models ?? []) {
      if (!arr.includes(m)) {
        arr.push(m);
      }
    }
    return arr;
  });

  // Local edits are committed on Check/Test; no continuous sync needed.

  // ── Mode switch ────────────────────────────────────────────────────────────

  async function setMode(m: string) {
    providerResult = null;
    await onConfigChange({ ...config, llm_mode: m });
  }

  async function saveApiType(type: string) {
    apiType = type;
    providerResult = null;
    await onConfigChange({ ...config, api_type: type });
  }

  async function saveCleanupModel(m: string) {
    cleanupModel = m;
    await onConfigChange({ ...config, cleanup_model: m });
  }

  async function saveConversionModel(m: string) {
    conversionModel = m;
    await onConfigChange({ ...config, conversion_model: m });
  }

  async function toggleLlmConversion(enabled: boolean) {
    await onConfigChange({ ...config, llm_conversion: enabled });
  }

  // ── Provider check ─────────────────────────────────────────────────────────

  async function runProviderCheck() {
    providerChecking = true;
    providerResult = null;
    try {
      if (config.llm_mode === 'local') {
        await onConfigChange({ ...config, local_base_url: localBaseUrl });
        providerResult = await invoke<ProviderCheckResult>('check_provider', {
          provider: 'local',
          baseUrl: localBaseUrl,
          key: '',
        });
      } else if (config.llm_mode === 'api') {
        await onConfigChange({
          ...config,
          api_type: apiType,
          api_base_url: apiBaseUrl,
          api_key: apiKey,
        });
        providerResult = await invoke<ProviderCheckResult>('check_provider', {
          provider: apiType === 'anthropic' ? 'api_anthropic' : 'api_openai_compat',
          baseUrl: apiBaseUrl,
          key: apiKey,
        });
      }
    } catch (e) {
      providerResult = { reachable: false, detail: String(e), usable: false };
    } finally {
      providerChecking = false;
    }
  }
</script>

{#if active}
  <section class="section">
    <h2 class="section-title">{tr('section_llm')}</h2>

    <div class="seg mode-seg" role="group" aria-label={tr('intelligence')}>
      {#each [['off', 'mode_off'], ['local', 'mode_local'], ['api', 'mode_api']] as [m, key]}
        <button
          class="seg-btn"
          class:active={config.llm_mode === m}
          aria-pressed={config.llm_mode === m}
          onclick={() => setMode(m)}
        >
          {tr(key)}
        </button>
      {/each}
    </div>

    {#if config.llm_mode === 'off'}
      <p class="provider-note">{tr('llm_off_note')}</p>
    {:else if config.llm_mode === 'local'}
      <div class="provider-fields">
        <label class="field-label" for="local-url">{tr('server_url')}</label>
        <div class="field-row">
          <input
            id="local-url"
            class="field-input"
            bind:value={localBaseUrl}
            placeholder="http://localhost:11434"
            spellcheck="false"
            autocomplete="off"
          />
          <button
            class="btn-primary"
            title={tr('check_connection')}
            onclick={runProviderCheck}
            disabled={providerChecking}
          >
            {providerChecking ? tr('checking') : tr('check')}
          </button>
        </div>
        <p class="field-hint">{tr('local_url_hint')}</p>
        {#if providerResult}
          <div
            class="provider-result"
            class:result-ok={providerResult.usable}
            class:result-fail={!providerResult.usable}
          >
            <span class="dot dot-{providerResult.usable ? 'green' : 'red'}" aria-hidden="true"
            ></span>
            <span class="result-text">{providerResult.detail}</span>
          </div>
        {/if}
      </div>
    {:else}
      <div class="provider-fields">
        <label class="field-label" for="api-type">{tr('api_type')}</label>
        <select
          id="api-type"
          class="field-select"
          value={apiType}
          onchange={(e) => saveApiType((e.target as HTMLSelectElement).value)}
        >
          <option value="openai_compat">{tr('openai_compat')}</option>
          <option value="anthropic">{tr('anthropic')}</option>
        </select>

        {#if apiType === 'openai_compat'}
          <label class="field-label" for="api-url">{tr('base_url')}</label>
          <input
            id="api-url"
            class="field-input"
            bind:value={apiBaseUrl}
            placeholder="https://api.openai.com/v1"
            spellcheck="false"
            autocomplete="off"
          />
          <p class="field-hint">{tr('openai_url_hint')}</p>
        {:else}
          <p class="field-hint">{tr('anthropic_hint')}</p>
        {/if}

        <label class="field-label" for="api-key">{tr('api_key')}</label>
        <div class="field-row">
          <input
            id="api-key"
            type="password"
            class="field-input"
            bind:value={apiKey}
            placeholder={tr('paste_key')}
            autocomplete="off"
          />
          <button
            class="btn-primary"
            title={tr('test_api_key')}
            onclick={runProviderCheck}
            disabled={providerChecking}
          >
            {providerChecking ? tr('testing') : tr('test')}
          </button>
        </div>
        <p class="field-hint">{tr('key_storage_hint')}</p>

        {#if providerResult}
          <div
            class="provider-result"
            class:result-ok={providerResult.usable}
            class:result-fail={!providerResult.usable}
          >
            <span class="dot dot-{providerResult.usable ? 'green' : 'red'}" aria-hidden="true"
            ></span>
            <span class="result-text">{providerResult.detail}</span>
          </div>
        {/if}
      </div>
    {/if}

    {#if config.llm_mode !== 'off'}
      <div class="provider-fields cleanup-model-block hairline-t">
        <label class="field-label" for="cleanup-model">{tr('cleanup_model')}</label>
        <select
          id="cleanup-model"
          class="field-select"
          title={tr('tip_cleanup_model')}
          value={cleanupModel}
          onchange={(e) => saveCleanupModel((e.target as HTMLSelectElement).value)}
        >
          <option value="">{tr('auto_model')}</option>
          {#each modelOptions as m}
            <option value={m}>{m}</option>
          {/each}
        </select>
        {#if modelOptions.length === 0}
          <p class="field-hint">{tr('model_check_hint')}</p>
        {:else}
          <p class="field-hint">{tr('model_use_hint')}</p>
        {/if}
        {#if config.llm_mode === 'local'}
          <p class="field-hint rec-hint">{tr('model_rec_local')}</p>
        {/if}
      </div>

      <div class="provider-fields cleanup-model-block hairline-t">
        <div class="toggle-row">
          <label class="toggle-label" for="llm-conversion">{tr('llm_image_desc')}</label>
          <button
            id="llm-conversion"
            role="switch"
            aria-checked={config.llm_conversion}
            class="toggle-btn"
            class:toggle-on={config.llm_conversion}
            onclick={() => toggleLlmConversion(!config.llm_conversion)}
            title={tr('tip_llm_conversion')}
          >
            <span class="toggle-thumb"></span>
          </button>
        </div>
        <p class="field-hint">{tr('llm_image_hint')}</p>

        {#if config.llm_conversion}
          <label class="field-label" for="conversion-model">{tr('conversion_model')}</label>
          <select
            id="conversion-model"
            class="field-select"
            title={tr('tip_conversion_model')}
            value={conversionModel}
            onchange={(e) => saveConversionModel((e.target as HTMLSelectElement).value)}
          >
            <option value="">{tr('auto_model')}</option>
            {#each modelOptions as m}
              <option value={m}>{m}</option>
            {/each}
          </select>
          <p class="field-hint">{tr('conversion_model_hint')}</p>
        {/if}
      </div>
    {/if}
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
    font-size: var(--font-size-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-muted);
  }

  .dot {
    width: var(--indicator-sm);
    height: var(--indicator-sm);
    border-radius: 50%;
    flex-shrink: 0;
  }
  .dot-green {
    background: var(--green);
  }
  .dot-red {
    background: var(--red);
  }

  /* LLM mode uses global .seg / .seg-btn */
  .mode-seg {
    align-self: flex-start;
    max-width: 100%;
    overflow-x: auto;
  }
  .mode-seg > :global(.seg-btn) {
    white-space: nowrap;
  }
  .provider-note {
    font-size: var(--font-size-sm);
    color: var(--text-muted);
    padding: var(--sp-2) 0;
  }

  .provider-fields {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
  }
  .field-label {
    font-size: var(--font-size-xs);
    font-weight: 500;
    /* Required-field labels are necessary reading, not decorative — text-muted
       reads too faint here even where it clears AA. */
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .field-row {
    display: flex;
    flex-wrap: wrap;
    gap: var(--sp-2);
  }
  .field-input {
    flex: 1 1 16rem;
    min-width: 0;
    background: var(--surface-1);
    border: var(--stroke-hairline) solid var(--border);
    border-radius: var(--radius-sm);
    min-height: var(--control-h);
    padding-inline: var(--control-padding-inline);
    font-size: var(--font-size-sm);
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
  .field-select {
    background: var(--surface-1);
    border: var(--stroke-hairline) solid var(--border);
    border-radius: var(--radius-sm);
    min-height: var(--control-h);
    width: 100%;
    max-width: 100%;
    min-width: 0;
    padding-inline: var(--control-padding-inline);
    font-size: var(--font-size-sm);
    font-family: var(--font-ui);
    color: var(--text-primary);
    outline: none;
    cursor: pointer;
    align-self: flex-start;
  }
  .field-select:focus {
    border-color: var(--accent);
  }
  .field-hint {
    font-size: var(--font-size-xs);
    color: var(--text-secondary);
    line-height: 1.5;
  }
  .provider-result {
    display: flex;
    align-items: flex-start;
    gap: var(--sp-2);
    padding: var(--sp-2) var(--sp-3);
    border-radius: var(--radius-sm);
    font-size: var(--font-size-sm);
  }
  .result-text {
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
  }
  .result-ok {
    background: color-mix(in srgb, var(--green) 10%, var(--surface-1));
    color: var(--text-primary);
  }
  .result-fail {
    background: color-mix(in srgb, var(--red) 10%, var(--surface-1));
    color: var(--text-primary);
  }

  .cleanup-model-block {
    margin-top: var(--sp-3);
    padding-top: var(--sp-3);
  }

  /* LLM conversion toggle */
  .toggle-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--sp-3);
  }
  .toggle-label {
    font-size: var(--font-size-sm);
    color: var(--text-primary);
    cursor: pointer;
    flex: 1;
  }
  .toggle-btn {
    position: relative;
    width: 36px;
    height: 20px;
    background: var(--surface-3);
    border: var(--stroke-hairline) solid transparent;
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
    /* Fixed, not --on-accent: dark's --on-accent is now near-black for CTA text,
       which nearly vanishes on the off-state track (--surface-3). This flat warm
       grey clears >=3:1 against --surface-3 in both themes; on-state relies on
       track colour + thumb position (same pattern most OS toggles use) plus the
       border below for an edge when the track is close in tone. */
    background: #867f74;
    border: var(--stroke-hairline) solid var(--border-strong);
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
