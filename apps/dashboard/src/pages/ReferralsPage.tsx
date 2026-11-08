import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { Link, useSearchParams } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import { REFERRAL_STATUSES, type ReferralStatus } from '../api/types';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { useSiteName } from '../components/hooks';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { QueryState } from '../components/QueryState';
import { formatDateTime } from '../domain/format';
import { isTerminalReferralStatus, REFERRAL_STATUS_LABELS } from '../domain/referrals';

function parseStatus(value: string | null): ReferralStatus | '' {
  return value && (REFERRAL_STATUSES as readonly string[]).includes(value) ? (value as ReferralStatus) : '';
}

export function ReferralsPage() {
  const api = useApi();
  const siteName = useSiteName();
  const [params, setParams] = useSearchParams();
  const status = parseStatus(params.get('statut'));
  const offset = Number(params.get('offset') ?? 0) || 0;

  const referrals = useQuery({
    queryKey: ['referrals', status, offset],
    queryFn: () => api.listReferrals({ status: status || undefined, limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  });

  const update = (next: Record<string, string>) => setParams({ statut: status || 'tous', offset: '0', ...next });

  return (
    <section aria-labelledby="ref-title" className="stack">
      <div className="page-head">
        <h1 id="ref-title">Références</h1>
        <div className="field inline">
          <label htmlFor="ref-status">Statut</label>
          <select id="ref-status" value={status || 'tous'} onChange={(e) => update({ statut: e.target.value })}>
            <option value="tous">Tous</option>
            {REFERRAL_STATUSES.map((s) => (
              <option key={s} value={s}>
                {REFERRAL_STATUS_LABELS[s]}
              </option>
            ))}
          </select>
        </div>
      </div>
      <QueryState isPending={referrals.isPending} error={referrals.error}>
        {referrals.data && referrals.data.items.length === 0 ? (
          <p className="muted">Aucune référence pour ce filtre.</p>
        ) : (
          <table className="table">
            <caption className="sr-only">Liste des références</caption>
            <thead>
              <tr>
                <th scope="col">Statut</th>
                <th scope="col">Bénéficiaire</th>
                <th scope="col">De</th>
                <th scope="col">Vers</th>
                <th scope="col">Mise à jour</th>
                <th scope="col">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {referrals.data?.items.map((r) => (
                <tr key={r.id}>
                  <td data-label="Statut">
                    <Badge tone={isTerminalReferralStatus(r.status) ? (r.status === 'arrived' ? 'success' : 'neutral') : 'warning'}>
                      {REFERRAL_STATUS_LABELS[r.status]}
                    </Badge>
                  </td>
                  <td data-label="Bénéficiaire">
                    <BeneficiaryRef beneficiaryId={r.beneficiary_id} />
                  </td>
                  <td data-label="De">{siteName(r.from_site_id)}</td>
                  <td data-label="Vers">{siteName(r.to_site_id)}</td>
                  <td data-label="Mise à jour">{formatDateTime(r.updated_at)}</td>
                  <td>
                    <Link to={`/references/${r.id}`}>
                      Détail{' '}<span className="sr-only">de la référence vers {siteName(r.to_site_id)}</span>
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <Pagination offset={offset} total={referrals.data?.total ?? 0} onChange={(o) => update({ offset: String(o) })} />
      </QueryState>
    </section>
  );
}
