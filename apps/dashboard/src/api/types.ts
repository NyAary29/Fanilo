/**
 * Types de l'API FANILO, écrits à la main à partir de docs/api-contrat.md (v0.1).
 *
 * C'est le SEUL endroit où ces types sont déclarés : toute divergence avec le contrat
 * se corrige d'abord dans le contrat, puis ici.
 *
 * Conventions : `snake_case`, `IsoDate` = "YYYY-MM-DD", `IsoDateTime` = UTC avec fuseau.
 */

export type Uuid = string;
export type IsoDate = string;
export type IsoDateTime = string;

/** Réponse paginée standard : `?limit=50&offset=0` → `{items, total}`. */
export interface Page<T> {
  items: T[];
  total: number;
}

export interface PageParams {
  limit?: number;
  offset?: number;
}

// --- 1. Authentification ---------------------------------------------------

export const ROLES = [
  'community_agent',
  'clinical_advisor',
  'csb_head',
  'clinical_lead',
  'admin',
  'data_officer',
  'technical',
] as const;
export type Role = (typeof ROLES)[number];

export interface LoginRequest {
  login: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  refresh_expires_in: number;
}

export interface Me {
  id: Uuid;
  login: string;
  role: Role;
  site_id: Uuid | null;
  is_active: boolean;
}

// --- 2. Sites et utilisateurs ----------------------------------------------

export const SITE_KINDS = ['csb', 'reference_facility', 'community_zone'] as const;
export type SiteKind = (typeof SITE_KINDS)[number];

export interface Site {
  id: Uuid;
  name: string;
  kind: SiteKind;
  code: string;
  district: string;
  region: string;
  parent_site_id: Uuid | null;
  is_active: boolean;
}

export type SiteCreate = Omit<Site, 'id'>;
export type SiteUpdate = Partial<SiteCreate>;

export interface User {
  id: Uuid;
  login: string;
  role: Role;
  site_id: Uuid | null;
  is_active: boolean;
  last_login_at: IsoDateTime | null;
}

export interface UserCreate {
  login: string;
  password: string;
  role: Role;
  site_id: Uuid | null;
}

export interface UserUpdate {
  role?: Role;
  site_id?: Uuid | null;
  is_active?: boolean;
}

// --- 3. Bénéficiaires (lecture minimale utile au dashboard) -----------------

export interface SyncFields {
  version: number;
  created_at: IsoDateTime;
  updated_at: IsoDateTime;
  deleted_at: IsoDateTime | null;
}

export interface Beneficiary extends SyncFields {
  id: Uuid;
  /** Code pseudonyme, ex. "FAN-000123". Ce n'est pas une donnée nominative. */
  code: string;
  site_id: Uuid;
  birth_year: number | null;
  preferred_channel: 'sms' | 'ivr' | 'ac_visit' | 'none';
}

/** Données nominatives : réservées à NOMINATIVE_DATA_ROLES (chaque lecture est auditée). */
export interface BeneficiaryIdentity {
  beneficiary_id: Uuid;
  display_name: string;
  phone: string | null;
  village: string | null;
}

// --- 5. Contenus ------------------------------------------------------------

export const CONTENT_STATUSES = ['draft', 'in_review', 'validated', 'retired', 'demo'] as const;
export type ContentStatus = (typeof CONTENT_STATUSES)[number];
export const CONTENT_MODULES = ['reny', 'tanora', 'common'] as const;
export type ContentModule = (typeof CONTENT_MODULES)[number];
export const CONTENT_LANGUAGES = ['mg', 'fr'] as const;
export type ContentLanguage = (typeof CONTENT_LANGUAGES)[number];

export interface ContentItem {
  id: Uuid;
  code: string;
  module: ContentModule;
  language: ContentLanguage;
  title: string;
  body: string;
  audio_url: string | null;
  version: number;
  status: ContentStatus;
  author_id: Uuid;
  validator_id: Uuid | null;
  validated_at: IsoDateTime | null;
  source_ref: string | null;
}

