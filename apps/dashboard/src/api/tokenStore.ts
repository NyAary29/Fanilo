import type { TokenResponse } from './types';

/**
 * Stockage des jetons.
 *
 * DÉCISION (voir README, « Jetons et risque XSS ») :
 * - le jeton d'accès (courte durée) reste UNIQUEMENT en mémoire (variable de module) ;
 *   il n'est jamais écrit dans un stockage du navigateur ;
 * - le jeton de rafraîchissement est conservé dans `sessionStorage`, pour survivre à un
 *   rechargement de l'onglet (fréquent sur tablette avec une connexion instable). Il est
 *   effacé à la fermeture de l'onglet, à la déconnexion et à tout échec de rafraîchissement,
 *   et il tourne à chaque rafraîchissement (rotation côté serveur).
 *
 * RISQUE : un script injecté (XSS) dans l'origine du dashboard peut lire `sessionStorage`
 * et exfiltrer le jeton de rafraîchissement. RECOMMANDATION À TERME : que le backend émette
 * le jeton de rafraîchissement dans un cookie `HttpOnly; Secure; SameSite=Strict` limité au
 * chemin `/auth`, inaccessible au JavaScript. Ce module est alors simplifié (jeton d'accès
 * en mémoire seulement). Une CSP stricte reste nécessaire dans tous les cas.
 */
export interface TokenStore {
  getAccessToken(): string | null;
  getRefreshToken(): string | null;
  setTokens(tokens: Pick<TokenResponse, 'access_token' | 'refresh_token'>): void;
  clear(): void;
}

export const REFRESH_TOKEN_KEY = 'fanilo.dashboard.refresh_token';

function safeStorage(storage: Storage | null | undefined): Storage | null {
  if (!storage) return null;
  try {
    const probe = '__fanilo_probe__';
    storage.setItem(probe, '1');
    storage.removeItem(probe);
    return storage;
  } catch {
    return null; // navigation privée, stockage bloqué : on retombe sur la mémoire
  }
}

export function createTokenStore(storage?: Storage | null): TokenStore {
  const persistent = safeStorage(
    storage === undefined ? (typeof window !== 'undefined' ? window.sessionStorage : null) : storage,
  );
  let accessToken: string | null = null;
  let refreshTokenInMemory: string | null = null;

  return {
    getAccessToken: () => accessToken,
    getRefreshToken() {
      if (persistent) {
        try {
          return persistent.getItem(REFRESH_TOKEN_KEY);
        } catch {
          return refreshTokenInMemory;
        }
      }
      return refreshTokenInMemory;
    },
    setTokens({ access_token, refresh_token }) {
      accessToken = access_token;
      refreshTokenInMemory = refresh_token;
      if (persistent) {
        try {
          persistent.setItem(REFRESH_TOKEN_KEY, refresh_token);
        } catch {
          /* la copie en mémoire suffit */
        }
      }
    },
    clear() {
      accessToken = null;
      refreshTokenInMemory = null;
      if (persistent) {
        try {
          persistent.removeItem(REFRESH_TOKEN_KEY);
        } catch {
          /* rien à faire */
        }
      }
    },
  };
}
