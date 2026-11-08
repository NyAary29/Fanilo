import type { ReactNode } from 'react';
import { ApiError } from '../api/client';

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  if (error instanceof Error) return error.message;
  return 'Erreur inattendue.';
}

export function ErrorMessage({ error }: { error: unknown }) {
  if (!error) return null;
  return (
    <p className="error" role="alert">
      {errorMessage(error)}
    </p>
  );
}

/** Affiche chargement / erreur / contenu pour une requête TanStack Query. */
export function QueryState({
  isPending,
  error,
  children,
}: {
  isPending: boolean;
  error: unknown;
  children: ReactNode;
}) {
  if (isPending) {
    return (
      <p role="status" className="muted">
        Chargement…
      </p>
    );
  }
  if (error) return <ErrorMessage error={error} />;
  return <>{children}</>;
}
