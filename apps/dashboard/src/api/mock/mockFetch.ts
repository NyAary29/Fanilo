/**
 * Adaptateur mock « maison » : une fonction compatible `fetch` qui sert les routes du
 * contrat à partir d'une base en mémoire de données FICTIVES (voir data.ts).
 *
 * Il reproduit les règles utiles à l'interface (rôles, périmètre de site simplifié,
 * données nominatives, machine à états des références, cycle des contenus) pour que
 * les écrans se comportent comme face au vrai backend. Il ne remplace pas les tests
 * du backend : le serveur reste la référence.
 */
import { NOMINATIVE_DATA_ROLES } from '../../auth/permissions';
import { isAlertOverdue } from '../../domain/alerts';
import { isPendingReferral, validateReferralTransition } from '../../domain/referrals';
import type { FetchLike } from '../client';
import type {
  AlertEventType,
  ContentCreate,
  ContentItem,
  DashboardSummary,
  ReferralTransition,
  Role,
  Site,
  SiteCreate,
  User,
  UserCreate,
  UserUpdate,
} from '../types';
import { ROLES } from '../types';
import { createMockDb, type MockDb, type MockUser } from './data';

export interface MockServer {
  fetch: FetchLike;
  db: MockDb;
  /** Invalide tous les jetons d'accès (simule leur expiration, pour tester le rafraîchissement). */
  expireAccessTokens(): void;
  /** Nombre d'appels reçus par route, pour les tests. */
  calls: { method: string; path: string }[];
}

interface Ctx {
  user: MockUser;
  body: Record<string, unknown>;
  query: URLSearchParams;
  params: string[];
}

class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly detail: unknown,
  ) {
    super(String(detail));
  }
}

