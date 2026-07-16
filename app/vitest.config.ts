import { defineConfig } from 'vitest/config';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      $lib: path.resolve(root, 'src/lib'),
    },
  },
  test: {
    name: 'mdflux-ui',
    // jsdom: DOMPurify sanitizes correctly (happy-dom strips headings / keeps script).
    environment: 'jsdom',
    include: ['src/**/*.{test,spec}.{js,ts}'],
    setupFiles: ['./vitest.setup.ts'],
    globals: false,
    restoreMocks: true,
    clearMocks: true,
  },
});
