import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import type { Interaction } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { DemoBanner } from '../components/DemoBanner';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { SEVERITY_LABELS } from '../domain/alerts';
import { formatDateTime, shortId } from '../domain/format';

const OUTCOME_LABELS: Record<Interaction['outcome'], string> = {
  answer: 'Réponse diffusée',
  danger_sign: 'Signe de danger',
  fallback: 'Transférée au conseiller',
};

function ReviewForm({ interaction, onDone }: { interaction: Interaction; onDone: () => void }) {
  const api = useApi();
  const [note, setNote] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);
  const review = useMutation({ mutationFn: (n: string) => api.reviewInteraction(interaction.id, { note: n }), onSuccess: onDone });
  const id = `review-${interaction.id}`;

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!note.trim()) {
      setLocalError('Documentez votre réponse ou votre orientation.');
      return;
    }
    setLocalError(null);
    review.mutate(note.trim());
  }

  return (
    <form className="stack-sm" onSubmit={handleSubmit} noValidate>
      <div className="field">
        <label htmlFor={id}>Réponse ou orientation documentée</label>
        <textarea id={id} rows={2} value={note} aria-invalid={!!localError} onChange={(e) => setNote(e.target.value)} />
      </div>
      {localError && (
        <p className="error" role="alert">
          {localError}
        </p>
      )}
      <ErrorMessage error={review.error} />
      <div>
        <button type="submit" className="btn btn-primary" disabled={review.isPending}>
          Enregistrer la revue
        </button>
      </div>
    </form>
  );
}

export function InteractionsPage() {
  const api = useApi();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const [offset, setOffset] = useState(0);
  const interactions = useQuery({
    queryKey: ['interactions', offset],
    queryFn: () => api.listInteractions({ limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  });

  return (
    <section aria-labelledby="inter-title" className="stack">
      <h1 id="inter-title">Questions à revoir</h1>
      <p className="muted small">
        Questions transférées ou non couvertes par les contenus validés. La décision d&apos;alerte vient du moteur de
        règles, jamais de l&apos;IA ; ici, le conseiller documente la suite donnée.
      </p>
      <QueryState isPending={interactions.isPending} error={interactions.error}>
        {interactions.data && interactions.data.items.length === 0 ? (
          <p className="muted">Aucune question à revoir.</p>
        ) : (
          <ul className="list">
            {interactions.data?.items.map((item) => (
              <li key={item.id} className="panel stack-sm">
                <DemoBanner isDemo={item.is_demo} />
                <div className="page-head">
                  <h2 className="h3">
                    {OUTCOME_LABELS[item.outcome]} · {item.module.toUpperCase()}
                  </h2>
                  <div>
                    {item.severity && <Badge tone={item.severity === 'critical' ? 'danger' : 'warning'}>{SEVERITY_LABELS[item.severity]}</Badge>}{' '}
                    {item.reviewed_at ? <Badge tone="success">Revue faite</Badge> : <Badge tone="warning">À revoir</Badge>}
                  </div>
                </div>
                <p className="muted small">
                  Reçue le {formatDateTime(item.created_at)}
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
                </p>
                <blockquote className="transcript">
                  {item.transcript ?? <span className="muted">Pas de transcription (saisie de signes).</span>}
                  {item.transcript_needs_review && <p className="small warning-text">Transcription automatique à vérifier.</p>}
                </blockquote>
                {item.reviewed_at ? (
                  <p>
                    <strong>Revue</strong> du {formatDateTime(item.reviewed_at)} par{' '}
                    {item.reviewed_by_user_id === user.id ? 'vous' : `…${shortId(item.reviewed_by_user_id)}`} : {item.review_note}
                  </p>
                ) : (
                  <ReviewForm interaction={item} onDone={() => void queryClient.invalidateQueries({ queryKey: ['interactions'] })} />
                )}
              </li>
            ))}
          </ul>
        )}
        <Pagination offset={offset} total={interactions.data?.total ?? 0} onChange={setOffset} />
      </QueryState>
    </section>
  );
}
