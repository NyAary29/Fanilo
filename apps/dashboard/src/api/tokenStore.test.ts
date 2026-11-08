import { describe, expect, it } from 'vitest';
import { createTokenStore, REFRESH_TOKEN_KEY } from './tokenStore';

describe('tokenStore', () => {
  it("garde le jeton d'accès en mémoire seulement et le jeton de rafraîchissement en sessionStorage", () => {
    const store = createTokenStore(window.sessionStorage);
    store.setTokens({ access_token: 'acc', refresh_token: 'ref' });
    expect(store.getAccessToken()).toBe('acc');
    expect(store.getRefreshToken()).toBe('ref');
    expect(window.sessionStorage.getItem(REFRESH_TOKEN_KEY)).toBe('ref');
    expect(JSON.stringify({ ...window.sessionStorage })).not.toContain('acc');
    expect(JSON.stringify({ ...window.localStorage })).not.toContain('ref');
  });

  it('efface tout à la déconnexion', () => {
    const store = createTokenStore(window.sessionStorage);
    store.setTokens({ access_token: 'acc', refresh_token: 'ref' });
    store.clear();
    expect(store.getAccessToken()).toBeNull();
    expect(store.getRefreshToken()).toBeNull();
    expect(window.sessionStorage.getItem(REFRESH_TOKEN_KEY)).toBeNull();
  });

  it('retombe sur la mémoire si le stockage est indisponible', () => {
    const broken = {
      setItem: () => {
        throw new Error('bloqué');
      },
    } as unknown as Storage;
    const store = createTokenStore(broken);
    store.setTokens({ access_token: 'a', refresh_token: 'r' });
    expect(store.getRefreshToken()).toBe('r');
  });
});
