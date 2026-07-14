import svelte from 'eslint-plugin-svelte';
import tseslint from 'typescript-eslint';
import svelteParser from 'svelte-eslint-parser';

export default tseslint.config(
  ...tseslint.configs.recommended,
  ...svelte.configs['flat/recommended'],
  {
    files: ['**/*.svelte'],
    languageOptions: {
      parser: svelteParser,
      parserOptions: {
        parser: tseslint.parser,
      },
    },
    rules: {
      'svelte/no-at-html-tags': 'off',
      'svelte/require-each-key': 'off',
    },
  },
  // Svelte 5 rune modules (.svelte.ts / .svelte.js) need the TS parser nested
  // under svelte-eslint-parser — otherwise `export type` fails as Unexpected token.
  {
    files: ['**/*.svelte.ts', '**/*.svelte.js'],
    languageOptions: {
      parser: svelteParser,
      parserOptions: {
        parser: tseslint.parser,
      },
    },
  },
  {
    ignores: ['.svelte-kit/', 'dist/', 'build/', 'src-tauri/', 'node_modules/'],
  },
);
