import { render } from '@testing-library/react';
import { createApi } from '../api/ApiProvider';
import { createMockServer, type MockServer } from '../api/mock/mockFetch';
import { createTokenStore } from '../api/tokenStore';
import { App } from '../App';

/** Monte l'application complète sur l'adaptateur mock, éventuellement déjà connectée. */
export async function renderApp(path: string, options: { login?: string; server?: MockServer } = {}) {
  const server = options.server ?? createMockServer();
  const tokenStore = createTokenStore(window.sessionStorage);
  const api = createApi({ baseUrl: 'http://api.test', tokenStore, fetchImpl: server.fetch, isMock: true });
  if (options.login) await api.client.login(options.login, 'demo');
  const view = render(<App api={api} initialPath={path} />);
  return { ...view, server, api, tokenStore };
}
