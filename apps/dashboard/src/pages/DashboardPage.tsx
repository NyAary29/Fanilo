import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useApi } from '../api/ApiProvider';
import { useCurrentUser } from '../auth/AuthContext';
import { hasGlobalView } from '../auth/permissions';
import { useSites } from '../components/hooks';
import { QueryState } from '../components/QueryState';
import { formatDateTime, formatPercent } from '../domain/format';

interface Card {
  label: string;
  value: string;
  hint?: string;
  alert?: boolean;
}

export function DashboardPage() {
  const api = useApi();
  const user = useCurrentUser();
  const global = hasGlobalView(user);
  const { sites } = useSites();
  const [siteId, setSiteId] = useState('');

  const summary = useQuery({
    queryKey: ['dashboard-summary', siteId],
    queryFn: () => api.getDashboardSummary(siteId || null),
    refetchInterval: 60_000,
  });

  const s = summary.data;
  const cards: Card[] = s
    ? [
        { label: 'Alertes ouvertes', value: String(s.open_alerts) },
        { label: 'Alertes en retard', value: String(s.overdue_alerts), alert: s.overdue_alerts > 0, hint: 'Échéance dépassée sans accusé de réception' },
        { label: 'Références en attente', value: String(s.pending_referrals) },
        { label: 'CPN prévues (7 jours)', value: String(s.upcoming_anc_7d) },
        { label: 'CPN manquées (30 jours)', value: String(s.missed_anc_30d), alert: s.missed_anc_30d > 0 },
        { label: 'Agents actifs (30 jours)', value: `${s.active_agents_30d} / ${s.total_agents}` },
        { label: 'Grossesses suivies', value: String(s.active_pregnancies) },
        { label: 'Questions (30 jours)', value: String(s.interactions_30d) },
        { label: 'Taux de transfert au conseiller (30 jours)', value: formatPercent(s.fallback_rate_30d) },
      ]
    : [];

  return (
    <section aria-labelledby="dash-title" className="stack">
      <div className="page-head">
        <h1 id="dash-title">Tableau de bord</h1>
        {global && (
          <div className="field inline">
            <label htmlFor="dash-site">Site</label>
            <select id="dash-site" value={siteId} onChange={(e) => setSiteId(e.target.value)}>
              <option value="">Tous les sites</option>
              {sites.map((site) => (
                <option key={site.id} value={site.id}>
                  {site.name}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>
      <p className="muted small">Indicateurs agrégés, sans aucune donnée nominative.</p>
      <QueryState isPending={summary.isPending} error={summary.error}>
        <ul className="cards">
          {cards.map((card) => (
            <li key={card.label} className={`card${card.alert ? ' card-alert' : ''}`}>
              <span className="card-value">{card.value}</span>
              <span className="card-label">{card.label}</span>
              {card.hint && <span className="card-hint">{card.hint}</span>}
            </li>
          ))}
        </ul>
        {s && <p className="muted small">Mis à jour : {formatDateTime(s.generated_at)}</p>}
      </QueryState>
    </section>
  );
}