export interface ContentCreate {
  code: string;
  module: ContentModule;
  language: ContentLanguage;
  title: string;
  body: string;
  audio_url: string | null;
  source_ref: string | null;
}

export type ContentUpdate = Partial<ContentCreate>;

// --- 6. Interactions --------------------------------------------------------

export type InteractionOutcome = 'answer' | 'danger_sign' | 'fallback';
export type Severity = 'critical' | 'urgent' | 'routine';

/**
 * HYPOTHÈSE : le contrat (§6) ne décrit pas le schéma renvoyé par `GET /interactions`
 * ni le corps de `POST /interactions/{id}/review`. Les champs ci-dessous reprennent
 * ceux de la réponse de `/interactions/ask` ; ils seront alignés dès que le contrat
 * sera précisé (voir README, « Limites »).
 */
export interface Interaction {
  id: Uuid;
  module: ContentModule;
  beneficiary_id: Uuid | null;
  transcript: string | null;
  transcript_needs_review: boolean;
  outcome: InteractionOutcome;
  severity: Severity | null;
  actions: string[];
  alert_id: Uuid | null;
  is_demo: boolean;
  created_at: IsoDateTime;
  reviewed_at: IsoDateTime | null;
  reviewed_by_user_id: Uuid | null;
  review_note: string | null;
}

export interface InteractionReview {
  note: string;
}

// --- 7. Alertes et références ----------------------------------------------

export const ALERT_STATUSES = ['open', 'acknowledged', 'resolved', 'escalated', 'cancelled'] as const;
export type AlertStatus = (typeof ALERT_STATUSES)[number];

export interface Alert {
  id: Uuid;
  beneficiary_id: Uuid;
  interaction_id: Uuid | null;
  rule_id: string;
  ruleset_version: string;
  severity: Severity;
  status: AlertStatus;
  recipient_user_id: Uuid;
  backup_user_id: Uuid | null;
  due_at: IsoDateTime;
  acknowledged_at: IsoDateTime | null;
  acknowledged_by_user_id: Uuid | null;
  resolved_at: IsoDateTime | null;
  is_demo: boolean;
  created_at: IsoDateTime;
}

export type AlertEventType = 'created' | 'acknowledged' | 'escalated' | 'note' | 'resolved' | 'cancelled';

export interface AlertEvent {
  id: Uuid;
  alert_id: Uuid;
  at: IsoDateTime;
  actor_user_id: Uuid | null;
  type: AlertEventType;
  note: string | null;
}

export interface AlertDetail extends Alert {
  events: AlertEvent[];
}

export const REFERRAL_STATUSES = ['proposed', 'accepted', 'arrived', 'transferred', 'not_completed'] as const;
export type ReferralStatus = (typeof REFERRAL_STATUSES)[number];

export interface Referral extends SyncFields {
  id: Uuid;
  beneficiary_id: Uuid;
  alert_id: Uuid | null;
  from_site_id: Uuid | null;
  to_site_id: Uuid;
  status: ReferralStatus;
  reason: string | null;
  outcome_note: string | null;
}

export interface ReferralTransition {
  to_status: ReferralStatus;
  reason?: string;
  outcome_note?: string;
}

// --- 9. Tableau de bord -----------------------------------------------------

export interface DashboardSummary {
  open_alerts: number;
  overdue_alerts: number;
  pending_referrals: number;
  upcoming_anc_7d: number;
  missed_anc_30d: number;
  active_agents_30d: number;
  total_agents: number;
  active_pregnancies: number;
  interactions_30d: number;
  fallback_rate_30d: number;
  generated_at: IsoDateTime;
}

// --- 10. Audit --------------------------------------------------------------

export interface AuditEvent {
  id: Uuid;
  at: IsoDateTime;
  actor_user_id: Uuid;
  actor_role: Role;
  action: string;
  entity_type: string;
  entity_id: Uuid;
  request_id: string;
  site_id: Uuid | null;
}

export interface AuditFilters extends PageParams {
  entity_type?: string;
  actor_user_id?: string;
  from?: string;
  to?: string;
}
