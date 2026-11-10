import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Building2, CheckCircle2, MessageCircleQuestion, TriangleAlert } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import type { Interaction, Triage } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { DemoBanner } from '../components/DemoBanner';
import { useSiteName, useSites } from '../components/hooks';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { formatDateTime, shortId } from '../domain/format';

/** Réponses types : le conseiller les adapte avant d'envoyer. */
export const TRIAGE_LABELS: Record<Triage, { label: string; tone: 'danger' | 'warning' | 'success'; hint: string }> = {
  urgent: { label: '🔴 Urgent', tone: 'danger', hint: 'Elle doit aller au centre tout de suite' },
  follow_up: { label: '🟠 À suivre', tone: 'warning', hint: 'Elle doit aller au centre, sans urgence' },
  info: { label: '🟢 Simple information', tone: 'success', hint: 'Votre réponse suffit' },
};

const FOLLOW_UP_LABELS = { expected: 'Attendue au centre', came: 'Venue au centre ✔', no_show: 'Pas venue' } as const;

const QUICK_REPLIES = [
  'Allez au centre de santé dès aujourd’hui. Si vous ne pouvez pas vous déplacer, demandez à l’agent communautaire de vous accompagner.',
  'Allez sans attendre à l’hôpital indiqué ci-dessous, accompagnée si possible.',
  'Ce que vous décrivez n’est pas inquiétant. Parlez-en à l’agent communautaire lors de sa prochaine visite.',
  'Vous pouvez en parler en toute confidentialité au personnel du centre de santé indiqué ci-dessous.',
];

function isUrgent(item: Interaction): boolean {
  return item.outcome === 'danger_sign' || item.severity !== null || item.intent === 'report_danger_sign' || (item.sign_codes?.length ?? 0) > 0;
}

function ReplyForm({ interaction, onDone }: { interaction: Interaction; onDone: () => void }) {
  const api = useApi();
  const { sites } = useSites();
  const [note, setNote] = useState('');
  const [siteId, setSiteId] = useState('');
  const [triage, setTriage] = useState<Triage | null>(isUrgent(interaction) ? 'urgent' : null);
  const [localError, setLocalError] = useState<string | null>(null);
  const review = useMutation({
    mutationFn: () =>
      api.reviewInteraction(interaction.id, { note: note.trim(), triage: triage ?? 'info', orientation_site_id: siteId || null }),
    onSuccess: onDone,
  });
  const centres = sites
    .filter((s) => s.is_active && s.kind !== 'community_zone')
    .sort((a, b) => (a.kind === b.kind ? a.name.localeCompare(b.name) : a.kind === 'reference_facility' ? -1 : 1));
  const id = `review-${interaction.id}`;

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!triage) {
      setLocalError('Classez la situation : urgent, à suivre ou simple information.');
      return;
    }
    if (!note.trim()) {
      setLocalError('Écrivez ce qu’elle doit faire.');
      return;
    }
    if (triage !== 'info' && !siteId) {
      setLocalError('Pour une situation urgente ou à suivre, choisissez le centre où l’envoyer.');
      return;
    }
    setLocalError(null);
    review.mutate();
  }

  return (
    <form className="stack-sm" onSubmit={handleSubmit} noValidate>
      <fieldset className="stack-sm">
        <legend>1. Classez la situation</legend>
        <div className="segmented" role="radiogroup" aria-label="Classement">
          {(Object.keys(TRIAGE_LABELS) as Triage[]).map((t) => (
            <button key={t} type="button" role="radio" aria-checked={triage === t} onClick={() => setTriage(t)} title={TRIAGE_LABELS[t].hint}>
              {TRIAGE_LABELS[t].label}
            </button>
          ))}
        </div>
        {triage && <p className="muted small">{TRIAGE_LABELS[triage].hint}.</p>}
      </fieldset>
      <div className="field">
        <label htmlFor={id}>
          2.{' '}
          {interaction.channel === 'public_app' ? 'Votre réponse : ce qu’elle doit faire' : 'Réponse ou orientation documentée'}
        </label>
        <div className="row">
          {QUICK_REPLIES.map((text) => (
            <button key={text} type="button" className="btn btn-secondary small" style={{ minHeight: 36, padding: '4px 12px' }} onClick={() => setNote(text)}>
              {text.split(/[.:]/)[0]}
            </button>
          ))}
        </div>
        <textarea id={id} rows={3} value={note} aria-invalid={!!localError} onChange={(e) => setNote(e.target.value)} />
      </div>
      <div className="field">
        <label htmlFor={`${id}-site`}>
          3. L’orienter vers un centre de santé {triage && triage !== 'info' ? '(obligatoire : le centre fera le suivi)' : '(facultatif)'}
        </label>
        <select id={`${id}-site`} value={siteId} onChange={(e) => setSiteId(e.target.value)}>
          <option value="">— Aucun centre précis —</option>
          {centres.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name} ({s.kind === 'reference_facility' ? 'hôpital de référence' : 'CSB'}, {s.district})
            </option>
          ))}
        </select>
      </div>
      {localError && (
        <p className="error" role="alert">
          {localError}
        </p>
      )}
      <ErrorMessage error={review.error} />
      <div>
        <button type="submit" className="btn btn-primary" disabled={review.isPending}>
          Envoyer la réponse
        </button>
      </div>
    </form>
  );
}

