import type { ApiClient } from './client';
import type {
  FollowUpStatus,
  OrientationItem,
  OrientationList,
  Activity,
  Patient,
  Alert,
  AlertDetail,
  AlertStatus,
  AuditEvent,
  AskJson,
  AskModule,
  AskLanguage,
  AskResponse,
  AuditFilters,
  Beneficiary,
  BeneficiaryIdentity,
  ContentCreate,
  ContentItem,
  ContentStatus,
  ContentUpdate,
  DashboardSummary,
  DataValueSet,
  Interaction,
  InteractionReview,
  Page,
  PageParams,
  Referral,
  ReferralStatus,
  ReferralTransition,
  Site,
  SiteCreate,
  SiteUpdate,
  SignCodes,
  TopicStats,
  User,
  UserCreate,
  UserUpdate,
  Uuid,
  VoiceMenu,
} from './types';

const enc = encodeURIComponent;

/** Fonctions typées, une par endpoint du contrat utilisé par le dashboard. */
export function createEndpoints(client: ApiClient) {
  return {
    // §2 Sites et utilisateurs
    listSites: (params: PageParams = { limit: 200 }) => client.get<Page<Site>>('/sites', { ...params }),
    createSite: (body: SiteCreate) => client.post<Site>('/sites', body),
    updateSite: (id: Uuid, body: SiteUpdate) => client.patch<Site>(`/sites/${enc(id)}`, body),
    listUsers: (params: PageParams = {}) => client.get<Page<User>>('/users', { ...params }),
    createUser: (body: UserCreate) => client.post<User>('/users', body),
    updateUser: (id: Uuid, body: UserUpdate) => client.patch<User>(`/users/${enc(id)}`, body),

    // §3 Bénéficiaires (lecture minimale)
    getBeneficiary: (id: Uuid) => client.get<Beneficiary>(`/beneficiaries/${enc(id)}`),
    /** Rôles nominatifs uniquement ; chaque lecture est tracée dans l'audit. */
    getBeneficiaryIdentity: (id: Uuid) => client.get<BeneficiaryIdentity>(`/beneficiaries/${enc(id)}/identity`),

    // §5 Contenus
    // NB : le filtre `status` n'est pas listé par le contrat pour GET /contents (voir README).
    listContents: (params: PageParams & { status?: ContentStatus } = {}) =>
      client.get<Page<ContentItem>>('/contents', { ...params }),
    createContent: (body: ContentCreate) => client.post<ContentItem>('/contents', body),
    updateContent: (id: Uuid, body: ContentUpdate) => client.patch<ContentItem>(`/contents/${enc(id)}`, body),
    submitContent: (id: Uuid) => client.post<ContentItem>(`/contents/${enc(id)}/submit`),
    validateContent: (id: Uuid) => client.post<ContentItem>(`/contents/${enc(id)}/validate`),
    retireContent: (id: Uuid) => client.post<ContentItem>(`/contents/${enc(id)}/retire`),

    // §6 Interactions
    listInteractions: (params: PageParams & { review_status?: 'pending' | 'reviewed' | 'not_required' } = {}) => client.get<Page<Interaction>>('/interactions', { ...params }),
    reviewInteraction: (id: Uuid, body: InteractionReview) =>
      client.post<Interaction>(`/interactions/${enc(id)}/review`, body),
    ask: (body: AskJson) => client.post<AskResponse>('/interactions/ask', body),
    /** Forme audio : multipart, l'audio est relayé en mémoire et jamais stocké. */
    askAudio: (audio: Blob, module: AskModule) => {
      const form = new FormData();
      form.append('audio', audio, 'question.webm');
      form.append('module', module);
      return client.post<AskResponse>('/interactions/ask', form);
    },

    // §8 bis Référentiels
    getSignCodes: (module: AskModule) => client.get<SignCodes>('/reference/sign-codes', { module }),
    getVoiceMenu: (module: AskModule, language: AskLanguage = 'mg') =>
      client.get<VoiceMenu>('/reference/menus', { module, language }),

    // §7 Alertes
    listAlerts: (params: PageParams & { status?: AlertStatus; sort?: 'due' | 'recent' } = {}) =>
      client.get<Page<Alert>>('/alerts', { ...params }),
    getAlert: (id: Uuid) => client.get<AlertDetail>(`/alerts/${enc(id)}`),
    acknowledgeAlert: (id: Uuid) => client.post<Alert>(`/alerts/${enc(id)}/acknowledge`),
    resolveAlert: (id: Uuid, note: string) => client.post<Alert>(`/alerts/${enc(id)}/resolve`, { note }),
    addAlertNote: (id: Uuid, note: string) => client.post<unknown>(`/alerts/${enc(id)}/notes`, { note }),

    // §7 Références
    // NB : le filtre `status` n'est pas listé par le contrat pour GET /referrals (voir README).
    listReferrals: (params: PageParams & { status?: ReferralStatus } = {}) =>
      client.get<Page<Referral>>('/referrals', { ...params }),
    getReferral: (id: Uuid) => client.get<Referral>(`/referrals/${enc(id)}`),
    createReferral: (body: { beneficiary_id: Uuid; to_site_id: Uuid; alert_id?: Uuid | null; reason?: string | null }) =>
      client.post<Referral>('/referrals', body),
    transitionReferral: (id: Uuid, body: ReferralTransition) =>
      client.post<Referral>(`/referrals/${enc(id)}/transition`, body),

    // §9 Tableau de bord
    getDashboardSummary: (siteId?: Uuid | null) =>
      client.get<DashboardSummary>('/dashboard/summary', { site_id: siteId ?? undefined }),

    getActivity: (months = 6, siteId?: Uuid | null) =>
      client.get<Activity>('/dashboard/activity', { months, site_id: siteId ?? undefined }),
    /** Liste de travail nominative : chaque identité renvoyée est tracée dans l'audit. */
    listPatients: (q?: string) => client.get<{ items: Patient[]; total: number }>('/followup/patients', { q }),
    listOrientations: (params: { status?: FollowUpStatus; code?: string } = {}) =>
      client.get<OrientationList>('/followup/orientations', { ...params }),
    updateOrientation: (id: Uuid, body: { status: 'came' | 'no_show'; note?: string | null }) =>
      client.post<OrientationItem>(`/followup/orientations/${enc(id)}`, body),
    getTopicStats: (days: number, siteId?: Uuid | null) =>
      client.get<TopicStats>('/dashboard/topics', { days, site_id: siteId ?? undefined }),
    exportDhis2: (period: string, includeSmallCells = false) =>
      client.get<DataValueSet>('/interop/dhis2/data-value-set', {
        period,
        include_small_cells: includeSmallCells || undefined,
      }),

    // §10 Audit
    listAudit: (filters: AuditFilters = {}) => client.get<Page<AuditEvent>>('/audit', { ...filters }),
  };
}

export type Endpoints = ReturnType<typeof createEndpoints>;
