import { useQuery } from '@tanstack/react-query';
import { ArrowRight, CalendarClock, CheckCircle2, HeartPulse, MapPin, Search, Smartphone, TriangleAlert } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import type { Patient } from '../api/types';
import { Badge } from '../components/Badge';
import { initials } from '../components/Layout';
import { QueryState } from '../components/QueryState';
import { formatDate } from '../domain/format';

const REASONS: Record<string, string> = {
  alerte_ouverte: 'Une alerte est ouverte : vérifier qu’elle a été prise en compte par le CSB.',
  cpn_manquee: 'Une consultation prénatale a été manquée : reprendre rendez-vous.',
  dates_inconnues: 'Date des dernières règles inconnue : la renseigner pour obtenir le calendrier.',
};

type Filter = 'all' | 'a_suivre' | 'a_jour';

function inDays(days: number): string {
  if (days === 0) return "aujourd'hui";
  if (days === 1) return 'demain';
  return `dans ${days} jours`;
}

function subtitle(p: Patient): string {
  if (!p.pregnancy) return 'Pas de grossesse en cours';
  return p.pregnancy.month ? `Grossesse · ${p.pregnancy.month} mois` : 'Grossesse · date inconnue';
}

/**
 * Espace agent (web/tablette) : liste de travail des patientes du périmètre.
 * Les noms sont des données nominatives : la liste n'est servie qu'aux rôles de soin
 * et chaque identité renvoyée est tracée dans le journal d'audit par l'API.
 */
