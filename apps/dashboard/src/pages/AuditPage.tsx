import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { useApi } from '../api/ApiProvider';
import type { AuditFilters } from '../api/types';
import { ROLE_LABELS } from '../auth/permissions';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { QueryState } from '../components/QueryState';
import { formatDateTime } from '../domain/format';

/**
 * Journal d'audit (data_officer). Les événements ne contiennent ni contenu médical ni
 * donnée nominative (contrat §10) : seuls des identifiants techniques sont affichés.
 */
function toIsoBoundary(date: string, end: boolean): string | undefined {
  if (!date) return undefined;
  // HYPOTHÈSE : le contrat ne précise pas le format de `from`/`to` ; on envoie un datetime UTC.
  return `${date}T${end ? '23:59:59.999' : '00:00:00.000'}Z`;
}

export function AuditPage() {
  const api = useApi();
  const [draft, setDraft] = useState({ entity_type: '', actor_user_id: '', from: '', to: '' });
  const [filters, setFilters] = useState<AuditFilters>({});
  const [offset, setOffset] = useState(0);

  const audit = useQuery({
    queryKey: ['audit', filters, offset],
    queryFn: () => api.listAudit({ ...filters, limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  });

  function apply(event: FormEvent) {
    event.preventDefault();
    setOffset(0);
    setFilters({
      entity_type: draft.entity_type.trim() || undefined,
      actor_user_id: draft.actor_user_id.trim() || undefined,
      from: toIsoBoundary(draft.from, false),
      to: toIsoBoundary(draft.to, true),
    });
  }

  return (
    <section aria-labelledby="audit-title" className="stack">
      <h1 id="audit-title">Journal d&apos;audit</h1>
      <form className="panel filters" onSubmit={apply} aria-label="Filtres du journal">
        <div className="field">
          <label htmlFor="af-entity">Type d&apos;entité</label>
          <input id="af-entity" placeholder="ex. alert, referral, user" value={draft.entity_type} onChange={(e) => setDraft({ ...draft, entity_type: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor="af-actor">Identifiant de l&apos;acteur</label>
          <input id="af-actor" className="mono" value={draft.actor_user_id} onChange={(e) => setDraft({ ...draft, actor_user_id: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor="af-from">Du</label>
          <input id="af-from" type="date" value={draft.from} onChange={(e) => setDraft({ ...draft, from: e.target.value })} />
        </div>
        <div className="field">
          <label htmlFor="af-to">Au</label>
          <input id="af-to" type="date" value={draft.to} onChange={(e) => setDraft({ ...draft, to: e.target.value })} />
        </div>
        <div className="field">
          <button type="submit" className="btn btn-primary">
            Filtrer
          </button>
        </div>
      </form>
      <QueryState isPending={audit.isPending} error={audit.error}>
        {audit.data && audit.data.items.length === 0 ? (
          <p className="muted">Aucun événement pour ces filtres.</p>
        ) : (
          <table className="table">
            <caption className="sr-only">Événements d&apos;audit</caption>
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Action</th>
                <th scope="col">Acteur</th>
                <th scope="col">Entité</th>
                <th scope="col">Requête</th>
              </tr>
            </thead>
            <tbody>
              {audit.data?.items.map((e) => (
                <tr key={e.id}>
                  <td data-label="Date">{formatDateTime(e.at)}</td>
                  <td data-label="Action" className="mono">
                    {e.action}
                  </td>
                  <td data-label="Acteur">
                    <span className="mono small">{e.actor_user_id}</span>
                    <br />
                    {ROLE_LABELS[e.actor_role] ?? e.actor_role}
                  </td>
                  <td data-label="Entité">
                    {e.entity_type} <span className="mono small">{e.entity_id}</span>
                  </td>
                  <td data-label="Requête" className="mono small">
                    {e.request_id}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <Pagination offset={offset} total={audit.data?.total ?? 0} onChange={setOffset} />
      </QueryState>
    </section>
  );
}
