/** Configuration lue au build par Vite (variables `VITE_*`). */
export interface AppConfig {
  apiUrl: string;
  useMocks: boolean;
}

export function readConfig(env: ImportMetaEnv = import.meta.env): AppConfig {
  const useMocks = env.VITE_USE_MOCKS === 'true' || env.MODE === 'mock';
  const apiUrl = (env.VITE_API_URL as string | undefined)?.trim() || (useMocks ? 'http://mock.local' : '');
  if (!apiUrl) {
    throw new Error('VITE_API_URL est obligatoire (ou activez VITE_USE_MOCKS=true). Voir apps/dashboard/.env.example.');
  }
  return { apiUrl, useMocks };
}
