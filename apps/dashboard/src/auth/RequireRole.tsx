import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import type { Role } from '../api/types';
import { useAuth } from './AuthContext';
import { hasRole } from './permissions';

/**
 * Garde de route selon le rôle renvoyé par `/auth/me`.
 *
 * ⚠️ Contrôle ERGONOMIQUE uniquement : il évite d'afficher un écran inutile, mais ne
 * protège aucune donnée. L'API applique seule les autorisations (403 / 404).
 */
export function RequireRole({ roles, children }: { roles?: readonly Role[]; children: ReactNode }) {
  const { status, user } = useAuth();
  const location = useLocation();

  if (status === 'loading') {
    return (
      <p role="status" className="muted">
        Chargement de la session…
      </p>
    );
  }
  if (status === 'anonymous' || !user) {
    return <Navigate to="/connexion" replace state={{ from: location.pathname }} />;
  }
  if (roles && !hasRole(user, roles)) {
    return (
      <section aria-labelledby="forbidden-title" className="panel">
        <h1 id="forbidden-title">Accès non autorisé</h1>
        <p>Votre rôle ne donne pas accès à cet écran.</p>
      </section>
    );
  }
  return <>{children}</>;
}
