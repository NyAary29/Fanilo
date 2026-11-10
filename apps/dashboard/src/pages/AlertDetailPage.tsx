import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import { useCurrentUser } from '../auth/AuthContext';
import { canAcknowledgeAlert, hasRole } from '../auth/permissions';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { DemoBanner } from '../components/DemoBanner';
import { useSites } from '../components/hooks';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { ALERT_EVENT_LABELS, ALERT_STATUS_LABELS, canResolveStatus, isAlertOverdue, SEVERITY_LABELS, severityTone } from '../domain/alerts';
import { formatDateTime, shortId } from '../domain/format';

function NoteForm({ label, submitLabel, onSubmit, pending, error }: {
  label: string;
  submitLabel: string;
  onSubmit: (note: string) => Promise<unknown>;
  pending: boolean;
  error: unknown;
}) {
  const [note, setNote] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);
  const id = `note-${submitLabel.replace(/\W+/g, '-').toLowerCase()}`;

  async function handle(event: FormEvent) {
    event.preventDefault();
    if (!note.trim()) {
      setLocalError('La note est obligatoire.');
      return;
    }
    setLocalError(null);
    try {
      await onSubmit(note.trim());
      setNote('');
    } catch {
      /* affiché via `error` */
    }
  }

  return (
    <form className="stack" onSubmit={handle} noValidate>
      <div className="field">
        <label htmlFor={id}>{label}</label>
        <textarea id={id} rows={2} value={note} required aria-invalid={!!localError} onChange={(e) => setNote(e.target.value)} />
      </div>
      {localError && (
        <p className="error" role="alert">
          {localError}
        </p>
      )}
      <ErrorMessage error={error} />
      <div>
        <button type="submit" className="btn btn-secondary" disabled={pending}>
          {submitLabel}
        </button>
      </div>
    </form>
  );
}

/** Rôles autorisés par l'API à créer une référence (lecture seule pour clinical_lead). */
const REFERRAL_CREATORS = ['community_agent', 'csb_head', 'clinical_advisor'] as const;

/** Orienter la patiente vers une autre structure, directement depuis l'alerte. */
function ReferForm({ alertId, beneficiaryId }: { alertId: string; beneficiaryId: string }) {
  const api = useApi();
  const queryClient = useQueryClient();
  const { sites } = useSites();
  const [toSite, setToSite] = useState('');
  const [reason, setReason] = useState('');
  const create = useMutation({
    mutationFn: () => api.createReferral({ beneficiary_id: beneficiaryId, alert_id: alertId, to_site_id: toSite, reason: reason.trim() || null }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['referrals'] }),
  });
  const choices = [...sites.filter((s) => s.is_active && s.kind !== 'community_zone')].sort((x, y) =>
    x.kind === y.kind ? x.name.localeCompare(y.name) : x.kind === 'reference_facility' ? -1 : 1,
  );
  if (create.data) {
    return (
      <div className="panel stack-sm" role="status">
        <h2>Référence créée</h2>
        <p>
          La patiente est orientée. Suivez son arrivée dans{' '}
          <Link to={`/references/${create.data.id}`}>la fiche de la référence</Link>.
        </p>
      </div>
    );
  }
  return (
    <form
      className="panel stack-sm"
      onSubmit={(e) => {
        e.preventDefault();
        if (toSite) create.mutate();
      }}
    >
      <h2>Orienter la patiente (référence)</h2>
      <p className="muted small">
        Si la patiente doit aller dans une autre structure (hôpital de référence, autre CSB), créez une référence : vous
        suivrez ensuite son arrivée.
      </p>
      <div className="field">
        <label htmlFor="refer-site">Vers</label>
        <select id="refer-site" required value={toSite} onChange={(e) => setToSite(e.target.value)}>
          <option value="">Choisir une structure…</option>
          {choices.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
              {s.kind === 'reference_facility' ? ' (structure de référence)' : ''}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label htmlFor="refer-reason">Motif (facultatif)</label>
        <input id="refer-reason" value={reason} maxLength={1000} onChange={(e) => setReason(e.target.value)} />
      </div>
      <ErrorMessage error={create.error} />
      <div>
        <button type="submit" className="btn btn-primary" disabled={!toSite || create.isPending}>
          Créer la référence
        </button>
      </div>
    </form>
  );
}

