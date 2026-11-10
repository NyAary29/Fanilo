import { useQuery } from '@tanstack/react-query';
import {
  ArrowRight,
  BarChart3,
  CalendarCheck,
  CalendarX,
  FileText,
  HeartPulse,
  MessageCircleQuestion,
  Mic,
  Route,
  ShieldCheck,
  TriangleAlert,
  UserCog,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import { useCurrentUser } from '../auth/AuthContext';
import { canAccess, hasGlobalView, SECTION_PATHS, type Section } from '../auth/permissions';
import { ActivityChart } from '../components/ActivityChart';
import { useSites } from '../components/hooks';
import { QueryState } from '../components/QueryState';
import { isAlertOverdue, SEVERITY_LABELS } from '../domain/alerts';
import { formatDateTime, formatPercent } from '../domain/format';

interface Card {
  label: string;
  value: string;
  hint?: string;
  icon: LucideIcon;
  tone: string;
}

const QUICK_ACTIONS: { section: Section; title: string; text: string; icon: LucideIcon }[] = [
  { section: 'alerts', title: 'Traiter les alertes', text: 'Accuser réception, résoudre', icon: TriangleAlert },
  { section: 'patients', title: 'Mes patientes', text: 'Qui suivre aujourd’hui', icon: HeartPulse },
  { section: 'referrals', title: 'Suivre les références', text: 'Acceptée, arrivée au CSB…', icon: Route },
  { section: 'interactions', title: 'Questions des femmes', text: 'Répondre aux transferts', icon: MessageCircleQuestion },
  { section: 'contents', title: 'Gérer les contenus', text: 'Rédiger, valider, retirer', icon: FileText },
  { section: 'users', title: 'Gérer les comptes', text: 'Créer, rôles, sites', icon: UserCog },
  { section: 'stats', title: 'Statistiques', text: 'Thèmes des questions', icon: BarChart3 },
  { section: 'simulator', title: 'Assistant vocal', text: 'Tester le parcours au téléphone', icon: Mic },
  { section: 'audit', title: "Journal d'audit", text: 'Accès et actions sensibles', icon: ShieldCheck },
];

const GREETING = () => {
  const h = new Date().getHours();
  return h < 12 ? 'Bonjour' : h < 18 ? 'Bon après-midi' : 'Bonsoir';
};

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
  const activity = useQuery({
    queryKey: ['dashboard-activity', siteId],
    queryFn: () => api.getActivity(6, siteId || null),
  });
  const alertsAllowed = canAccess(user, 'alerts');
  const recentAlerts = useQuery({
    queryKey: ['alerts', 'recent'],
    queryFn: () => api.listAlerts({ limit: 5, sort: 'recent' }),
    enabled: alertsAllowed,
  });

  const s = summary.data;
  const cards: Card[] = s
    ? [
        { label: 'Grossesses suivies', value: String(s.active_pregnancies), icon: Users, tone: 'tone-green' },
        {
          label: 'Alertes ouvertes',
          value: String(s.open_alerts),
          icon: TriangleAlert,
          tone: 'tone-red',
          hint: s.overdue_alerts > 0 ? `dont ${s.overdue_alerts} en retard (sans accusé de réception)` : 'aucune en retard',
        },
        { label: 'CPN prévues (7 jours)', value: String(s.upcoming_anc_7d), icon: CalendarCheck, tone: 'tone-teal' },
        { label: 'CPN manquées (30 jours)', value: String(s.missed_anc_30d), icon: CalendarX, tone: s.missed_anc_30d ? 'tone-orange' : 'tone-teal' },
        { label: 'Références en attente', value: String(s.pending_referrals), icon: Route, tone: 'tone-blue' },
        { label: 'Agents actifs (30 jours)', value: `${s.active_agents_30d} / ${s.total_agents}`, icon: HeartPulse, tone: 'tone-green' },
        { label: 'Questions (30 jours)', value: String(s.interactions_30d), icon: MessageCircleQuestion, tone: 'tone-violet' },
        {
          label: 'Transférées à un conseiller',
          value: formatPercent(s.fallback_rate_30d),
          icon: Mic,
          tone: 'tone-violet',
          hint: 'part des questions (30 jours)',
        },
      ]
    : [];

  const actions = QUICK_ACTIONS.filter((a) => a.section !== 'dashboard' && canAccess(user, a.section)).slice(0, 4);
  const siteRows = activity.data?.sites ?? [];
  const maxSite = Math.max(1, ...siteRows.map((r) => r.active_pregnancies + r.open_alerts));

  return (
    <section aria-labelledby="dash-title" className="stack">
      <div className="page-head">
        <div>
          <h1 id="dash-title">Tableau de bord</h1>
          <p className="subtitle">
            {GREETING()}, <strong>{user.login}</strong>. Voici la situation, en chiffres agrégés (aucune donnée nominative).{' '}
            <Link to="/aide">Que dois-je faire ?</Link>
          </p>
        </div>
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

      {actions.length > 0 && (
        <nav className="quick-actions" aria-label="Actions rapides">
          {actions.map((a) => (
            <Link key={a.section} to={SECTION_PATHS[a.section]} className="quick-action">
              <span className="qa-icon">
                <a.icon size={22} aria-hidden="true" />
              </span>
              <span>
                <strong>{a.title}</strong>
                <span>{a.text}</span>
              </span>
            </Link>
          ))}
        </nav>
      )}

      <QueryState isPending={summary.isPending} error={summary.error}>
        <ul className="cards">
          {cards.map((card) => (
            <li key={card.label} className={`card ${card.tone}`}>
              <span className="card-icon">
                <card.icon size={24} aria-hidden="true" />
              </span>
              <span className="card-value">{card.value}</span>
              <span className="card-label">{card.label}</span>
              {card.hint && <span className="card-hint">{card.hint}</span>}
            </li>
          ))}
        </ul>
      </QueryState>

      <div className="dash-grid">
        <div className="panel">
          <div className="panel-head">
            <h2>Activité sur 6 mois</h2>
          </div>
          <QueryState isPending={activity.isPending} error={activity.error}>
            {activity.data && <ActivityChart months={activity.data.months} />}
          </QueryState>
        </div>

        {alertsAllowed ? (
          <div className="panel">
            <div className="panel-head">
              <h2>Alertes récentes</h2>
              <Link to="/alertes" className="small">
                Voir tout <ArrowRight size={14} aria-hidden="true" style={{ verticalAlign: 'middle' }} />
              </Link>
            </div>
            <QueryState isPending={recentAlerts.isPending} error={recentAlerts.error}>
              {recentAlerts.data?.items.length === 0 ? (
                <p className="muted">Aucune alerte.</p>
              ) : (
                <ul className="feed">
                  {recentAlerts.data?.items.map((a) => {
                    const overdue = isAlertOverdue(a);
                    const open = a.status === 'open' || a.status === 'escalated';
                    return (
                      <li key={a.id}>
                        <span
                          className="feed-icon"
                          style={{
                            background: open ? 'var(--color-danger-bg)' : 'var(--color-success-bg)',
                            color: open ? 'var(--color-danger)' : 'var(--color-success)',
                          }}
                        >
                          <TriangleAlert size={16} aria-hidden="true" />
                        </span>
                        <span className="feed-body">
                          <Link className="feed-title" to={`/alertes/${a.id}`}>
                            Signe de danger · {SEVERITY_LABELS[a.severity]}
                          </Link>
                          <span className="feed-meta">
                            {formatDateTime(a.created_at)}
                            {overdue && <strong className="warning-text"> · en retard</strong>}
                            {a.status === 'acknowledged' && ' · reçue'}
                            {a.status === 'resolved' && ' · résolue'}
                          </span>
                        </span>
                      </li>
                    );
                  })}
                </ul>
              )}
            </QueryState>
          </div>
        ) : (
          <SitesPanel rows={siteRows} max={maxSite} />
        )}
      </div>
      {alertsAllowed && <SitesPanel rows={siteRows} max={maxSite} />}
      {s && <p className="muted xs">Mis à jour : {formatDateTime(s.generated_at)}</p>}
    </section>
  );
}

