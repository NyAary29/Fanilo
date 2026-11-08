import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { useApi } from '../api/ApiProvider';
import { ROLES, type Role, type User, type UserCreate } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { ROLE_LABELS } from '../auth/permissions';
import { Badge } from '../components/Badge';
import { useSiteName, useSites } from '../components/hooks';
import { PAGE_SIZE, Pagination } from '../components/Pagination';
import { ErrorMessage, QueryState } from '../components/QueryState';
import { formatDateTime } from '../domain/format';

/**
 * Gestion des comptes (rôle admin). On n'affiche que des données de compte
 * (identifiant, rôle, site) : aucune donnée nominative de bénéficiaire.
 */
function CreateUserForm({ onDone }: { onDone: () => void }) {
  const api = useApi();
  const { sites } = useSites();
  const [form, setForm] = useState<UserCreate>({ login: '', password: '', role: 'community_agent', site_id: null });
  const [localError, setLocalError] = useState<string | null>(null);
  const create = useMutation({ mutationFn: (body: UserCreate) => api.createUser(body), onSuccess: onDone });

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!form.login.trim()) return setLocalError("L'identifiant est obligatoire.");
    if (form.password.length < 12) return setLocalError('Le mot de passe doit contenir au moins 12 caractères.');
    setLocalError(null);
    create.mutate({ ...form, login: form.login.trim() });
  }

  return (
    <form className="panel stack" onSubmit={handleSubmit} noValidate aria-labelledby="new-user-title">
      <h2 id="new-user-title">Nouvel utilisateur</h2>
      <div className="grid-2">
        <div className="field">
          <label htmlFor="nu-login">Identifiant</label>
          <input id="nu-login" autoComplete="off" value={form.login} onChange={(e) => setForm({ ...form, login: e.target.value })} required />
        </div>
        <div className="field">
          <label htmlFor="nu-password">Mot de passe initial</label>
          <input
            id="nu-password"
            type="password"
            autoComplete="new-password"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            required
            minLength={12}
          />
        </div>
        <div className="field">
          <label htmlFor="nu-role">Rôle</label>
          <select id="nu-role" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}>
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="nu-site">Site</label>
          <select id="nu-site" value={form.site_id ?? ''} onChange={(e) => setForm({ ...form, site_id: e.target.value || null })}>
            <option value="">Aucun (vue globale)</option>
            {sites.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
      </div>
      {localError && (
        <p className="error" role="alert">
          {localError}
        </p>
      )}
      <ErrorMessage error={create.error} />
      <div className="row">
        <button type="submit" className="btn btn-primary" disabled={create.isPending}>
          Créer le compte
        </button>
      </div>
    </form>
  );
}

function UserRow({ user, isSelf, onChanged }: { user: User; isSelf: boolean; onChanged: () => void }) {
  const api = useApi();
  const siteName = useSiteName();
  const [role, setRole] = useState<Role>(user.role);
  const update = useMutation({
    mutationFn: (body: Parameters<typeof api.updateUser>[1]) => api.updateUser(user.id, body),
    onSettled: onChanged,
  });
  const roleSelectId = `role-${user.id}`;

  return (
    <tr className={user.is_active ? undefined : 'row-muted'}>
      <td data-label="Identifiant" className="mono">
        {user.login}
      </td>
      <td data-label="Rôle">
        <div className="row">
          <label htmlFor={roleSelectId} className="sr-only">
            Rôle de {user.login}
          </label>
          <select id={roleSelectId} value={role} disabled={isSelf} onChange={(e) => setRole(e.target.value as Role)}>
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {ROLE_LABELS[r]}
              </option>
            ))}
          </select>
          {role !== user.role && (
            <button type="button" className="btn btn-secondary" disabled={update.isPending} onClick={() => update.mutate({ role })}>
              Appliquer
            </button>
          )}
        </div>
      </td>
      <td data-label="Site">{siteName(user.site_id)}</td>
      <td data-label="Dernière connexion">{formatDateTime(user.last_login_at)}</td>
      <td data-label="État">{user.is_active ? <Badge tone="success">Actif</Badge> : <Badge>Désactivé</Badge>}</td>
      <td>
        {!isSelf &&
          (user.is_active ? (
            <button
              type="button"
              className="btn btn-danger"
              disabled={update.isPending}
              onClick={() => {
                if (window.confirm(`Désactiver le compte ${user.login} ?`)) update.mutate({ is_active: false });
              }}
            >
              Désactiver{' '}<span className="sr-only">{user.login}</span>
            </button>
          ) : (
            <button type="button" className="btn btn-secondary" disabled={update.isPending} onClick={() => update.mutate({ is_active: true })}>
              Réactiver{' '}<span className="sr-only">{user.login}</span>
            </button>
          ))}
        <ErrorMessage error={update.error} />
      </td>
    </tr>
  );
}

export function UsersPage() {
  const api = useApi();
  const me = useCurrentUser();
  const queryClient = useQueryClient();
  const [offset, setOffset] = useState(0);
  const [creating, setCreating] = useState(false);
  const users = useQuery({
    queryKey: ['users', offset],
    queryFn: () => api.listUsers({ limit: PAGE_SIZE, offset }),
    placeholderData: keepPreviousData,
  });
  const invalidate = () => void queryClient.invalidateQueries({ queryKey: ['users'] });

  return (
    <section aria-labelledby="users-title" className="stack">
      <div className="page-head">
        <h1 id="users-title">Utilisateurs</h1>
        <button type="button" className="btn btn-primary" onClick={() => setCreating((c) => !c)} aria-expanded={creating}>
          {creating ? 'Fermer le formulaire' : 'Nouvel utilisateur'}
        </button>
      </div>
      {creating && (
        <CreateUserForm
          onDone={() => {
            setCreating(false);
            invalidate();
          }}
        />
      )}
      <QueryState isPending={users.isPending} error={users.error}>
        <table className="table">
          <caption className="sr-only">Liste des utilisateurs</caption>
          <thead>
            <tr>
              <th scope="col">Identifiant</th>
              <th scope="col">Rôle</th>
              <th scope="col">Site</th>
              <th scope="col">Dernière connexion</th>
              <th scope="col">État</th>
              <th scope="col">
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {users.data?.items.map((u) => (
              <UserRow key={`${u.id}-${u.role}`} user={u} isSelf={u.id === me.id} onChanged={invalidate} />
            ))}
          </tbody>
        </table>
        <Pagination offset={offset} total={users.data?.total ?? 0} onChange={setOffset} />
      </QueryState>
    </section>
  );
}