export function AlertDetailPage() {
  const { id = '' } = useParams();
  const api = useApi();
  const user = useCurrentUser();
  const queryClient = useQueryClient();

  const alert = useQuery({ queryKey: ['alert', id], queryFn: () => api.getAlert(id) });

  const refresh = () => {
    void queryClient.invalidateQueries({ queryKey: ['alert', id] });
    void queryClient.invalidateQueries({ queryKey: ['alerts'] });
    void queryClient.invalidateQueries({ queryKey: ['dashboard-summary'] });
  };
  const acknowledge = useMutation({ mutationFn: () => api.acknowledgeAlert(id), onSettled: refresh });
  const resolve = useMutation({ mutationFn: (note: string) => api.resolveAlert(id, note), onSettled: refresh });
  const addNote = useMutation({ mutationFn: (note: string) => api.addAlertNote(id, note), onSettled: refresh });

  const a = alert.data;
  const you = (userId: string | null) => (userId === null ? 'Système' : userId === user.id ? 'Vous' : `Utilisateur …${shortId(userId)}`);

  return (
    <section aria-labelledby="alert-title" className="stack">
      <p>
        <Link to="/alertes">← Retour aux alertes</Link>
      </p>
      <QueryState isPending={alert.isPending} error={alert.error}>
        {a && (
          <>
            <DemoBanner isDemo={a.is_demo} />
            <div className="page-head">
              <h1 id="alert-title">
                Alerte <span className="mono">{a.rule_id}</span>
              </h1>
              <div>
                <Badge tone={severityTone(a.severity)}>{SEVERITY_LABELS[a.severity]}</Badge>{' '}
                <Badge>{ALERT_STATUS_LABELS[a.status]}</Badge>{' '}
                {isAlertOverdue(a) && <Badge tone="danger">En retard</Badge>}
              </div>
            </div>

            <dl className="details panel">
              <dt>Bénéficiaire</dt>
              <dd>
                <BeneficiaryRef beneficiaryId={a.beneficiary_id} allowIdentity />
              </dd>
              <dt>Échéance de prise en compte</dt>
              <dd>{formatDateTime(a.due_at)}</dd>
              <dt>Destinataire</dt>
              <dd>{you(a.recipient_user_id)}</dd>
              <dt>Suppléant</dt>
              <dd>{a.backup_user_id ? you(a.backup_user_id) : '—'}</dd>
              <dt>Accusé de réception</dt>
              <dd>{a.acknowledged_at ? `${formatDateTime(a.acknowledged_at)} par ${you(a.acknowledged_by_user_id)}` : 'Non enregistré'}</dd>
              <dt>Résolue le</dt>
              <dd>{formatDateTime(a.resolved_at)}</dd>
              <dt>Jeu de règles</dt>
              <dd className="mono">{a.ruleset_version}</dd>
              <dt>Créée le</dt>
              <dd>{formatDateTime(a.created_at)}</dd>
            </dl>

            <div className="panel stack">
              <h2>Actions</h2>
              {canAcknowledgeAlert(user, a) && (
                <div>
                  <button type="button" className="btn btn-primary" disabled={acknowledge.isPending} onClick={() => acknowledge.mutate()}>
                    Acquitter (accusé de réception)
                  </button>
                  <ErrorMessage error={acknowledge.error} />
                </div>
              )}
              {canResolveStatus(a.status) && (
                <NoteForm
                  label="Note de résolution (obligatoire)"
                  submitLabel="Résoudre l'alerte"
                  onSubmit={(note) => resolve.mutateAsync(note)}
                  pending={resolve.isPending}
                  error={resolve.error}
                />
              )}
              <NoteForm
                label="Ajouter une note au journal"
                submitLabel="Ajouter la note"
                onSubmit={(note) => addNote.mutateAsync(note)}
                pending={addNote.isPending}
                error={addNote.error}
              />
            </div>

            {a.beneficiary_id && hasRole(user, REFERRAL_CREATORS) && (
              <ReferForm alertId={a.id} beneficiaryId={a.beneficiary_id} />
            )}

            <div className="panel">
              <h2>Journal des événements</h2>
              <ol className="timeline">
                {[...a.events]
                  .sort((x, y) => x.at.localeCompare(y.at))
                  .map((event) => (
                    <li key={event.id}>
                      <span className="timeline-date">{formatDateTime(event.at)}</span>{' '}
                      <strong>{ALERT_EVENT_LABELS[event.type]}</strong> — {you(event.actor_user_id)}
                      {event.note && <p className="timeline-note">{event.note}</p>}
                    </li>
                  ))}
              </ol>
            </div>
          </>
        )}
      </QueryState>
    </section>
  );
}
