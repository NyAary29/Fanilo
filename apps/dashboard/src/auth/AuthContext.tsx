import { useQueryClient } from '@tanstack/react-query';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { useApiContext } from '../api/ApiProvider';
import { ApiError } from '../api/client';
import type { Me } from '../api/types';

export type AuthStatus = 'loading' | 'anonymous' | 'authenticated';

export interface AuthContextValue {
  status: AuthStatus;
  user: Me | null;
  /** Message affiché sur l'écran de connexion (session expirée, compte désactivé…). */
  notice: string | null;
  login(login: string, password: string): Promise<void>;
  logout(): Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const { client } = useApiContext();
  const queryClient = useQueryClient();
  const [user, setUser] = useState<Me | null>(null);
  const [status, setStatus] = useState<AuthStatus>(() => (client.hasSession() ? 'loading' : 'anonymous'));
  const [notice, setNotice] = useState<string | null>(null);

  const reset = useCallback(
    (message: string | null) => {
      setUser(null);
      setStatus('anonymous');
      setNotice(message);
      queryClient.clear(); // aucune donnée d'une session ne survit à la déconnexion
    },
    [queryClient],
  );

  const loadMe = useCallback(async () => {
    const me = await client.me();
    if (!me.is_active) {
      await client.logout();
      reset('Ce compte est désactivé.');
      return;
    }
    setUser(me);
    setStatus('authenticated');
    setNotice(null);
  }, [client, reset]);

  // Session expirée (rafraîchissement refusé) : retour à l'écran de connexion.
  useEffect(
    () => client.onSessionExpired(() => reset('Votre session a expiré. Veuillez vous reconnecter.')),
    [client, reset],
  );

  // Au chargement, reprise de session via le jeton de rafraîchissement éventuel.
  useEffect(() => {
    if (!client.hasSession()) return;
    let cancelled = false;
    loadMe().catch((error: unknown) => {
      if (cancelled) return;
      reset(error instanceof ApiError && error.status === 0 ? 'Serveur injoignable. Reconnectez-vous.' : null);
    });
    return () => {
      cancelled = true;
    };
  }, [client, loadMe, reset]);

  const login = useCallback(
    async (loginValue: string, password: string) => {
      await client.login(loginValue, password);
      await loadMe();
    },
    [client, loadMe],
  );

  const logout = useCallback(async () => {
    await client.logout();
    reset(null);
  }, [client, reset]);

  const value = useMemo<AuthContextValue>(
    () => ({ status, user, notice, login, logout }),
    [status, user, notice, login, logout],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth doit être utilisé sous <AuthProvider>.');
  return ctx;
}

/** Utilisateur connecté (à utiliser sous une route protégée). */
export function useCurrentUser(): Me {
  const { user } = useAuth();
  if (!user) throw new Error('Aucun utilisateur connecté.');
  return user;
}
