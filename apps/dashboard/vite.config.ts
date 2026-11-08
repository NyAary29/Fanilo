import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    css: false,
    // Les tests tournent toujours contre l'adaptateur mock, jamais contre un backend réel.
    env: { VITE_USE_MOCKS: 'true', VITE_API_URL: 'http://api.test' },
  },
});
