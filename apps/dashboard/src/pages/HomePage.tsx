import { Navigate } from 'react-router-dom';
import { useCurrentUser } from '../auth/AuthContext';
import { homePathFor, ROLE_LABELS } from '../auth/permissions';

/** Redirige vers le premier écran autorisé, ou explique qu'aucun écran n'est prévu pour ce rôle. */
export function HomePage() {
  const user = useCurrentUser();
  const target = homePathFor(user);
  if (target !== '/accueil') return <Navigate to={target} replace />;
  return (
    <section className="panel">
      <h1>Bienvenue</h1>
      <p>
        Aucun écran du tableau de bord n&apos;est prévu pour le rôle « {ROLE_LABELS[user.role]} ». Les agents
        communautaires utilisent l&apos;application mobile.
      </p>
    </section>
  );
}

export function NotFoundPage() {
  return (
    <section className="panel">
      <h1>Page introuvable</h1>
      <p>L&apos;adresse demandée n&apos;existe pas.</p>
    </section>
  );
}
