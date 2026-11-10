import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CheckCircle2, MapPinCheck, Search, XCircle } from 'lucide-react';
import { useState } from 'react';
import { useApi } from '../api/ApiProvider';
import type { FollowUpStatus, OrientationItem } from '../api/types';
import { Badge } from '../components/Badge';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { formatDateTime } from '../domain/format';
import { TRIAGE_LABELS } from './InteractionsPage';

const TABS: { status: FollowUpStatus; label: string }[] = [
  { status: 'expected', label: 'Attendues' },
  { status: 'came', label: 'Venues' },
  { status: 'no_show', label: 'Pas venues' },
];

/**
 * Suivi par le responsable du centre de santé : les personnes que le conseiller a
 * orientées vers son centre. Elles sont anonymes : on les reconnaît à leur code
 * (affiché dans leur application), et on enregistre si elles sont venues.
 */
export function OrientationsPage() {
  const api = useApi();
  const [status, setStatus] = useState<FollowUpStatus>('expected');
  const [code, setCode] = useState('');
  const search = code.trim().toUpperCase();
  const list = useQuery({
    queryKey: ['orientations', search ? 'code' : status, search],
    queryFn: () => api.listOrientations(search.length >= 4 ? { code: search } : { status }),
    refetchInterval: 15_000,
  });

  return (
    <section aria-labelledby="orient-title" className="stack">
      <div>
        <h1 id="orient-title">Suivi des orientations</h1>
        <p className="subtitle">
          Les femmes que le conseiller a envoyées vers votre centre. Quand l’une d’elles se présente, elle montre son{' '}
          <strong>code</strong> : retrouvez-la ici et cliquez « Elle est venue ».
        </p>
      </div>

      <div className="row">
        <div className="search" style={{ minWidth: 260 }}>
          <Search size={18} aria-hidden="true" />
          <label htmlFor="code-search" className="sr-only">
            Code montré par la personne
          </label>
          <input
            id="code-search"
            placeholder="Code montré par la personne (ex. K7-42)"
            value={code}
            maxLength={8}
            onChange={(e) => setCode(e.target.value)}
          />
        </div>
        {!search && (
          <div className="segmented" role="tablist" aria-label="Statut">
            {TABS.map((t) => (
              <button key={t.status} type="button" role="tab" aria-selected={status === t.status} onClick={() => setStatus(t.status)}>
                {t.label} ({list.data?.counts[t.status] ?? '…'})
              </button>
            ))}
          </div>
        )}
      </div>

      <QueryState isPending={list.isPending} error={list.error}>
        {list.data?.items.length === 0 ? (
          <div className="empty panel">
            <MapPinCheck size={44} aria-hidden="true" />
            <p>{search ? `Aucune personne avec le code ${search}.` : 'Personne dans cette liste.'}</p>
          </div>
        ) : (
          <ul className="list">
            {list.data?.items.map((item) => (
              <OrientationCard key={item.id} item={item} />
            ))}
          </ul>
        )}
      </QueryState>
    </section>
  );
}

function OrientationCard({ item }: { item: OrientationItem }) {
  const api = useApi();
  const queryClient = useQueryClient();
  const [note, setNote] = useState('');
  const update = useMutation({
    mutationFn: (status: 'came' | 'no_show') => api.updateOrientation(item.id, { status, note: note.trim() || null }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['orientations'] }),
  });
  const triage = item.triage ? TRIAGE_LABELS[item.triage] : null;
  return (
    <li className="panel stack-sm" style={item.triage === 'urgent' ? { borderColor: 'var(--color-danger)', borderWidth: 2 } : undefined}>
      <div className="row">
        <span className="mono" style={{ fontSize: '1.6rem', fontWeight: 900, letterSpacing: '0.08em' }}>
          {item.follow_up_code}
        </span>
        {triage && <Badge tone={triage.tone}>{triage.label}</Badge>}
        <Badge tone={item.module === 'tanora' ? 'success' : 'warning'}>{item.module === 'tanora' ? 'TANORA' : 'RENY'}</Badge>
        <span className="spacer" />
        <span className="muted small">
          Orientée le {formatDateTime(item.reviewed_at)} vers <strong>{item.site_name}</strong>
        </span>
      </div>
      {item.question && (
        <p>
          <span className="muted small">Elle a demandé : </span>« {item.question} »
        </p>
      )}
      {item.answer && (
        <p>
          <span className="muted small">Le conseiller a répondu : </span>
          {item.answer}
        </p>
      )}
      {item.follow_up_status === 'expected' ? (
        <div className="stack-sm">
          <div className="field">
            <label htmlFor={`note-${item.id}`}>Note (facultative)</label>
            <input id={`note-${item.id}`} value={note} maxLength={1000} onChange={(e) => setNote(e.target.value)} />
          </div>
          <div className="row">
            <button type="button" className="btn btn-primary" disabled={update.isPending} onClick={() => update.mutate('came')}>
              <CheckCircle2 size={18} aria-hidden="true" /> Elle est venue
            </button>
            <button type="button" className="btn btn-secondary" disabled={update.isPending} onClick={() => update.mutate('no_show')}>
              <XCircle size={18} aria-hidden="true" /> Pas venue
            </button>
          </div>
          <ErrorMessage error={update.error} />
        </div>
      ) : (
        <p className="row" style={{ fontWeight: 800, color: item.follow_up_status === 'came' ? 'var(--color-success)' : 'var(--color-danger)' }}>
          {item.follow_up_status === 'came' ? <CheckCircle2 size={18} aria-hidden="true" /> : <XCircle size={18} aria-hidden="true" />}
          {item.follow_up_status === 'came' ? 'Venue au centre' : 'Pas venue'} — {formatDateTime(item.follow_up_at)}
          {item.follow_up_note && <span className="muted"> · {item.follow_up_note}</span>}
        </p>
      )}
    </li>
  );
}
