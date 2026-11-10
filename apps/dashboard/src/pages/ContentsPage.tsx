import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useApi } from '../api/ApiProvider';
import {
  CONTENT_LANGUAGES,
  CONTENT_MODULES,
  CONTENT_STATUSES,
  type ContentCreate,
  type ContentItem,
  type ContentStatus,
} from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import {
  canEditContent,
  canRetireContent,
  canSubmitContent,
  canValidateContent,
  CONTENT_STATUS_LABELS,
} from '../auth/permissions';
import { Badge, type BadgeTone } from '../components/Badge';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { formatDateTime, shortId } from '../domain/format';

const STATUS_TONES: Record<ContentStatus, BadgeTone> = {
  draft: 'neutral',
  in_review: 'warning',
  validated: 'success',
  retired: 'neutral',
  demo: 'info',
};

const MODULE_LABELS = { reny: 'RENY', tanora: 'TANORA', common: 'Commun' } as const;
const LANGUAGE_LABELS = { mg: 'Malgache', fr: 'Français' } as const;

const EMPTY: ContentCreate = { code: 'MSG_', module: 'reny', language: 'mg', title: '', body: '', audio_url: null, source_ref: null };

function ContentForm({
  initial,
  isNew,
  onCancel,
  onSaved,
}: {
  initial: ContentItem | null;
  isNew: boolean;
  onCancel: () => void;
  onSaved: () => void;
}) {
  const api = useApi();
  const [form, setForm] = useState<ContentCreate>(
    initial
      ? {
          code: initial.code,
          module: initial.module,
          language: initial.language,
          title: initial.title,
          body: initial.body,
          audio_url: initial.audio_url,
          source_ref: initial.source_ref,
        }
      : EMPTY,
  );
  const [localError, setLocalError] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: (body: ContentCreate) => {
      if (!initial) return api.createContent(body);
      const { code: _code, ...changes } = body; // le code n'est pas modifiable
      return api.updateContent(initial.id, changes);
    },
    onSuccess: onSaved,
  });

  const set = <K extends keyof ContentCreate>(key: K, value: ContentCreate[K]) => setForm((f) => ({ ...f, [key]: value }));

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!/^MSG_[A-Z0-9_]+$/.test(form.code)) {
      setLocalError('Le code doit commencer par MSG_ et ne contenir que des majuscules, chiffres et _.');
      return;
    }
    if (!form.title.trim() || !form.body.trim()) {
      setLocalError('Le titre et le texte sont obligatoires.');
      return;
    }
    setLocalError(null);
    save.mutate({
      ...form,
      title: form.title.trim(),
      body: form.body.trim(),
      audio_url: form.audio_url?.trim() || null,
      source_ref: form.source_ref?.trim() || null,
    });
  }

  return (
    <form className="editor" onSubmit={handleSubmit} noValidate aria-labelledby="content-form-title">
      <div className="panel stack">
        <h2 id="content-form-title">{isNew ? 'Éditeur de contenu · nouveau brouillon' : `Éditeur de contenu · ${initial?.code ?? ''}`}</h2>
        <div className="field">
          <label htmlFor="cf-title">Titre *</label>
          <input id="cf-title" value={form.title} placeholder="Ex. : Signes de danger pendant la grossesse" onChange={(e) => set('title', e.target.value)} required />
        </div>
        <div className="field">
          <label htmlFor="cf-module">Catégorie (module)</label>
          <select id="cf-module" value={form.module} onChange={(e) => set('module', e.target.value as ContentCreate['module'])}>
            {CONTENT_MODULES.map((m) => (
              <option key={m} value={m}>
                {MODULE_LABELS[m]}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="cf-body">Texte diffusé *</label>
          <textarea id="cf-body" rows={9} value={form.body} onChange={(e) => set('body', e.target.value)} required />
          <span className="muted xs">
            Message court, simple, sans diagnostic ni prescription. Il sera lu ou enregistré en voix pour le téléphone.
          </span>
        </div>
        {localError && (
          <p className="error" role="alert">
            {localError}
          </p>
        )}
        <ErrorMessage error={save.error} />
        <div className="row">
          <button type="submit" className="btn btn-primary" disabled={save.isPending}>
            Enregistrer le brouillon
          </button>
          <button type="button" className="btn btn-secondary" onClick={onCancel}>
            Annuler
          </button>
        </div>
      </div>
      <div className="panel stack">
        <div className="stack-sm">
          <strong>Statut</strong>
          <div className="status-pill" style={{ background: '#eef0ea', color: 'var(--color-muted)' }}>
            Brouillon
          </div>
          <ol className="steps small">
            <li>Brouillon (vous écrivez)</li>
            <li>Soumis à validation</li>
            <li>Validé par un responsable clinique (autre que l&apos;auteur), puis diffusé</li>
          </ol>
        </div>
        <fieldset className="stack-sm">
          <legend>Langue</legend>
          {CONTENT_LANGUAGES.map((l) => (
            <label key={l} className="radio">
              <input type="radio" name="cf-language" checked={form.language === l} onChange={() => set('language', l)} />
              {LANGUAGE_LABELS[l]}
            </label>
          ))}
        </fieldset>
        <div className="field">
          <label htmlFor="cf-code">Code</label>
          <input id="cf-code" className="mono" value={form.code} disabled={!isNew} onChange={(e) => set('code', e.target.value.toUpperCase())} required />
        </div>
        <div className="field">
          <label htmlFor="cf-source">Référence de la source (protocole)</label>
          <input id="cf-source" value={form.source_ref ?? ''} onChange={(e) => set('source_ref', e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="cf-audio">URL de l&apos;audio (facultative)</label>
          <input id="cf-audio" type="url" value={form.audio_url ?? ''} onChange={(e) => set('audio_url', e.target.value)} />
        </div>
      </div>
    </form>
  );
}

export function ContentsPage() {
  const api = useApi();
  const user = useCurrentUser();
  const queryClient = useQueryClient();
  const [params, setParams] = useSearchParams();
  const statusParam = params.get('statut');
  const status = statusParam && (CONTENT_STATUSES as readonly string[]).includes(statusParam) ? (statusParam as ContentStatus) : '';
  const offset = Number(params.get('offset') ?? 0) || 0;
  const [editing, setEditing] = useState<ContentItem | 'new' | null>(null);

  const contents = useQuery({
    queryKey: ['contents', status, offset],
    queryFn: () => api.listContents({ status: status || undefined, limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['contents'] });
  const action = useMutation({
    mutationFn: ({ kind, id }: { kind: 'submit' | 'validate' | 'retire'; id: string }) =>
      kind === 'submit' ? api.submitContent(id) : kind === 'validate' ? api.validateContent(id) : api.retireContent(id),
    onSettled: invalidate,
  });

  const update = (next: Record<string, string>) => setParams({ statut: status || 'tous', offset: '0', ...next });
  const author = (id: string) => (id === user.id ? 'vous' : `…${shortId(id)}`);

  return (
    <section aria-labelledby="contents-title" className="stack">
      <div className="page-head">
        <div>
          <h1 id="contents-title">Contenus de santé</h1>
          <p className="subtitle">Les seuls messages que FANILO a le droit de diffuser.</p>
        </div>
        <div className="row">
          <div className="field inline">
            <label htmlFor="content-status">Statut</label>
            <select id="content-status" value={status || 'tous'} onChange={(e) => update({ statut: e.target.value })}>
              <option value="tous">Tous</option>
              {CONTENT_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {CONTENT_STATUS_LABELS[s]}
                </option>
              ))}
            </select>
          </div>
          <button type="button" className="btn btn-primary" onClick={() => setEditing('new')}>
            <Plus size={18} aria-hidden="true" /> Nouveau contenu
          </button>
        </div>
      </div>
      <p className="muted small">
        Tout contenu diffusé doit être validé par le responsable clinique. Un auteur ne valide jamais son propre contenu.
      </p>

      {editing && (
        <ContentForm
          key={editing === 'new' ? 'new' : editing.id}
          initial={editing === 'new' ? null : editing}
          isNew={editing === 'new'}
          onCancel={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            void invalidate();
          }}
        />
      )}

      <ErrorMessage error={action.error} />
      <QueryState isPending={contents.isPending} error={contents.error}>
        {contents.data && contents.data.items.length === 0 ? (
          <p className="muted">Aucun contenu pour ce filtre.</p>
        ) : (
          <ul className="list">
            {contents.data?.items.map((item) => (
              <li key={item.id} className="panel stack-sm">
                <div className="page-head">
                  <h2 className="h3">
                    {item.title} <span className="mono muted small">{item.code}</span>
                  </h2>
                  <div>
                    {item.status === 'demo' ? (
                      <Badge tone="info">DÉMO — non validé cliniquement</Badge>
                    ) : (
                      <Badge tone={STATUS_TONES[item.status]}>{CONTENT_STATUS_LABELS[item.status]}</Badge>
                    )}
                  </div>
                </div>
                <p className="content-body">{item.body}</p>
                <p className="muted small">
                  {MODULE_LABELS[item.module]} · {LANGUAGE_LABELS[item.language]} · version {item.version} · auteur {author(item.author_id)}
                  {item.validated_at && ` · validé le ${formatDateTime(item.validated_at)} par ${author(item.validator_id ?? '')}`}
                  {item.source_ref && ` · source : ${item.source_ref}`}
                </p>
                <div className="row">
                  {canEditContent(user, item) && (
                    <button type="button" className="btn btn-secondary" onClick={() => setEditing(item)}>
                      Modifier{' '}<span className="sr-only">{item.code}</span>
                    </button>
                  )}
                  {canSubmitContent(user, item) && (
                    <button type="button" className="btn btn-secondary" disabled={action.isPending} onClick={() => action.mutate({ kind: 'submit', id: item.id })}>
                      Soumettre à validation{' '}<span className="sr-only">{item.code}</span>
                    </button>
                  )}
                  {canValidateContent(user, item) && (
                    <button type="button" className="btn btn-primary" disabled={action.isPending} onClick={() => action.mutate({ kind: 'validate', id: item.id })}>
                      Valider{' '}<span className="sr-only">{item.code}</span>
                    </button>
                  )}
                  {canRetireContent(user, item) && (
                    <button
                      type="button"
                      className="btn btn-danger"
                      disabled={action.isPending}
                      onClick={() => {
                        if (window.confirm(`Retirer le contenu ${item.code} ? Il ne sera plus diffusé.`)) action.mutate({ kind: 'retire', id: item.id });
                      }}
                    >
                      Retirer{' '}<span className="sr-only">{item.code}</span>
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
        <Pagination offset={offset} total={contents.data?.total ?? 0} onChange={(o) => update({ offset: String(o) })} />
      </QueryState>
    </section>
  );
}
