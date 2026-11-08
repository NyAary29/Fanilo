import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useApi } from '../api/ApiProvider';
import type { Site } from '../api/types';

/** Sites (lecture ouverte à tout utilisateur authentifié), mis en cache 5 minutes. */
export function useSites() {
  const api = useApi();
  const query = useQuery({ queryKey: ['sites'], queryFn: () => api.listSites({ limit: 500 }), staleTime: 5 * 60_000 });
  const byId = useMemo(() => new Map<string, Site>((query.data?.items ?? []).map((s) => [s.id, s])), [query.data]);
  return { ...query, sites: query.data?.items ?? [], byId };
}

export function useSiteName() {
  const { byId } = useSites();
  return (id: string | null | undefined) => (id ? (byId.get(id)?.name ?? `Site …${id.slice(-6)}`) : '—');
}
