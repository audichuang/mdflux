<script lang="ts">
  // Horizontal multi-step indicator. Complete / active / error / pending.
  export interface Step {
    title: string;
    description?: string;
  }

  let {
    steps,
    current,
    error = false,
    done = false,
  }: {
    steps: Step[];
    current: number;
    error?: boolean;
    done?: boolean;
  } = $props();

  function stateOf(i: number): 'complete' | 'active' | 'error' | 'pending' {
    if (done) return 'complete';
    if (i < current) return 'complete';
    if (i === current) return error ? 'error' : 'active';
    return 'pending';
  }
</script>

<ol class="stepper" role="list">
  {#each steps as step, i}
    {@const st = stateOf(i)}
    <li class="step" data-state={st}>
      <div class="row">
        <span class="line left" class:on={i > 0 && i <= current} class:hide={i === 0}></span>
        <span class="marker" aria-hidden="true">
          {#if st === 'complete'}
            <svg
              viewBox="0 0 24 24"
              width="14"
              height="14"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 13l4 4L19 7" />
            </svg>
          {:else if st === 'error'}
            <svg
              viewBox="0 0 24 24"
              width="14"
              height="14"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          {:else if st === 'active'}
            <span class="dot"></span>
          {:else}
            <span class="num">{i + 1}</span>
          {/if}
        </span>
        <span class="line right" class:on={i < current} class:hide={i === steps.length - 1}></span>
      </div>
      <div class="labels">
        <span class="title">{step.title}</span>
        {#if step.description}
          <span class="desc">{step.description}</span>
        {/if}
      </div>
    </li>
  {/each}
</ol>

<style>
  .stepper {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    width: 100%;
    list-style: none;
    margin: 0;
    padding: 0;
    user-select: none;
  }
  .step {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    position: relative;
  }
  .row {
    display: flex;
    align-items: center;
    width: 100%;
    justify-content: center;
  }
  .line {
    height: 2px;
    flex: 1;
    background: var(--divider);
    transition: background var(--transition);
  }
  .line.on {
    background: var(--accent);
  }
  .line.hide {
    visibility: hidden;
  }
  .marker {
    flex-shrink: 0;
    width: 32px;
    height: 32px;
    border-radius: 999px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1.5px solid var(--border-strong);
    background: var(--surface-1);
    color: var(--text-muted);
    font-size: 11px;
    font-weight: 600;
    font-family: var(--font-mono);
    transition: all var(--transition);
  }
  .step[data-state='complete'] .marker {
    background: var(--accent);
    border-color: var(--accent-edge);
    color: var(--on-accent);
  }
  .step[data-state='active'] .marker {
    border-color: var(--accent);
    color: var(--accent);
    background: var(--surface-1);
    box-shadow: 0 0 0 4px var(--accent-dim);
  }
  .step[data-state='error'] .marker {
    background: var(--red);
    border-color: var(--red);
    color: var(--on-accent);
  }
  .dot {
    width: 10px;
    height: 10px;
    border-radius: 999px;
    background: var(--accent);
    animation: pulse 1.4s ease-in-out infinite;
  }
  .num {
    line-height: 1;
  }
  .labels {
    display: flex;
    flex-direction: column;
    gap: 2px;
    margin-top: 8px;
    padding: 0 4px;
  }
  .title {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted);
    transition: color var(--transition);
  }
  .step[data-state='active'] .title {
    color: var(--text-primary);
    font-weight: 700;
  }
  .step[data-state='complete'] .title {
    color: var(--text-secondary);
  }
  .step[data-state='error'] .title {
    color: var(--red);
  }
  .desc {
    font-size: 10px;
    color: var(--text-muted);
    line-height: 1.35;
  }
  @keyframes pulse {
    0%,
    100% {
      opacity: 1;
    }
    50% {
      opacity: 0.45;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .dot {
      animation: none;
    }
  }
</style>
