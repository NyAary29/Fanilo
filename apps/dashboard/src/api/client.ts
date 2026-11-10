import type { TokenStore } from './tokenStore';
import type { Me, TokenResponse } from './types';

export type RefreshOutcome = 'ok' | 'rejected' | 'network';

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

type QueryValue = string | number | boolean | null | undefined;

export interface RequestOptions {
  body?: unknown;
  query?: Record<string, QueryValue>;
  /** false pour les endpoints publics (`/auth/login`, `/auth/refresh`). */
  auth?: boolean;
  signal?: AbortSignal;
}

/** Erreur HTTP au format FastAPI `{"detail": ...}`. */
export class ApiError extends Error {
  readonly status: number;
  readonly detail: unknown;

  constructor(status: number, detail: unknown) {
    super(describeError(status, detail));
    this.name = 'ApiError';
    this.status = status;
    this.detail = detail;
  }
}

function detailToText(detail: unknown): string | null {
  if (typeof detail === 'string') return detail;
  if (Array.isArray(detail)) {
    // Erreurs de validation FastAPI : [{loc: [...], msg: "..."}]
    const parts = detail
      .map((d: unknown) => {
        if (d && typeof d === 'object' && 'msg' in d) {
          const loc = 'loc' in d && Array.isArray(d.loc) ? d.loc.filter((l: unknown) => l !== 'body').join('.') : '';
          return loc ? `${loc} : ${String(d.msg)}` : String(d.msg);
        }
        return null;
      })
      .filter((p): p is string => p !== null);
    return parts.length ? parts.join(' ; ') : null;
  }
  return null;
}

export function describeError(status: number, detail: unknown): string {
  const text = detailToText(detail);
  switch (status) {
    case 0:
      return 'Le serveur est injoignable. Vérifiez la connexion puis réessayez.';
    case 401:
      return 'Session expirée ou identifiants invalides.';
    case 403:
      return 'Accès refusé pour votre rôle ou votre site.';
    case 404:
      return 'Élément introuvable ou hors de votre périmètre.';
    case 409:
      return `Conflit : l'élément a changé ou l'opération n'est pas autorisée dans son état actuel.${text ? ` (${text})` : ''}`;
    case 422:
      return `Données invalides${text ? ` : ${text}` : '.'}`;
    default:
      return text ?? `Erreur du serveur (${status}).`;
  }
}

export interface ApiClientOptions {
  baseUrl: string;
  tokenStore: TokenStore;
  fetchImpl?: FetchLike;
}

/**
 * Client HTTP typé de l'API FANILO.
 *
 * - ajoute `Authorization: Bearer <access_token>` ;
 * - sur un 401, tente UN rafraîchissement (mutualisé entre requêtes concurrentes),
 *   puis rejoue la requête une fois ;
 * - si le rafraîchissement échoue, efface les jetons et prévient l'application
 *   (`onSessionExpired`) qui renvoie vers l'écran de connexion.
 */
export class ApiClient {
  private readonly baseUrl: string;
  private readonly tokens: TokenStore;
  private readonly fetchImpl: FetchLike;
  private refreshInFlight: Promise<RefreshOutcome> | null = null;
  private sessionExpiredListeners = new Set<() => void>();

