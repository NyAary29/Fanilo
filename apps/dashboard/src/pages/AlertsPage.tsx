import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { Link, useSearchParams } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import { ALERT_STATUSES, type AlertStatus } from '../api/types';
import { Badge } from '../components/Badge';
import { BeneficiaryRef } from '../components/BeneficiaryRef';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { QueryState } from '../components/QueryState';
import { ALERT_STATUS_LABELS, isAlertOverdue, SEVERITY_LABELS, severityTone } from '../domain/alerts';
import { formatDateTime } from '../domain/format';

function parseStatus(value: string | null): AlertStatus | '' {
  return value && (ALERT_STATUSES as readonly string[]).includes(value) ? (value as AlertStatus) : '';
}

export function AlertsPage() {
  const api = useApi();
  const [params, setParams] = useSearchParams();
  const status = parseStatus(params.get('statut') ?? 'open');
  const offset = Number(params.get('offset') ?? 0) || 0;

  const alerts = useQuery({
    queryKey: ['alerts', status, offset],
    queryFn: () => api.listAlerts({ status: status || undefined, limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
    refetchInterval: 30_000,
  });

  const update = (next: Record<string, string>) => setParams({ statut: status || 'tous', offset: '0', ...next });
  const now = new Date();

  return (
    <section aria-labelledby="alerts-title" className="stack">
      <div className="page-head">
        <h1 id="alerts-title">Alertes</h1>
        <div className="field inline">
          <label htmlFor="alert-status">Statut</label>
          <select id="alert-status" value={status || 'tous'} onChange={(e) => update({ statut: e.target.value })}>
            <option value="tous">Tous</option>
            {ALERT_STATUSES.map((s) => (
              <option key={s} value={s}>
                {ALERT_STATUS_LABELS[s]}
              </option>
            ))}
          </select>
        </div>
      </div>

      <QueryState isPending={alerts.isPending} error={alerts.error}>
        {alerts.data && alerts.data.items.length === 0 ? (
          <p className="muted">Aucune alerte pour ce filtre.</p>
        ) : (
          <table className="table">
            <caption className="sr-only">Liste des alertes</caption>
            <thead>
              <tr>
                <th scope="col">Sévérité</th>
                <th scope="col">Statut</th>
                <th scope="col">Bénéficiaire</th>
                <th scope="col">Échéance</th>
                <th scope="col">Règle</th>
                <th scope="col">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {alerts.data?.items.map((alert) => {
                const overdue = isAlertOverdue(alert, now);
                return (
                  <tr key={alert.id} className={overdue ? 'row-overdue' : undefined}>
                    <td data-label="Sévérité">
                      <Badge tone={severityTone(alert.severity)}>{SEVERITY_LABELS[alert.severity]}</Badge>
                      {alert.is_demo && <Badge tone="info">DÉMO</Badge>}
                    </td>
                    <td data-label="Statut">
                      {ALERT_STATUS_LABELS[alert.status]}
                      {overdue && (
                        <>
                          {' '}
                          <Badge tone="danger">En retard</Badge>
                        </>
                      )}
                    </td>
                    <td data-label="Bénéficiaire">
                      <BeneficiaryRef beneficiaryId={alert.beneficiary_id} />
                    </td>
                    <td data-label="Échéance">{formatDateTime(alert.due_at)}</td>
                    <td data-label="Règle" className="mono">
                      {alert.rule_id} <span className="muted">({alert.ruleset_version})</span>
                    </td>
                    <td>
                      <Link to={`/alertes/${alert.id}`}>
                        Détail{' '}<span className="sr-only">de l&apos;alerte {alert.rule_id}</span>
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
        <Pagination offset={offset} total={alerts.data?.total ?? 0} onChange={(o) => update({ offset: String(o) })} />
      </QueryState>
    </section>
  );
}
