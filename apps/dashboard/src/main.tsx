import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createApi } from './api/ApiProvider';
import type { FetchLike } from './api/client';
import { readConfig } from './api/config';
import { createTokenStore } from './api/tokenStore';
import { App } from './App';
import './styles/tokens.css';
import './styles/global.css';

async function bootstrap() {
  const config = readConfig();
  let fetchImpl: FetchLike | undefined;
  if (config.useMocks) {
    // Mode mock : adaptateur `fetch` maison sur des données FICTIVES, aucun appel réseau.
    // Import dynamique : le code mock part dans un fichier séparé, chargé seulement ici.
    const { createMockServer } = await import('./api/mock/mockFetch');
    fetchImpl = createMockServer({ latencyMs: 200 }).fetch;
  }
  const api = createApi({ baseUrl: config.apiUrl, tokenStore: createTokenStore(), fetchImpl, isMock: config.useMocks });

  const root = document.getElementById('root');
  if (!root) throw new Error('#root introuvable');
  createRoot(root).render(
    <StrictMode>
      <App api={api} />
    </StrictMode>,
  );
}

void bootstrap();