  constructor({ baseUrl, tokenStore, fetchImpl }: ApiClientOptions) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.tokens = tokenStore;
    // Enveloppe : appeler `window.fetch` détaché de `window` lève « Illegal invocation ».
    this.fetchImpl = fetchImpl ?? ((input, init) => fetch(input, init));
  }

  onSessionExpired(listener: () => void): () => void {
    this.sessionExpiredListeners.add(listener);
    return () => this.sessionExpiredListeners.delete(listener);
  }

  hasSession(): boolean {
    return this.tokens.getAccessToken() !== null || this.tokens.getRefreshToken() !== null;
  }

  buildUrl(path: string, query?: Record<string, QueryValue>): string {
    const url = `${this.baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
    if (!query) return url;
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(query)) {
      if (value === undefined || value === null || value === '') continue;
      params.append(key, String(value));
    }
    const qs = params.toString();
    return qs ? `${url}?${qs}` : url;
  }

  async request<T>(method: string, path: string, options: RequestOptions = {}): Promise<T> {
    const auth = options.auth ?? true;
    // Après un rechargement, seul le jeton de rafraîchissement subsiste : on
    // rafraîchit d'abord plutôt que d'envoyer une requête vouée au 401.
    if (auth && this.tokens.getAccessToken() === null && this.tokens.getRefreshToken() !== null) {
      const outcome = await this.refresh();
      if (outcome === 'network') throw new ApiError(0, null);
      if (outcome === 'rejected') {
        this.expireSession();
        throw new ApiError(401, null);
      }
    }
    let response = await this.send(method, path, options, auth);

    if (response.status === 401 && auth) {
      const outcome = await this.refresh();
      if (outcome === 'network') {
        // Coupure passagère : on garde la session et on remonte une erreur réseau.
        throw new ApiError(0, null);
      }
      if (outcome === 'rejected') {
        this.expireSession();
        throw new ApiError(401, await readDetail(response));
      }
      response = await this.send(method, path, options, auth);
      if (response.status === 401) {
        this.expireSession();
      }
    }

    if (!response.ok) {
      throw new ApiError(response.status, await readDetail(response));
    }
    if (response.status === 204) {
      return undefined as T;
    }
    const text = await response.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }

  get<T>(path: string, query?: RequestOptions['query'], signal?: AbortSignal): Promise<T> {
    return this.request<T>('GET', path, { query, signal });
  }

  post<T>(path: string, body?: unknown): Promise<T> {
    return this.request<T>('POST', path, { body });
  }

  patch<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('PATCH', path, { body });
  }

  // --- Authentification ----------------------------------------------------

  async login(login: string, password: string): Promise<void> {
    const tokens = await this.request<TokenResponse>('POST', '/auth/login', {
      body: { login, password },
      auth: false,
    });
    this.tokens.setTokens(tokens);
  }

  me(): Promise<Me> {
    return this.get<Me>('/auth/me');
  }

  async logout(): Promise<void> {
    const refreshToken = this.tokens.getRefreshToken();
    this.tokens.clear();
    if (!refreshToken) return;
    try {
      await this.request<void>('POST', '/auth/logout', { body: { refresh_token: refreshToken }, auth: false });
    } catch {
      // Déconnexion locale effective même si le serveur est injoignable.
    }
  }

  /** Rafraîchit les jetons ; un seul appel réseau pour toutes les requêtes en attente. */
  refresh(): Promise<RefreshOutcome> {
    if (!this.refreshInFlight) {
      this.refreshInFlight = this.doRefresh().finally(() => {
        this.refreshInFlight = null;
      });
    }
    return this.refreshInFlight;
  }

  private async doRefresh(): Promise<RefreshOutcome> {
    const refreshToken = this.tokens.getRefreshToken();
    if (!refreshToken) return 'rejected';
    let response: Response;
    try {
      response = await this.send('POST', '/auth/refresh', { body: { refresh_token: refreshToken } }, false);
    } catch {
      return 'network';
    }
    if (!response.ok) {
      this.tokens.clear();
      return 'rejected';
    }
    try {
      const tokens = (await response.json()) as TokenResponse;
      this.tokens.setTokens(tokens);
      return 'ok';
    } catch {
      this.tokens.clear();
      return 'rejected';
    }
  }

  private expireSession(): void {
    this.tokens.clear();
    for (const listener of this.sessionExpiredListeners) listener();
  }

  private async send(method: string, path: string, options: RequestOptions, auth: boolean): Promise<Response> {
    const headers: Record<string, string> = { Accept: 'application/json' };
    // FormData (audio) : le navigateur fixe lui-même le Content-Type multipart.
    const isForm = typeof FormData !== 'undefined' && options.body instanceof FormData;
    if (options.body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
    if (auth) {
      const token = this.tokens.getAccessToken();
      if (token) headers.Authorization = `Bearer ${token}`;
    }
    try {
      return await this.fetchImpl(this.buildUrl(path, options.query), {
        method,
        headers,
        body: isForm ? (options.body as FormData) : options.body !== undefined ? JSON.stringify(options.body) : undefined,
        signal: options.signal,
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') throw error;
      throw new ApiError(0, null);
    }
  }
}

async function readDetail(response: Response): Promise<unknown> {
  try {
    const data: unknown = await response.json();
    if (data && typeof data === 'object' && 'detail' in data) return data.detail;
    return data;
  } catch {
    return null;
  }
}
