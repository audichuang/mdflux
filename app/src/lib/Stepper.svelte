<script lang="ts">
  // Horizontal multi-step indicator, modelled on Nuxt UI's <UStepper>.
  // Steps before `current` render as complete (check), `current` is active,
  // the rest are pending. When `error` is set, the active step turns red.
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

<ol class="flex items-center justify-between w-full select-none" role="list">
  {#each steps as step, i}
    {@const st = stateOf(i)}
    <li class="flex-1 flex flex-col items-center text-center relative" data-state={st}>
      <div class="flex items-center w-full justify-center">
        <!-- Left line -->
        <span
          class="h-[2px] flex-1 transition-colors duration-300 {i === 0 ? 'invisible' : ''} {i <=
            current && i > 0
            ? 'bg-blue-500'
            : 'bg-zinc-800'}"
        ></span>

        <!-- Marker -->
        <span
          class="flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center border-2 text-xs font-semibold font-mono transition-all duration-300
          {st === 'complete' ? 'bg-blue-500 border-blue-500 text-zinc-950' : ''}
          {st === 'active'
            ? 'border-blue-500 text-blue-500 shadow-[0_0_0_4px_rgba(59,130,246,0.15)] bg-zinc-900'
            : ''}
          {st === 'error' ? 'bg-red-500 border-red-500 text-zinc-950' : ''}
          {st === 'pending' ? 'border-zinc-850 bg-zinc-900/60 text-zinc-500' : ''}"
          aria-hidden="true"
        >
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
            <span class="w-2.5 h-2.5 rounded-full bg-blue-500 animate-pulse"></span>
          {:else}
            <span>{i + 1}</span>
          {/if}
        </span>

        <!-- Right line -->
        <span
          class="h-[2px] flex-1 transition-colors duration-300 {i === steps.length - 1
            ? 'invisible'
            : ''} {i < current ? 'bg-blue-500' : 'bg-zinc-800'}"
        ></span>
      </div>

      <div class="flex flex-col gap-0.5 mt-2 px-1">
        <span
          class="text-xs font-semibold transition-colors duration-300
          {st === 'active' ? 'text-zinc-50 font-bold' : ''}
          {st === 'complete' ? 'text-zinc-300' : ''}
          {st === 'error' ? 'text-red-400' : ''}
          {st === 'pending' ? 'text-zinc-500' : ''}"
        >
          {step.title}
        </span>
        {#if step.description}
          <span class="text-[10px] text-zinc-500 leading-normal">{step.description}</span>
        {/if}
      </div>
    </li>
  {/each}
</ol>
