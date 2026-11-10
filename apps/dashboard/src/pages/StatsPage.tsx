import { useMutation, useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useApi } from '../api/ApiProvider';
import { useCurrentUser } from '../auth/AuthContext';
import { hasGlobalView, hasRole } from '../auth/permissions';
import { useSites } from '../components/hooks';
import { errorMessage, QueryState } from '../components/QueryState';
import { formatDateTime } from '../domain/format';

const OUTCOME_LABELS: Record<string, string> = {
  answer: 'Réponse',
  danger_sign: 'Signe de danger',
  fallback: 'Transfert conseiller',
};

const PERIODS = [7, 30, 90, 365] as const;

function previousMonth(): string {
  const d = new Date();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() - 1);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

export function StatsPage() {
  const api = useApi();
  const user = useCurrentUser();
  const global = hasGlobalView(user);
  const { sites } = useSites();
  const [siteId, setSiteId] = useState('');
  const [days, setDays] = useState<number>(30);

  const stats = useQuery({
    queryKey: ['topic-stats', siteId, days],
    queryFn: () => api.getTopicStats(days, siteId || null),
  });
  const s = stats.data;

  return (
    <section aria-labelledby="stats-title" className="stack">
      <div className="page-head">
        <h1 id="stats-title">Statistiques thématiques</h1>
        <div className="row">
          {global && (
            <div className="field inline">
              <label htmlFor="stats-site">Site</label>
              <select id="stats-site" value={siteId} onChange={(e) => setSiteId(e.target.value)}>
                <option value="">Tous les sites</option>
                {sites.map((site) => (
                  <option key={site.id} value={site.id}>
                    {site.name}
                  </option>
                ))}
              </select>
            </div>
          )}
          <div className="field inline">
            <label htmlFor="stats-days">Période</label>
            <select id="stats-days" value={days} onChange={(e) => setDays(Number(e.target.value))}>
              {PERIODS.map((p) => (
                <option key={p} value={p}>
                  {p} jours
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>
      <p className="muted small">
        Questions agrégées par module, intention proposée, issue et contenu servi. Aucune donnée nominative ; les
        cellules de moins de {s?.min_cell_size ?? '…'} questions sont masquées (secret statistique).
      </p>
      <QueryState isPending={stats.isPending} error={stats.error}>
        {s && (
          <>
            <ul className="cards">
              <li className="card">
                <span className="card-value">{s.total}</span>
                <span className="card-label">Questions ({s.period_days} jours)</span>
              </li>
              <li className="card">
                <span className="card-value">{s.suppressed_total}</span>
                <span className="card-label">Dans des cellules masquées</span>
                <span className="card-hint">{s.suppressed_cells} cellule(s)</span>
              </li>
            </ul>
            {s.items.length === 0 ? (
              <p className="muted">Aucune cellule publiable sur cette période.</p>
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th scope="col">Module</th>
                    <th scope="col">Intention proposée</th>
                    <th scope="col">Issue</th>
                    <th scope="col">Contenu servi</th>
                    <th scope="col">Nombre</th>
                  </tr>
                </thead>
                <tbody>
                  {s.items.map((c) => (
                    <tr key={`${c.module}-${c.intent}-${c.outcome}-${c.content_code}`}>
                      <td>{c.module.toUpperCase()}</td>
                      <td className="mono">{c.intent ?? '—'}</td>
                      <td>{OUTCOME_LABELS[c.outcome] ?? c.outcome}</td>
                      <td className="mono">{c.content_code ?? '—'}</td>
                      <td>{c.count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            <p className="muted small">Mis à jour : {formatDateTime(s.generated_at)}</p>
          </>
        )}
      </QueryState>
      {hasRole(user, ['data_officer']) && <Dhis2Export />}
    </section>
  );
}

/** Export agrégé mensuel (format DHIS2 dataValueSet). Préparatoire : rien n'est envoyé à un tiers. */
function Dhis2Export() {
  const api = useApi();
  const [month, setMonth] = useState(previousMonth());
  const [smallCells, setSmallCells] = useState(false);
  const exportMutation = useMutation({
    mutationFn: () => api.exportDhis2(month.replace('-', ''), smallCells),
    onSuccess: (data) => {
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `fanilo-dhis2-${data.period}.json`;
      a.click();
      URL.revokeObjectURL(url);
    },
  });

  return (
    <div className="panel stack-sm">
      <h2 className="h3">Export agrégé (format DHIS2)</h2>
      <p className="muted small">
        Fichier JSON <span className="mono">dataValueSet</span> par CSB, sans aucune donnée nominative. L&apos;export est
        tracé dans le journal d&apos;audit. Aucune transmission automatique : l&apos;intégration à DHIS2 reste soumise à
        autorisation (voir docs/interoperabilite.md).
      </p>
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          exportMutation.mutate();
        }}
      >
        <div className="field inline">
          <label htmlFor="dhis2-month">Mois</label>
          <input id="dhis2-month" type="month" required value={month} onChange={(e) => setMonth(e.target.value)} />
        </div>
        <label className="radio">
          <input type="checkbox" checked={smallCells} onChange={(e) => setSmallCells(e.target.checked)} />
          Inclure les petites cellules
        </label>
        <button type="submit" className="btn btn-primary" disabled={exportMutation.isPending || !month}>
          Télécharger l&apos;export
        </button>
      </form>
      {exportMutation.error && (
        <p className="error" role="alert">
          {errorMessage(exportMutation.error)}
        </p>
      )}
      {exportMutation.data && (
        <p className="small" aria-live="polite">
          {exportMutation.data.dataValues.length} valeur(s) exportée(s), {exportMutation.data.suppressed_values} masquée(s).
        </p>
      )}
    </div>
  );
}