export function InteractionsPage() {
  const api = useApi();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const siteName = useSiteName();
  const [tab, setTab] = useState<'pending' | 'reviewed'>('pending');
  const [offset, setOffset] = useState(0);
  const interactions = useQuery({
    queryKey: ['interactions', tab, offset],
    queryFn: () => api.listInteractions({ review_status: tab, limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
    refetchInterval: 15_000,
  });
  const pendingCount = useQuery({
    queryKey: ['interactions', 'pending-count'],
    queryFn: () => api.listInteractions({ review_status: 'pending', limit: 1 }),
    refetchInterval: 15_000,
  });

  return (
    <section aria-labelledby="inter-title" className="stack">
      <div>
        <h1 id="inter-title">Questions des femmes</h1>
        <p className="subtitle">
          Une femme ou une adolescente a posé une question que FANILO ne peut pas traiter seul. Dites-lui quoi faire et, si
          besoin, vers quel centre de santé aller : elle lit votre réponse dans son application. Les urgences sont en haut.
        </p>
      </div>
      <div className="segmented" role="tablist" aria-label="Filtrer">
        <button
          type="button"
          role="tab"
          aria-selected={tab === 'pending'}
          onClick={() => {
            setTab('pending');
            setOffset(0);
          }}
        >
          À traiter ({pendingCount.data?.total ?? '…'})
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={tab === 'reviewed'}
          onClick={() => {
            setTab('reviewed');
            setOffset(0);
          }}
        >
          Déjà répondues
        </button>
      </div>
      <QueryState isPending={interactions.isPending} error={interactions.error}>
        {interactions.data?.items.length === 0 ? (
          <div className="empty panel">
            <MessageCircleQuestion size={44} aria-hidden="true" />
            <p>{tab === 'pending' ? 'Aucune question en attente. Tout est à jour.' : 'Aucune question répondue pour le moment.'}</p>
          </div>
        ) : (
          <ul className="list">
            {interactions.data?.items.map((item) => {
              const urgent = isUrgent(item);
              return (
                <li key={item.id} className="panel stack-sm" style={urgent ? { borderColor: 'var(--color-danger)', borderWidth: 2 } : undefined}>
                  {urgent && (
                    <p className="row" style={{ color: 'var(--color-danger)', fontWeight: 800 }}>
                      <TriangleAlert size={20} aria-hidden="true" /> Signe de danger possible : à traiter en premier
                    </p>
                  )}
                  <div className="row">
                    <Badge tone={item.module === 'tanora' ? 'success' : 'warning'}>{item.module === 'tanora' ? 'TANORA · adolescente' : 'RENY · grossesse'}</Badge>
                    <span className="muted small">
                      {item.channel === 'public_app' ? 'Question anonyme (application Femmes)' : 'Transmise par un agent'} ·{' '}
                      {formatDateTime(item.created_at)}
                      {item.beneficiary_id && (
                        <>
                          {' · '}
                          <BeneficiaryRef beneficiaryId={item.beneficiary_id} />
                        </>
                      )}
                      {item.alert_id && (
                        <>
                          {' · '}
                          <Link to={`/alertes/${item.alert_id}`}>Alerte liée</Link>
                        </>
                      )}
                    </span>
                  </div>
                  <div>
                    <p className="small muted" style={{ fontWeight: 700 }}>
                      Elle a demandé :
                    </p>
                    <blockquote className="transcript" style={{ fontSize: '1.1rem' }}>
                      {item.transcript ?? <span className="muted">(question orale non transcrite, ou signes cochés par l’agent)</span>}
                      {item.transcript_needs_review && <p className="small warning-text">Transcription automatique : vérifiez le sens.</p>}
                    </blockquote>
                  </div>
                  {item.reviewed_at ? (
                    <div className="stack-sm">
                      <p className="row" style={{ color: 'var(--color-success)', fontWeight: 800 }}>
                        <CheckCircle2 size={18} aria-hidden="true" /> Répondu le {formatDateTime(item.reviewed_at)} par{' '}
                        {item.reviewed_by_user_id === user.id ? 'vous' : `…${shortId(item.reviewed_by_user_id)}`}
                      </p>
                      {item.triage && <Badge tone={TRIAGE_LABELS[item.triage].tone}>{TRIAGE_LABELS[item.triage].label}</Badge>}
                      <p>{item.review_note}</p>
                      {item.orientation_site_id && (
                        <p className="info-tile">
                          <Building2 size={22} aria-hidden="true" /> Orientée vers : <strong>{siteName(item.orientation_site_id)}</strong>
                          {item.follow_up_code && (
                            <>
                              {' · code '}
                              <span className="mono">{item.follow_up_code}</span>
                              {' · '}
                              <Badge tone={item.follow_up_status === 'came' ? 'success' : item.follow_up_status === 'no_show' ? 'danger' : 'warning'}>
                                {FOLLOW_UP_LABELS[item.follow_up_status ?? 'expected']}
                              </Badge>
                            </>
                          )}
                        </p>
                      )}
                    </div>
                  ) : (
                    <ReplyForm interaction={item} onDone={() => void queryClient.invalidateQueries({ queryKey: ['interactions'] })} />
                  )}
                  <DemoBanner isDemo={item.is_demo} />
                </li>
              );
            })}
          </ul>
        )}
        <Pagination offset={offset} total={interactions.data?.total ?? 0} onChange={setOffset} />
      </QueryState>
    </section>
  );
}