function SitesPanel({ rows, max }: { rows: { site_id: string; name: string; region: string; active_pregnancies: number; open_alerts: number }[]; max: number }) {
  return (
    <div className="panel">
      <div className="panel-head">
        <h2>Par centre de santé</h2>
        <span className="chart-legend xs" aria-hidden="true">
          <span className="key">
            <svg width="12" height="12"><rect width="12" height="12" rx="3" fill="var(--series-1)" /></svg> grossesses
          </span>
          <span className="key">
            <svg width="12" height="12"><rect width="12" height="12" rx="3" fill="var(--series-2)" /></svg> alertes ouvertes
          </span>
        </span>
      </div>
      {rows.length === 0 ? (
        <p className="muted">Aucun centre dans votre périmètre.</p>
      ) : (
        <ul className="bars">
          {rows.map((r) => (
            <li key={r.site_id}>
              <div className="bar-label">
                <span>
                  {r.name} <span className="muted xs">· {r.region}</span>
                </span>
                <span>
                  {r.active_pregnancies} grossesse{r.active_pregnancies > 1 ? 's' : ''} · {r.open_alerts} alerte{r.open_alerts > 1 ? 's' : ''}
                </span>
              </div>
              <div className="bar-track" aria-hidden="true">
                <span className="bar-fill" style={{ width: `${(r.active_pregnancies / max) * 100}%` }} />
                <span className="bar-fill alt" style={{ width: `${(r.open_alerts / max) * 100}%` }} />
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
