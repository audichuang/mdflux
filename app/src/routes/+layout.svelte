<script lang="ts">
  import '@fontsource-variable/inter';
  import '@fontsource/jetbrains-mono/400.css';
  import '$lib/tokens.css';
  // Side-effect: restore theme preference + watch system scheme
  import '$lib/theme.svelte';

  let { children } = $props();
</script>

{@render children()}