export function PatientsPage() {
  const api = useApi();
  const [query, setQuery] = useState('');
  const [debounced, setDebounced] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [selectedId, setSelectedId] = useState<string | null>(null);

  useEffect(() => {
    const t = setTimeout(() => setDebounced(query.trim()), 300);
    return () => clearTimeout(t);
  }, [query]);

  const patients = useQuery({
    queryKey: ['patients', debounced],
    queryFn: () => api.listPatients(debounced || undefined),
    staleTime: 30_000,
  });
  const all = useMemo(() => patients.data?.items ?? [], [patients.data]);
  const items = useMemo(() => (filter === 'all' ? all : all.filter((p) => p.status === filter)), [all, filter]);
  const selected = items.find((p) => p.beneficiary_id === selectedId) ?? items[0] ?? null;
  const toFollow = all.filter((p) => p.status === 'a_suivre').length;

  return (
    <section aria-labelledby="patients-title" className="stack">
      <div className="page-head">
        <div>
          <h1 id="patients-title">Mes patientes</h1>
          <p className="subtitle">
            {all.length} patiente{all.length > 1 ? 's' : ''} dans votre zone · <strong>{toFollow} à suivre</strong> en priorité
          </p>
        </div>
      </div>

      <QueryState isPending={patients.isPending} error={patients.error}>
        <div className="patients">
          <div className="panel stack-sm">
            <div className="search">
              <Search size={18} aria-hidden="true" />
              <label htmlFor="patient-search" className="sr-only">
                Rechercher une patiente
              </label>
              <input
                id="patient-search"
                type="search"
                placeholder="Rechercher (nom, code, village)…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
            </div>
            <div className="segmented" role="radiogroup" aria-label="Filtrer">
              {(
                [
                  ['all', 'Toutes'],
                  ['a_suivre', `À suivre (${toFollow})`],
                  ['a_jour', 'À jour'],
                ] as const
              ).map(([value, label]) => (
                <button key={value} type="button" role="radio" aria-checked={filter === value} onClick={() => setFilter(value)}>
                  {label}
                </button>
              ))}
            </div>
            {items.length === 0 ? (
              <div className="empty">
                <HeartPulse size={40} aria-hidden="true" />
                <p>Aucune patiente.</p>
              </div>
            ) : (
              <ul className="patient-list">
                {items.map((p) => (
                  <li key={p.beneficiary_id}>
                    <button
                      type="button"
                      className="patient-item"
                      aria-current={selected?.beneficiary_id === p.beneficiary_id}
                      onClick={() => setSelectedId(p.beneficiary_id)}
                    >
                      <span className="avatar" aria-hidden="true">
                        {initials(p.display_name ?? p.code)}
                      </span>
                      <span className="who">
                        <strong>{p.display_name ?? p.code}</strong>
                        <span>{subtitle(p)}</span>
                      </span>
                      {p.status === 'a_suivre' ? <Badge tone="warning">À suivre</Badge> : <Badge tone="success">À jour</Badge>}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {selected ? <PatientDetail patient={selected} /> : <div />}

          <div className="stack">
            {selected && selected.open_alerts > 0 && selected.latest_alert_id && (
              <div className="alert-card stack-sm" role="status">
                <h2 className="h3">
                  <TriangleAlert size={22} aria-hidden="true" /> Alerte importante
                </h2>
                <p>
                  <strong>Signe de danger signalé.</strong> L&apos;alerte a été transmise au CSB. Vérifiez qu&apos;elle a bien
                  été reçue ; aucune prise en charge n&apos;est garantie tant qu&apos;un professionnel ne l&apos;a pas confirmée.
                </p>
                <Link to={`/alertes/${selected.latest_alert_id}`} className="btn btn-danger btn-block">
                  Voir l&apos;alerte <ArrowRight size={18} aria-hidden="true" />
                </Link>
              </div>
            )}
            <div className="panel stack-sm">
              <h2 className="h3">Enregistrer ou visiter</h2>
              <div className="info-tile">
                <Smartphone size={28} aria-hidden="true" />
                <p className="small">
                  L&apos;enregistrement d&apos;une nouvelle patiente, la visite du jour et le signalement des signes se font avec
                  l&apos;<strong>application mobile</strong>, qui fonctionne même sans réseau.
                </p>
              </div>
            </div>
          </div>
        </div>
      </QueryState>
    </section>
  );
}

function PatientDetail({ patient: p }: { patient: Patient }) {
  const [tab, setTab] = useState<'suivi' | 'infos'>('suivi');
  const progress = p.anc_total ? Math.round((p.anc_done / p.anc_total) * 100) : 0;
  return (
    <div className="panel stack">
      <div className="patient-head">
        <span className="avatar lg" aria-hidden="true">
          {initials(p.display_name ?? p.code)}
        </span>
        <div>
          <h2 style={{ margin: 0 }}>{p.display_name ?? 'Identité non renseignée'}</h2>
          <p className="muted small">
            {p.age !== null && `${p.age} ans · `}
            <MapPin size={14} aria-hidden="true" style={{ verticalAlign: 'middle' }} /> {p.village ?? p.site_name}
          </p>
          <p className="xs muted">
            Code <span className="mono">{p.code}</span>
          </p>
        </div>
      </div>
      <div className="tabs" role="tablist">
        <button type="button" role="tab" className="tab" aria-selected={tab === 'suivi'} onClick={() => setTab('suivi')}>
          Suivi
        </button>
        <button type="button" role="tab" className="tab" aria-selected={tab === 'infos'} onClick={() => setTab('infos')}>
          Informations
        </button>
      </div>
      {tab === 'suivi' ? (
        <div className="stack">
          {p.reasons.length > 0 ? (
            <ul className="stack-sm" style={{ paddingLeft: '1.1rem', margin: 0 }}>
              {p.reasons.map((r) => (
                <li key={r} className="warning-text" style={{ fontWeight: 700 }}>
                  {REASONS[r] ?? r}
                </li>
              ))}
            </ul>
          ) : (
            <p className="row" style={{ color: 'var(--color-success)', fontWeight: 700 }}>
              <CheckCircle2 size={20} aria-hidden="true" /> Suivi à jour, rien à signaler.
            </p>
          )}
          <div>
            <h3 className="h3" style={{ marginBottom: 'var(--space-2)' }}>
              Prochain rappel
            </h3>
            <div className="info-tile">
              <CalendarClock size={30} aria-hidden="true" />
              {p.next_anc ? (
                <p>
                  <strong>
                    CPN {p.next_anc.sequence} : {inDays(p.next_anc.days)}
                  </strong>
                  <br />
                  <span className="muted small">{formatDate(p.next_anc.scheduled_date)}</span>
                </p>
              ) : (
                <p className="muted">{p.pregnancy ? 'Aucune consultation planifiée.' : 'Pas de grossesse en cours.'}</p>
              )}
            </div>
          </div>
          {p.pregnancy && p.anc_total > 0 && (
            <div className="stack-sm">
              <div className="row">
                <strong>Consultations prénatales</strong>
                <span className="spacer" />
                <span className="small">
                  {p.anc_done} / {p.anc_total} réalisées
                </span>
              </div>
              <div className="progress" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={progress} aria-label="CPN réalisées">
                <span style={{ width: `${progress}%` }} />
              </div>
              {p.missed_anc > 0 && <p className="small warning-text">{p.missed_anc} CPN manquée(s)</p>}
            </div>
          )}
        </div>
      ) : (
        <dl className="details">
          <dt>Code</dt>
          <dd className="mono">{p.code}</dd>
          <dt>Site</dt>
          <dd>{p.site_name}</dd>
          <dt>Âge</dt>
          <dd>{p.age !== null ? `${p.age} ans` : '—'}</dd>
          <dt>Dernières règles</dt>
          <dd>{p.pregnancy?.lmp_date ? formatDate(p.pregnancy.lmp_date) : '—'}</dd>
          <dt>Terme prévu</dt>
          <dd>{p.pregnancy?.estimated_due_date ? formatDate(p.pregnancy.estimated_due_date) : '—'}</dd>
        </dl>
      )}
    </div>
  );
}
