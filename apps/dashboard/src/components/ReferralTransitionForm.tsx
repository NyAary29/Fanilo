import { useId, useState, type FormEvent } from 'react';
import type { ReferralStatus, ReferralTransition } from '../api/types';
import { allowedReferralTransitions, REFERRAL_STATUS_LABELS, validateReferralTransition } from '../domain/referrals';
import { ErrorMessage } from './QueryState';

/**
 * Formulaire de transition d'une référence.
 * N'offre que les transitions autorisées depuis l'état courant (copie ergonomique de la
 * machine à états ; le serveur fait foi). Le motif est obligatoire pour `not_completed`.
 */
export function ReferralTransitionForm({
  current,
  onSubmit,
  isSubmitting = false,
  serverError,
}: {
  current: ReferralStatus;
  onSubmit: (transition: ReferralTransition) => void;
  isSubmitting?: boolean;
  serverError?: unknown;
}) {
  const options = allowedReferralTransitions(current);
  const [toStatus, setToStatus] = useState<ReferralStatus | ''>('');
  const [reason, setReason] = useState('');
  const [outcomeNote, setOutcomeNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const uid = useId();

  if (options.length === 0) {
    return <p className="muted">Cette référence est dans un état final : aucune transition possible.</p>;
  }

  const reasonRequired = toStatus === 'not_completed';

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!toStatus) {
      setError('Choisissez le nouveau statut.');
      return;
    }
    const message = validateReferralTransition(current, toStatus, reason);
    if (message) {
      setError(message);
      return;
    }
    setError(null);
    const payload: ReferralTransition = { to_status: toStatus };
    if (reason.trim()) payload.reason = reason.trim();
    if (outcomeNote.trim()) payload.outcome_note = outcomeNote.trim();
    onSubmit(payload);
  }

  const errorId = `${uid}-error`;
  const reasonId = `${uid}-reason`;

  return (
    <form className="stack" onSubmit={handleSubmit} noValidate aria-describedby={error ? errorId : undefined}>
      <fieldset>
        <legend>Nouveau statut</legend>
        <div className="radio-group">
          {options.map((status) => (
            <label key={status} className="radio">
              <input
                type="radio"
                name={`${uid}-to-status`}
                value={status}
                checked={toStatus === status}
                onChange={() => {
                  setToStatus(status);
                  setError(null);
                }}
              />
              {REFERRAL_STATUS_LABELS[status]}
            </label>
          ))}
        </div>
      </fieldset>

      <div className="field">
        <label htmlFor={reasonId}>
          Motif{reasonRequired ? ' (obligatoire)' : ' (facultatif)'}
        </label>
        <textarea
          id={reasonId}
          value={reason}
          required={reasonRequired}
          aria-required={reasonRequired}
          aria-invalid={reasonRequired && !!error && !reason.trim()}
          aria-describedby={error ? errorId : undefined}
          onChange={(e) => setReason(e.target.value)}
          rows={2}
        />
      </div>

      <div className="field">
        <label htmlFor={`${uid}-outcome`}>Note de suivi (facultative)</label>
        <textarea id={`${uid}-outcome`} value={outcomeNote} onChange={(e) => setOutcomeNote(e.target.value)} rows={2} />
      </div>

      {error && (
        <p id={errorId} className="error" role="alert">
          {error}
        </p>
      )}
      <ErrorMessage error={serverError} />

      <div>
        <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
          {isSubmitting ? 'Enregistrement…' : 'Enregistrer la transition'}
        </button>
      </div>
    </form>
  );
}
