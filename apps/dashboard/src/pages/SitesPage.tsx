import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';
import { useApi } from '../api/ApiProvider';
import { SITE_KINDS, type Site, type SiteCreate, type SiteKind } from '../api/types';
import { Badge } from '../components/Badge';
import { useSiteName, useSites } from '../components/hooks';
import { ErrorMessage, QueryState } from '../components/QueryState';

const SITE_KIND_LABELS: Record<SiteKind, string> = {
  csb: 'CSB',
  reference_facility: 'Structure de référence',
  community_zone: 'Zone communautaire',
};

const EMPTY: SiteCreate = { name: '', kind: 'csb', code: '', district: '', region: '', parent_site_id: null, is_active: true };

function CreateSiteForm({ sites, onDone }: { sites: Site[]; onDone: () => void }) {
  const api = useApi();
  const [form, setForm] = useState<SiteCreate>(EMPTY);
  const [localError, setLocalError] = useState<string | null>(null);
  const create = useMutation({ mutationFn: (body: SiteCreate) => api.createSite(body), onSuccess: onDone });

  function handleSubmit(event: FormEvent) {
    event.preventDefault();
    if (!form.name.trim() || !form.code.trim() || !form.district.trim() || !form.region.trim()) {
      setLocalError('Nom, code, district et région sont obligatoires.');
      return;
    }
    setLocalError(null);
    create.mutate({ ...form, name: form.name.trim(), code: form.code.trim(), district: form.district.trim(), region: form.region.trim() });
  }

  const text = (key: 'name' | 'code' | 'district' | 'region', label: string) => (
    <div className="field">
      <label htmlFor={`ns-${key}`}>{label}</label>
      <input id={`ns-${key}`} value={form[key]} onChange={(e) => setForm({ ...form, [key]: e.target.value })} required />
    </div>
  );

  return (
    <form className="panel stack" onSubmit={handleSubmit} noValidate aria-labelledby="new-site-title">
      <h2 id="new-site-title">Nouveau site</h2>
      <div className="grid-2">
        {text('name', 'Nom')}
        {text('code', 'Code')}
        <div className="field">
          <label htmlFor="ns-kind">Type</label>
          <select id="ns-kind" value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value as SiteKind })}>
            {SITE_KINDS.map((k) => (
              <option key={k} value={k}>
                {SITE_KIND_LABELS[k]}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="ns-parent">Site parent</label>
          <select id="ns-parent" value={form.parent_site_id ?? ''} onChange={(e) => setForm({ ...form, parent_site_id: e.target.value || null })}>
            <option value="">Aucun</option>
            {sites.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
        {text('district', 'District')}
        {text('region', 'Région')}
      </div>
      {localError && (
        <p className="error" role="alert">
          {localError}
        </p>
      )}
      <ErrorMessage error={create.error} />
      <div className="row">
        <button type="submit" className="btn btn-primary" disabled={create.isPending}>
          Créer le site
        </button>
      </div>
    </form>
  );
}

export function SitesPage() {
  const api = useApi();
  const queryClient = useQueryClient();
  const sitesQuery = useSites();
  const siteName = useSiteName();
  const [creating, setCreating] = useState(false);
  const invalidate = () => void queryClient.invalidateQueries({ queryKey: ['sites'] });
  const toggle = useMutation({
    mutationFn: (site: Site) => api.updateSite(site.id, { is_active: !site.is_active }),
    onSettled: invalidate,
  });

  return (
    <section aria-labelledby="sites-title" className="stack">
      <div className="page-head">
        <h1 id="sites-title">Sites</h1>
        <button type="button" className="btn btn-primary" onClick={() => setCreating((c) => !c)} aria-expanded={creating}>
          {creating ? 'Fermer le formulaire' : 'Nouveau site'}
        </button>
      </div>
      {creating && (
        <CreateSiteForm
          sites={sitesQuery.sites}
          onDone={() => {
            setCreating(false);
            invalidate();
          }}
        />
      )}
      <ErrorMessage error={toggle.error} />
      <QueryState isPending={sitesQuery.isPending} error={sitesQuery.error}>
        <table className="table">
          <caption className="sr-only">Liste des sites</caption>
          <thead>
            <tr>
              <th scope="col">Nom</th>
              <th scope="col">Code</th>
              <th scope="col">Type</th>
              <th scope="col">Rattachement</th>
              <th scope="col">District / région</th>
              <th scope="col">État</th>
              <th scope="col">
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {sitesQuery.sites.map((site) => (
              <tr key={site.id} className={site.is_active ? undefined : 'row-muted'}>
                <td data-label="Nom">{site.name}</td>
                <td data-label="Code" className="mono">
                  {site.code}
                </td>
                <td data-label="Type">{SITE_KIND_LABELS[site.kind]}</td>
                <td data-label="Rattachement">{siteName(site.parent_site_id)}</td>
                <td data-label="District / région">
                  {site.district} / {site.region}
                </td>
                <td data-label="État">{site.is_active ? <Badge tone="success">Actif</Badge> : <Badge>Inactif</Badge>}</td>
                <td>
                  <button type="button" className="btn btn-secondary" disabled={toggle.isPending} onClick={() => toggle.mutate(site)}>
                    {site.is_active ? 'Désactiver' : 'Réactiver'}
                    {' '}<span className="sr-only">{site.name}</span>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </QueryState>
    </section>
  );
}