const json = (status: number, data: unknown) =>
  new Response(status === 204 ? null : JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

function requireRoles(ctx: Ctx, roles: readonly Role[]) {
  if (!roles.includes(ctx.user.role)) throw new HttpError(403, 'Rôle non autorisé');
}

function paginate<T>(items: T[], query: URLSearchParams) {
  const limit = Math.min(Number(query.get('limit') ?? 50) || 50, 200);
  const offset = Number(query.get('offset') ?? 0) || 0;
  return { items: items.slice(offset, offset + limit), total: items.length };
}

function nowIso() {
  return new Date().toISOString();
}

function newId() {
  return typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now().toString(16)}-0000-4000-8000-${Math.random().toString(16).slice(2, 14).padEnd(12, '0')}`;
}

function publicUser(u: MockUser): User {
  return {
    id: u.id,
    login: u.login,
    role: u.role,
    site_id: u.site_id,
    is_active: u.is_active,
    last_login_at: u.last_login_at,
  };
}

function requiredString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== 'string' || !value.trim()) {
    throw new HttpError(422, [{ loc: ['body', key], msg: 'Champ obligatoire' }]);
  }
  return value.trim();
}

export function createMockServer(options: { db?: MockDb; latencyMs?: number } = {}): MockServer {
  const db = options.db ?? createMockDb();
  const latency = options.latencyMs ?? 0;
  const accessTokens = new Map<string, string>(); // token → user id
  const refreshTokens = new Map<string, string>();
  const calls: MockServer['calls'] = [];
  let counter = 0;

  function issueTokens(user: MockUser) {
    counter += 1;
    const access = `mock-access-${counter}-${user.id}`;
    const refresh = `mock-refresh-${counter}-${user.id}`;
    accessTokens.set(access, user.id);
    refreshTokens.set(refresh, user.id);
    return { access_token: access, token_type: 'bearer', expires_in: 900, refresh_token: refresh, refresh_expires_in: 86_400 };
  }

  /** Sites visibles : le site de l'utilisateur et ses descendants, ou tout pour les vues globales. */
  function scopeSiteIds(user: MockUser): Set<string> | null {
    if (['admin', 'clinical_lead', 'data_officer'].includes(user.role) || !user.site_id) return null;
    const ids = new Set<string>([user.site_id]);
    let grew = true;
    while (grew) {
      grew = false;
      for (const s of db.sites) {
        if (s.parent_site_id && ids.has(s.parent_site_id) && !ids.has(s.id)) {
          ids.add(s.id);
          grew = true;
        }
      }
    }
    return ids;
  }

  function beneficiarySite(beneficiaryId: string | null): string | undefined {
    return db.beneficiaries.find((b) => b.id === beneficiaryId)?.site_id;
  }

  function inScope(user: MockUser, beneficiaryId: string | null): boolean {
    const scope = scopeSiteIds(user);
    if (!scope) return true;
    const site = beneficiarySite(beneficiaryId);
    return !!site && scope.has(site);
  }

  function findAlert(ctx: Ctx) {
    const alert = db.alerts.find((a) => a.id === ctx.params[0]);
    if (!alert || !inScope(ctx.user, alert.beneficiary_id)) throw new HttpError(404, 'Introuvable');
    return alert;
  }

  function addAlertEvent(alertId: string, type: AlertEventType, actor: string | null, note: string | null) {
    const alert = db.alerts.find((a) => a.id === alertId);
    alert?.events.push({ id: newId(), alert_id: alertId, at: nowIso(), actor_user_id: actor, type, note });
  }

  function findContent(ctx: Ctx): ContentItem {
    const item = db.contents.find((c) => c.id === ctx.params[0]);
    if (!item) throw new HttpError(404, 'Introuvable');
    return item;
  }

  function audit(ctx: Ctx, action: string, entityType: string, entityId: string) {
    db.audit.unshift({
      id: newId(),
      at: nowIso(),
      actor_user_id: ctx.user.id,
      actor_role: ctx.user.role,
      action,
      entity_type: entityType,
      entity_id: entityId,
      request_id: `req-mock-${db.audit.length + 1}`,
      site_id: ctx.user.site_id,
    });
  }

  type Handler = (ctx: Ctx) => unknown;
  const routes: [string, RegExp, Handler][] = [];
  const route = (method: string, pattern: string, handler: Handler) => {
    routes.push([method, new RegExp(`^${pattern.replace(/:id/g, '([^/]+)')}$`), handler]);
  };

  const ALERT_ROLES: Role[] = ['csb_head', 'clinical_advisor', 'clinical_lead', 'community_agent'];
  const CONTENT_ROLES: Role[] = ['clinical_lead', 'admin'];

  // --- Auth
  route('GET', '/auth/me', ({ user }) => ({ id: user.id, login: user.login, role: user.role, site_id: user.site_id, is_active: user.is_active }));

  // --- Sites
  route('GET', '/sites', ({ query }) => paginate(db.sites, query));
  route('POST', '/sites', (ctx) => {
    requireRoles(ctx, ['admin']);
    const body = ctx.body as Partial<SiteCreate>;
    const site: Site = {
      id: newId(),
      name: requiredString(ctx.body, 'name'),
      kind: body.kind ?? 'csb',
      code: requiredString(ctx.body, 'code'),
      district: requiredString(ctx.body, 'district'),
      region: requiredString(ctx.body, 'region'),
      parent_site_id: body.parent_site_id ?? null,
      is_active: body.is_active ?? true,
    };
    if (db.sites.some((s) => s.code === site.code)) throw new HttpError(409, 'Code de site déjà utilisé');
    db.sites.push(site);
    return [201, site];
  });
  route('PATCH', '/sites/:id', (ctx) => {
    requireRoles(ctx, ['admin']);
    const site = db.sites.find((s) => s.id === ctx.params[0]);
    if (!site) throw new HttpError(404, 'Introuvable');
    Object.assign(site, ctx.body);
    return site;
  });

  // --- Utilisateurs
  route('GET', '/users', (ctx) => {
    requireRoles(ctx, ['admin', 'data_officer']);
    return paginate(db.users.map(publicUser), ctx.query);
  });
  route('POST', '/users', (ctx) => {
    requireRoles(ctx, ['admin']);
    const body = ctx.body as Partial<UserCreate>;
    const login = requiredString(ctx.body, 'login');
    const password = requiredString(ctx.body, 'password');
    if (!body.role || !ROLES.includes(body.role)) throw new HttpError(422, [{ loc: ['body', 'role'], msg: 'Rôle invalide' }]);
    if (db.users.some((u) => u.login === login)) throw new HttpError(409, 'Identifiant déjà utilisé');
    const created: MockUser = { id: newId(), login, password, role: body.role, site_id: body.site_id ?? null, is_active: true, last_login_at: null };
    db.users.push(created);
    audit(ctx, 'user.create', 'user', created.id);
    return [201, publicUser(created)];
  });
  route('PATCH', '/users/:id', (ctx) => {
    requireRoles(ctx, ['admin']);
    const target = db.users.find((u) => u.id === ctx.params[0]);
    if (!target) throw new HttpError(404, 'Introuvable');
    const body = ctx.body as UserUpdate;
    if (body.role !== undefined) {
      if (!ROLES.includes(body.role)) throw new HttpError(422, [{ loc: ['body', 'role'], msg: 'Rôle invalide' }]);
      target.role = body.role;
      audit(ctx, 'user.role_change', 'user', target.id);
    }
    if (body.site_id !== undefined) target.site_id = body.site_id;
    if (body.is_active !== undefined) target.is_active = body.is_active;
    return publicUser(target);
  });

  // --- Bénéficiaires (lecture minimale)
  route('GET', '/beneficiaries/:id', (ctx) => {
    const b = db.beneficiaries.find((x) => x.id === ctx.params[0]);
    if (!b || !inScope(ctx.user, b.id)) throw new HttpError(404, 'Introuvable');
    return b;
  });
  route('GET', '/beneficiaries/:id/identity', (ctx) => {
    if (!NOMINATIVE_DATA_ROLES.has(ctx.user.role)) throw new HttpError(403, 'Accès aux données nominatives refusé');
    const identity = db.identities.find((x) => x.beneficiary_id === ctx.params[0]);
    if (!identity || !inScope(ctx.user, identity.beneficiary_id)) throw new HttpError(404, 'Introuvable');
    audit(ctx, 'beneficiary.identity.read', 'beneficiary', identity.beneficiary_id);
    return identity;
  });

  // --- Contenus
  route('GET', '/contents', (ctx) => {
    requireRoles(ctx, CONTENT_ROLES);
    const status = ctx.query.get('status');
    return paginate(status ? db.contents.filter((c) => c.status === status) : db.contents, ctx.query);
  });
  route('POST', '/contents', (ctx) => {
    requireRoles(ctx, CONTENT_ROLES);
    const body = ctx.body as Partial<ContentCreate>;
    const code = requiredString(ctx.body, 'code');
    if (!/^MSG_[A-Z0-9_]+$/.test(code)) throw new HttpError(422, [{ loc: ['body', 'code'], msg: 'Le code doit commencer par MSG_ (majuscules, chiffres, _)' }]);
    const item: ContentItem = {
      id: newId(),
      code,
      module: body.module ?? 'common',
      language: body.language ?? 'mg',
      title: requiredString(ctx.body, 'title'),
      body: requiredString(ctx.body, 'body'),
      audio_url: body.audio_url ?? null,
      version: 1,
      status: 'draft',
      author_id: ctx.user.id,
      validator_id: null,
      validated_at: null,
      source_ref: body.source_ref ?? null,
    };
    db.contents.unshift(item);
    return [201, item];
  });
  route('PATCH', '/contents/:id', (ctx) => {
    requireRoles(ctx, CONTENT_ROLES);
    const item = findContent(ctx);
    if (item.status !== 'draft') throw new HttpError(409, 'Seul un brouillon est modifiable');
    const { code: _c, status: _s, author_id: _a, ...rest } = ctx.body;
    Object.assign(item, rest);
    return item;
  });
  route('POST', '/contents/:id/submit', (ctx) => {
    requireRoles(ctx, CONTENT_ROLES);
    const item = findContent(ctx);
    if (item.status !== 'draft') throw new HttpError(409, 'Seul un brouillon peut être soumis');
    item.status = 'in_review';
    return item;
  });
  route('POST', '/contents/:id/validate', (ctx) => {
    requireRoles(ctx, ['clinical_lead']);
    const item = findContent(ctx);
    if (item.status !== 'in_review') throw new HttpError(409, 'Le contenu doit être en revue');
    if (item.author_id === ctx.user.id) throw new HttpError(403, "L'auteur ne peut pas valider son propre contenu");
    item.status = 'validated';
    item.validator_id = ctx.user.id;
    item.validated_at = nowIso();
    audit(ctx, 'content.validate', 'content', item.id);
    return item;
  });
  route('POST', '/contents/:id/retire', (ctx) => {
    requireRoles(ctx, ['clinical_lead']);
    const item = findContent(ctx);
    if (item.status === 'retired') throw new HttpError(409, 'Déjà retiré');
    item.status = 'retired';
    return item;
  });

  // --- Interactions
  route('GET', '/interactions', (ctx) => {
    requireRoles(ctx, ['clinical_advisor', 'clinical_lead']);
    const visible = db.interactions.filter((i) => !i.beneficiary_id || inScope(ctx.user, i.beneficiary_id));
    return paginate(visible, ctx.query);
  });
  route('POST', '/interactions/:id/review', (ctx) => {
    requireRoles(ctx, ['clinical_advisor', 'clinical_lead']);
    const item = db.interactions.find((i) => i.id === ctx.params[0]);
    if (!item) throw new HttpError(404, 'Introuvable');
    item.review_note = requiredString(ctx.body, 'note');
    item.reviewed_at = nowIso();
    item.reviewed_by_user_id = ctx.user.id;
    return item;
  });

  // --- Alertes
  route('GET', '/alerts', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const status = ctx.query.get('status');
    const visible = db.alerts
      .filter((a) => inScope(ctx.user, a.beneficiary_id))
      .filter((a) => !status || a.status === status)
      .map(({ events: _events, ...alert }) => alert);
    return paginate(visible, ctx.query);
  });
  route('GET', '/alerts/:id', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    return findAlert(ctx);
  });
  route('POST', '/alerts/:id/acknowledge', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const alert = findAlert(ctx);
    const allowed =
      ctx.user.id === alert.recipient_user_id || ctx.user.id === alert.backup_user_id || ctx.user.role === 'csb_head';
    if (!allowed) throw new HttpError(403, "Seuls le destinataire, le suppléant ou le chef CSB peuvent acquitter");
    if (alert.status !== 'open' && alert.status !== 'escalated') throw new HttpError(409, 'Alerte déjà traitée');
    alert.status = 'acknowledged';
    alert.acknowledged_at = nowIso();
    alert.acknowledged_by_user_id = ctx.user.id;
    addAlertEvent(alert.id, 'acknowledged', ctx.user.id, null);
    audit(ctx, 'alert.acknowledge', 'alert', alert.id);
    const { events: _e, ...rest } = alert;
    return rest;
  });
  route('POST', '/alerts/:id/resolve', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const alert = findAlert(ctx);
    const note = requiredString(ctx.body, 'note');
    if (alert.status === 'resolved' || alert.status === 'cancelled') throw new HttpError(409, 'Alerte close');
    alert.status = 'resolved';
    alert.resolved_at = nowIso();
    addAlertEvent(alert.id, 'resolved', ctx.user.id, note);
    audit(ctx, 'alert.resolve', 'alert', alert.id);
    const { events: _e, ...rest } = alert;
    return rest;
  });
  route('POST', '/alerts/:id/notes', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const alert = findAlert(ctx);
    const note = requiredString(ctx.body, 'note');
    addAlertEvent(alert.id, 'note', ctx.user.id, note);
    return [201, alert.events[alert.events.length - 1]];
  });

  // --- Références
  route('GET', '/referrals', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const status = ctx.query.get('status');
    const visible = db.referrals.filter((r) => inScope(ctx.user, r.beneficiary_id)).filter((r) => !status || r.status === status);
    return paginate(visible, ctx.query);
  });
  route('GET', '/referrals/:id', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const r = db.referrals.find((x) => x.id === ctx.params[0]);
    if (!r || !inScope(ctx.user, r.beneficiary_id)) throw new HttpError(404, 'Introuvable');
    return r;
  });
  route('POST', '/referrals', (ctx) => {
    requireRoles(ctx, ['community_agent', 'csb_head', 'clinical_advisor']);
    const referral = {
      id: crypto.randomUUID(),
      beneficiary_id: String(ctx.body.beneficiary_id),
      alert_id: (ctx.body.alert_id as string | null) ?? null,
      from_site_id: null,
      to_site_id: String(ctx.body.to_site_id),
      status: 'proposed' as const,
      reason: (ctx.body.reason as string | null) ?? null,
      outcome_note: null,
      version: 1,
      created_at: nowIso(),
      updated_at: nowIso(),
      deleted_at: null,
    };
    db.referrals.push(referral);
    return [201, referral];
  });
  route('POST', '/referrals/:id/transition', (ctx) => {
    requireRoles(ctx, ALERT_ROLES);
    const r = db.referrals.find((x) => x.id === ctx.params[0]);
    if (!r || !inScope(ctx.user, r.beneficiary_id)) throw new HttpError(404, 'Introuvable');
    const body = ctx.body as Partial<ReferralTransition>;
    if (!body.to_status) throw new HttpError(422, [{ loc: ['body', 'to_status'], msg: 'Champ obligatoire' }]);
    const error = validateReferralTransition(r.status, body.to_status, body.reason);
    if (error) throw new HttpError(body.to_status === 'not_completed' && !body.reason?.trim() ? 422 : 409, error);
    r.status = body.to_status;
    if (body.reason !== undefined) r.reason = body.reason;
    if (body.outcome_note !== undefined) r.outcome_note = body.outcome_note;
    r.version += 1;
    r.updated_at = nowIso();
    audit(ctx, 'referral.transition', 'referral', r.id);
    return r;
  });

  // --- Tableau de bord
  route('GET', '/dashboard/summary', (ctx) => {
    requireRoles(ctx, ['csb_head', 'clinical_lead', 'admin', 'data_officer']);
    const siteFilter = ctx.query.get('site_id');
    const scope = scopeSiteIds(ctx.user);
    const keep = (beneficiaryId: string | null) => {
      const site = beneficiarySite(beneficiaryId);
      if (scope && (!site || !scope.has(site))) return false;
      return !siteFilter || site === siteFilter;
    };
    const alerts = db.alerts.filter((a) => keep(a.beneficiary_id));
    const agents = db.users.filter((u) => u.role === 'community_agent');
    const interactions = db.interactions.filter((i) => !i.beneficiary_id || keep(i.beneficiary_id));
    const summary: DashboardSummary = {
      open_alerts: alerts.filter((a) => a.status === 'open' || a.status === 'escalated').length,
      overdue_alerts: alerts.filter((a) => isAlertOverdue(a)).length,
      pending_referrals: db.referrals.filter((r) => keep(r.beneficiary_id) && isPendingReferral(r.status)).length,
      upcoming_anc_7d: 7,
      missed_anc_30d: 2,
      active_agents_30d: agents.filter((u) => u.last_login_at).length,
      total_agents: agents.length,
      active_pregnancies: db.beneficiaries.filter((b) => keep(b.id)).length,
      interactions_30d: interactions.length,
      fallback_rate_30d: interactions.length ? interactions.filter((i) => i.outcome === 'fallback').length / interactions.length : 0,
      generated_at: nowIso(),
    };
    return summary;
  });

  // --- Activité mensuelle et espace agent (données fictives)
  route('GET', '/dashboard/activity', (ctx) => {
    requireRoles(ctx, ['csb_head', 'clinical_lead', 'admin', 'data_officer']);
    const months = ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'];
    return {
      months: months.map((month, i) => ({ month, pregnancies: 4 + i * 2, alerts: 1 + (i % 3), questions: 10 + i * 3, anc_done: 6 + i })),
      sites: db.sites.filter((s) => s.kind === 'csb').map((s, i) => ({ site_id: s.id, name: s.name, code: s.code, region: s.region, active_pregnancies: 12 - i * 3, open_alerts: 2 - (i % 2) })),
      generated_at: nowIso(),
    };
  });
  route('GET', '/followup/patients', (ctx) => {
    requireRoles(ctx, ['community_agent', 'csb_head', 'clinical_advisor', 'clinical_lead']);
    const q = (ctx.query.get('q') ?? '').toLowerCase();
    const items = db.beneficiaries
      .filter((b) => inScope(ctx.user, b.id))
      .map((b, i) => {
        const identity = db.identities.find((x) => x.beneficiary_id === b.id);
        const alert = db.alerts.find((a) => a.beneficiary_id === b.id && (a.status === 'open' || a.status === 'escalated'));
        return {
          beneficiary_id: b.id,
          code: b.code,
          site_id: b.site_id,
          site_name: db.sites.find((s) => s.id === b.site_id)?.name ?? '',
          age: 20 + i,
          display_name: identity?.display_name ?? null,
          village: identity?.village ?? null,
          pregnancy: { id: `p-${b.id}`, month: 3 + (i % 6), lmp_date: null, estimated_due_date: null },
          next_anc: { visit_id: `v-${b.id}`, sequence: 2 + (i % 3), scheduled_date: '2026-11-20', days: 7 + i },
          anc_done: 1 + (i % 3),
          anc_total: 8,
          missed_anc: 0,
          open_alerts: alert ? 1 : 0,
          latest_alert_id: alert?.id ?? null,
          status: alert ? 'a_suivre' : 'a_jour',
          reasons: alert ? ['alerte_ouverte'] : [],
        };
      })
      .filter((p) => !q || (p.display_name ?? '').toLowerCase().includes(q) || p.code.toLowerCase().includes(q));
    return { items, total: items.length };
  });

  // --- Suivi des orientations (fictif)
  route('GET', '/followup/orientations', (ctx) => {
    requireRoles(ctx, ['csb_head', 'clinical_advisor', 'clinical_lead']);
    const item = {
      id: 'or-1', created_at: nowIso(), module: 'reny', channel: 'public_app', question: 'Mandeha ra aho',
      triage: 'urgent', answer: 'Allez au CSB sans attendre.', reviewed_at: nowIso(),
      orientation_site_id: db.sites[1]?.id ?? '', site_name: db.sites[1]?.name ?? '', follow_up_code: 'K7-42',
      follow_up_status: 'expected', follow_up_at: null, follow_up_note: null,
    };
    const code = ctx.query.get('code');
    const items = code && code !== 'K7-42' ? [] : [item];
    return { items, total: items.length, counts: { expected: 1, came: 0, no_show: 0 } };
  });
  route('POST', '/followup/orientations/:id', (ctx) => ({
    id: ctx.params[0], follow_up_status: ctx.body.status, follow_up_code: 'K7-42',
  }));

  // --- Statistiques thématiques (agrégats fictifs)
  route('GET', '/dashboard/topics', (ctx) => {
    requireRoles(ctx, ['csb_head', 'clinical_lead', 'admin', 'data_officer']);
    return {
      period_days: Number(ctx.query.get('days') ?? 30),
      min_cell_size: 5,
      total: 31,
      suppressed_cells: 2,
      suppressed_total: 4,
      items: [
        { module: 'reny', intent: 'ask_anc_schedule', outcome: 'answer', content_code: 'MSG_DEMO_INFO_ANC', count: 14 },
        { module: 'tanora', intent: 'ask_menstruation', outcome: 'answer', content_code: 'MSG_DEMO_INFO_MENSTRUATION', count: 7 },
        { module: 'reny', intent: 'out_of_scope', outcome: 'fallback', content_code: 'MSG_DEMO_TRANSFER_COUNSELOR', count: 6 },
      ],
      generated_at: nowIso(),
    };
  });
  route('GET', '/interop/dhis2/data-value-set', (ctx) => {
    requireRoles(ctx, ['data_officer']);
    const period = ctx.query.get('period') ?? '';
    return {
      dataSet: 'FANILO_MONTHLY',
      period,
      completeDate: nowIso().slice(0, 10),
      generated_at: nowIso(),
      min_cell_size: 5,
      suppressed_values: 1,
      data_elements: { FANILO_QUESTIONS: 'Questions posées' },
      dataValues: [{ dataElement: 'FANILO_QUESTIONS', orgUnit: 'CSB-DEMO-A', period, value: '12' }],
    };
  });

  // --- Simulateur vocal (référentiels et question, réponses fictives)
  const CARE: Role[] = ['community_agent', 'csb_head', 'clinical_advisor', 'clinical_lead'];
  route('GET', '/reference/menus', (ctx) => ({
    config_id: 'mock-information',
    version: '0.1.0',
    is_demo: true,
    module: ctx.query.get('module') ?? 'reny',
    items: [
      { key: 1, code: 'MSG_DEMO_INFO_ANC', title: '[DÉMO] Consultations prénatales', body: '[DÉMO] Demandez votre prochain rendez-vous à votre AC.', audio_url: null, status: 'demo' },
      { key: 2, code: 'MSG_DEMO_INFO_NUTRITION', title: "[DÉMO] Questions sur l'alimentation", body: '[DÉMO] Parlez-en à votre AC ou au CSB.', audio_url: null, status: 'demo' },
    ],
  }));
  route('GET', '/reference/sign-codes', (ctx) => ({
    catalog_id: 'mock-signs',
    version: '0.1.0',
    status: 'demo',
    is_demo: true,
    items: [1, 2, 3].map((n) => ({ code: `SIGN_DEMO_0${n}`, label_fr: `[DÉMO] Signe fictif n° ${n}`, label_mg: null, modules: [ctx.query.get('module') ?? 'reny'] })),
  }));
  route('POST', '/interactions/ask', (ctx) => {
    requireRoles(ctx, CARE);
    const signs = Array.isArray(ctx.body.sign_codes) ? (ctx.body.sign_codes as string[]) : [];
    const danger = signs.includes('SIGN_DEMO_01');
    return {
      interaction_id: crypto.randomUUID(),
      transcript: typeof ctx.body.text === 'string' ? ctx.body.text : null,
      transcript_needs_review: false,
      outcome: danger ? 'danger_sign' : 'fallback',
      actions: danger ? ['refer_reference_facility'] : ['transfer_counselor'],
      severity: danger ? 'critical' : null,
      content: { code: 'MSG_DEMO_TRANSFER_COUNSELOR', title: '[DÉMO] Question transmise à un conseiller', body: '[DÉMO] Votre question est transmise à un conseiller.', audio_url: null, status: 'demo' },
      alert_id: danger ? crypto.randomUUID() : null,
      is_demo: true,
      disclaimer: 'FANILO ne remplace pas un professionnel de santé.',
    };
  });

  // --- Audit
  route('GET', '/audit', (ctx) => {
    requireRoles(ctx, ['data_officer']);
    const q = ctx.query;
    const from = q.get('from');
    const to = q.get('to');
    const items = db.audit.filter(
      (e) =>
        (!q.get('entity_type') || e.entity_type === q.get('entity_type')) &&
        (!q.get('actor_user_id') || e.actor_user_id === q.get('actor_user_id')) &&
        (!from || e.at >= from) &&
        (!to || e.at <= to),
    );
    return paginate(items, q);
  });

  async function handle(input: string, init: RequestInit = {}): Promise<Response> {
    if (latency) await new Promise((r) => setTimeout(r, latency));
    const url = new URL(input);
    const method = (init.method ?? 'GET').toUpperCase();
    const path = url.pathname;
    calls.push({ method, path });
    const body = typeof init.body === 'string' && init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {};

    // Endpoints publics
    if (method === 'POST' && path === '/auth/login') {
      const user = db.users.find((u) => u.login === body.login && u.password === body.password && u.is_active);
      if (!user) return json(401, { detail: 'Identifiants invalides' });
      user.last_login_at = nowIso();
      return json(200, issueTokens(user));
    }
    if (method === 'POST' && path === '/auth/refresh') {
      const userId = refreshTokens.get(String(body.refresh_token));
      const user = db.users.find((u) => u.id === userId && u.is_active);
      if (!user) return json(401, { detail: 'Jeton de rafraîchissement invalide' });
      refreshTokens.delete(String(body.refresh_token)); // rotation
      return json(200, issueTokens(user));
    }
    if (method === 'POST' && path === '/auth/logout') {
      refreshTokens.delete(String(body.refresh_token));
      return json(204, null);
    }

    const headers = new Headers(init.headers);
    const token = headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
    const user = db.users.find((u) => u.id === accessTokens.get(token) && u.is_active);
    if (!user) return json(401, { detail: 'Non authentifié' });

    for (const [m, regex, handler] of routes) {
      if (m !== method) continue;
      const match = regex.exec(path);
      if (!match) continue;
      try {
        const result = handler({ user, body, query: url.searchParams, params: match.slice(1).map(decodeURIComponent) });
        if (Array.isArray(result) && typeof result[0] === 'number' && result.length === 2) {
          return json(result[0], result[1]);
        }
        return json(200, result);
      } catch (error) {
        if (error instanceof HttpError) return json(error.status, { detail: error.detail });
        throw error;
      }
    }
    return json(404, { detail: 'Not Found' });
  }

  return {
    fetch: handle,
    db,
    calls,
    expireAccessTokens: () => accessTokens.clear(),
  };
}
