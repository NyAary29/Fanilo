import { describe, expect, it, vi } from 'vitest';
import { ApiClient, ApiError, type FetchLike } from './client';
import { createMockServer } from './mock/mockFetch';
import { createTokenStore, REFRESH_TOKEN_KEY } from './tokenStore';

const BASE = 'http://api.test';

function jsonResponse(status: number, body: unknown) {
  return new Response(status === 204 ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function setup(fetchImpl: FetchLike) {
  const tokenStore = createTokenStore(window.sessionStorage);
  const client = new ApiClient({ baseUrl: `${BASE}/`, tokenStore, fetchImpl });
  return { client, tokenStore };
}

describe('ApiClient', () => {
  it("construit l'URL depuis la base et ignore les paramètres vides", () => {
    const { client } = setup(vi.fn());
    expect(client.buildUrl('/alerts', { status: 'open', limit: 25, offset: undefined, site_id: '' })).toBe(
      `${BASE}/alerts?status=open&limit=25`,
    );
  });

  it("envoie l'en-tête Authorization après connexion", async () => {
    const fetchMock = vi.fn<FetchLike>(async (url) => {
      if (url.endsWith('/auth/login')) {
        return jsonResponse(200, { access_token: 'A1', token_type: 'bearer', expires_in: 900, refresh_token: 'R1', refresh_expires_in: 3600 });
      }
      return jsonResponse(200, { id: 'u', login: 'x', role: 'admin', site_id: null, is_active: true });
    });
    const { client, tokenStore } = setup(fetchMock);
    await client.login('x', 'y');
    await client.me();
    const [, init] = fetchMock.mock.calls[1]!;
    expect(new Headers(init?.headers).get('Authorization')).toBe('Bearer A1');
    expect(tokenStore.getAccessToken()).toBe('A1');
    expect(window.sessionStorage.getItem(REFRESH_TOKEN_KEY)).toBe('R1');
  });

  it('sur 401, rafraîchit une seule fois (rotation) puis rejoue la requête', async () => {
    const server = createMockServer();
    const { client, tokenStore } = setup(server.fetch);
    await client.login('chef.csb', 'demo');
    const firstRefresh = tokenStore.getRefreshToken();
    server.expireAccessTokens();

    const me = await client.me();
    expect(me.login).toBe('chef.csb');
    expect(server.calls.filter((c) => c.path === '/auth/refresh')).toHaveLength(1);
    expect(tokenStore.getRefreshToken()).not.toBe(firstRefresh);
  });

  it('mutualise le rafraîchissement entre requêtes concurrentes', async () => {
    const server = createMockServer();
    const { client } = setup(server.fetch);
    await client.login('chef.csb', 'demo');
    server.expireAccessTokens();

    await Promise.all([client.me(), client.get('/alerts'), client.get('/sites')]);
    expect(server.calls.filter((c) => c.path === '/auth/refresh')).toHaveLength(1);
  });

  it('déconnecte (efface les jetons, prévient l’application) si le rafraîchissement échoue', async () => {
    const server = createMockServer();
    const { client, tokenStore } = setup(server.fetch);
    await client.login('chef.csb', 'demo');
    server.expireAccessTokens();
    window.sessionStorage.setItem(REFRESH_TOKEN_KEY, 'jeton-revoque');
    const expired = vi.fn();
    client.onSessionExpired(expired);

    await expect(client.me()).rejects.toMatchObject({ status: 401 });
    expect(expired).toHaveBeenCalledTimes(1);
    expect(tokenStore.getAccessToken()).toBeNull();
    expect(tokenStore.getRefreshToken()).toBeNull();
  });

  it('ne tente pas de rafraîchir sur un échec de connexion', async () => {
    const server = createMockServer();
    const { client } = setup(server.fetch);
    await expect(client.login('chef.csb', 'mauvais')).rejects.toBeInstanceOf(ApiError);
    expect(server.calls.some((c) => c.path === '/auth/refresh')).toBe(false);
  });

  it('garde la session en cas de coupure réseau pendant le rafraîchissement', async () => {
    let offline = false;
    const server = createMockServer();
    const fetchImpl: FetchLike = (url, init) => (offline && url.endsWith('/auth/refresh') ? Promise.reject(new TypeError('Failed to fetch')) : server.fetch(url, init));
    const { client, tokenStore } = setup(fetchImpl);
    await client.login('chef.csb', 'demo');
    server.expireAccessTokens();
    offline = true;
    const expired = vi.fn();
    client.onSessionExpired(expired);

    await expect(client.me()).rejects.toMatchObject({ status: 0 });
    expect(expired).not.toHaveBeenCalled();
    expect(tokenStore.getRefreshToken()).not.toBeNull();
  });

  it('traduit les erreurs FastAPI (422, 403, 409) en messages français', async () => {
    const { client } = setup(async (url) => {
      if (url.includes('422')) return jsonResponse(422, { detail: [{ loc: ['body', 'reason'], msg: 'Field required' }] });
      if (url.includes('403')) return jsonResponse(403, { detail: 'Forbidden' });
      return jsonResponse(409, { detail: 'Transition refusée' });
    });
    await expect(client.get('/422')).rejects.toThrow('Données invalides : reason : Field required');
    await expect(client.get('/403')).rejects.toThrow('Accès refusé');
    await expect(client.get('/409')).rejects.toThrow(/Conflit.*Transition refusée/);
  });

  it('logout efface localement même si le serveur est injoignable', async () => {
    const { client, tokenStore } = setup(async () => {
      throw new TypeError('offline');
    });
    tokenStore.setTokens({ access_token: 'a', refresh_token: 'r' });
    await client.logout();
    expect(tokenStore.getRefreshToken()).toBeNull();
  });
});
