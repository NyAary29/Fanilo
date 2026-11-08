import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import type { ReferralTransition } from '../api/types';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { useSiteName } from '../components/hooks';
import { QueryState } from '../components/QueryState';
import { ReferralTransitionForm } from '../components/ReferralTransitionForm';
import { formatDateTime } from '../domain/format';
import { REFERRAL_STATUS_LABELS } from '../domain/referrals';

export function ReferralDetailPage() {
  const { id = '' } = useParams();
  const api = useApi();
  const siteName = useSiteName();
  const queryClient = useQueryClient();
  const referral = useQuery({ queryKey: ['referral', id], queryFn: () => api.getReferral(id) });

  const transition = useMutation({
    mutationFn: (body: ReferralTransition) => api.transitionReferral(id, body),
    onSuccess: (updated) => queryClient.setQueryData(['referral', id], updated),
    // En cas de 409, l'état serveur a pu changer : on recharge toujours.
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ['referral', id] });
      void queryClient.invalidateQueries({ queryKey: ['referrals'] });
      void queryClient.invalidateQueries({ queryKey: ['dashboard-summary'] });
    },
  });

  const r = referral.data;
  return (
    <section aria-labelledby="refd-title" className="stack">
      <p>
        <Link to="/references">← Retour aux références</Link>
      </p>
      <QueryState isPending={referral.isPending} error={referral.error}>
        {r && (
          <>
            <div className="page-head">
              <h1 id="refd-title">Référence vers {siteName(r.to_site_id)}</h1>
              <Badge>{REFERRAL_STATUS_LABELS[r.status]}</Badge>
            </div>
            <dl className="details panel">
              <dt>Bénéficiaire</dt>
              <dd>
                <BeneficiaryRef beneficiaryId={r.beneficiary_id} allowIdentity />
              </dd>
              <dt>Site d&apos;origine</dt>
              <dd>{siteName(r.from_site_id)}</dd>
              <dt>Site de destination</dt>
              <dd>{siteName(r.to_site_id)}</dd>
              <dt>Alerte liée</dt>
              <dd>{r.alert_id ? <Link to={`/alertes/${r.alert_id}`}>Voir l&apos;alerte</Link> : '—'}</dd>
              <dt>Motif</dt>
              <dd>{r.reason ?? '—'}</dd>
              <dt>Note de suivi</dt>
              <dd>{r.outcome_note ?? '—'}</dd>
              <dt>Créée le</dt>
              <dd>{formatDateTime(r.created_at)}</dd>
              <dt>Mise à jour</dt>
              <dd>
                {formatDateTime(r.updated_at)} (version {r.version})
              </dd>
            </dl>
            <div className="panel stack">
              <h2>Changer le statut</h2>
              <ReferralTransitionForm
                key={`${r.status}-${r.version}`}
                current={r.status}
                onSubmit={(body) => transition.mutate(body)}
                isSubmitting={transition.isPending}
                serverError={transition.error}
              />
            </div>
          </>
        )}
      </QueryState>
    </section>
  );
}
