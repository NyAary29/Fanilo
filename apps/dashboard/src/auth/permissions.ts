/**
 * Droits d'accès CÔTÉ CLIENT.
 *
 * ⚠️ RAPPEL : ce contrôle est purement ERGONOMIQUE (masquer les écrans et boutons
 * inutiles). Il ne protège rien : la seule autorité est l'API, qui applique le rôle,
 * le périmètre de site et l'accès aux données nominatives, et renvoie 403/404.
 * Ne jamais s'appuyer sur ce fichier pour la sécurité.
 */
import type { Alert, ContentItem, ContentStatus, Me, Role } from '../api/types';

/** Miroir de NOMINATIVE_DATA_ROLES (services/api/app/modules/users/roles.py). */
export const NOMINATIVE_DATA_ROLES: ReadonlySet<Role> = new Set<Role>([
  'community_agent',
  'clinical_advisor',
  'csb_head',
  'clinical_lead',
]);

export const ROLE_LABELS: Readonly<Record<Role, string>> = {
  community_agent: 'Agent communautaire',
  clinical_advisor: 'Conseiller clinique',
  csb_head: 'Chef CSB',
  clinical_lead: 'Responsable clinique',
  admin: 'Administrateur',
  data_officer: 'Responsable données',
  technical: 'Équipe technique',
};

export type Section = 'dashboard' | 'alerts' | 'referrals' | 'contents' | 'users' | 'sites' | 'interactions' | 'audit';

/** Rôles autorisés par écran (dérivés du contrat ; voir README pour les hypothèses). */
export const SECTION_ROLES: Readonly<Record<Section, readonly Role[]>> = {
  dashboard: ['csb_head', 'clinical_lead', 'admin', 'data_officer'],
  alerts: ['csb_head', 'clinical_advisor', 'clinical_lead'],
  referrals: ['csb_head', 'clinical_advisor', 'clinical_lead'],
  contents: ['clinical_lead', 'admin'],
  users: ['admin'],
  sites: ['admin'],
  interactions: ['clinical_advisor', 'clinical_lead'],
  audit: ['data_officer'],
};

export const SECTION_PATHS: Readonly<Record<Section, string>> = {
  dashboard: '/tableau-de-bord',
  alerts: '/alertes',
  referrals: '/references',
  contents: '/contenus',
  users: '/utilisateurs',
  sites: '/sites',
  interactions: '/questions',
  audit: '/audit',
};

export const SECTION_LABELS: Readonly<Record<Section, string>> = {
  dashboard: 'Tableau de bord',
  alerts: 'Alertes',
  referrals: 'Références',
  contents: 'Contenus',
  users: 'Utilisateurs',
  sites: 'Sites',
  interactions: 'Questions à revoir',
  audit: "Journal d'audit",
};

export const SECTION_ORDER: readonly Section[] = [
  'dashboard',
  'alerts',
  'referrals',
  'interactions',
  'contents',
  'users',
  'sites',
  'audit',
];

export function hasRole(user: Pick<Me, 'role'> | null | undefined, roles: readonly Role[]): boolean {
  return !!user && roles.includes(user.role);
}

export function canAccess(user: Pick<Me, 'role'> | null | undefined, section: Section): boolean {
  return hasRole(user, SECTION_ROLES[section]);
}

export function sectionsFor(user: Pick<Me, 'role'> | null | undefined): Section[] {
  return SECTION_ORDER.filter((s) => canAccess(user, s));
}

export function homePathFor(user: Pick<Me, 'role'> | null | undefined): string {
  const first = sectionsFor(user)[0];
  return first ? SECTION_PATHS[first] : '/accueil';
}

/** Les rôles admin, data_officer et technical ne voient JAMAIS de champ nominatif. */
export function canSeeNominativeData(user: Pick<Me, 'role'> | null | undefined): boolean {
  return !!user && NOMINATIVE_DATA_ROLES.has(user.role);
}

/** Vue globale (sélecteur de site sur le tableau de bord). */
export function hasGlobalView(user: Pick<Me, 'role'> | null | undefined): boolean {
  return hasRole(user, ['admin', 'clinical_lead', 'data_officer']);
}

// --- Alertes -----------------------------------------------------------------

/** Contrat : destinataire, suppléant, ou `csb_head` du site (le site est vérifié par le serveur). */
export function canAcknowledgeAlert(user: Me | null, alert: Pick<Alert, 'recipient_user_id' | 'backup_user_id' | 'status'>): boolean {
  if (!user) return false;
  if (alert.status !== 'open' && alert.status !== 'escalated') return false;
  return user.id === alert.recipient_user_id || user.id === alert.backup_user_id || user.role === 'csb_head';
}

// --- Contenus ----------------------------------------------------------------

export const CONTENT_STATUS_LABELS: Readonly<Record<ContentStatus, string>> = {
  draft: 'Brouillon',
  in_review: 'En revue',
  validated: 'Validé',
  retired: 'Retiré',
  demo: 'Démo',
};

const CONTENT_MANAGERS: readonly Role[] = ['clinical_lead', 'admin'];

export function canManageContents(user: Pick<Me, 'role'> | null | undefined): boolean {
  return hasRole(user, CONTENT_MANAGERS);
}

export function canEditContent(user: Me | null, item: Pick<ContentItem, 'status'>): boolean {
  return canManageContents(user) && item.status === 'draft';
}

export function canSubmitContent(user: Me | null, item: Pick<ContentItem, 'status'>): boolean {
  return canManageContents(user) && item.status === 'draft';
}

/** `clinical_lead` uniquement, et jamais sur son propre contenu. */
export function canValidateContent(user: Me | null, item: Pick<ContentItem, 'status' | 'author_id'>): boolean {
  return !!user && user.role === 'clinical_lead' && item.status === 'in_review' && item.author_id !== user.id;
}

/** `clinical_lead` uniquement (contrat §5). */
export function canRetireContent(user: Me | null, item: Pick<ContentItem, 'status'>): boolean {
  return !!user && user.role === 'clinical_lead' && (item.status === 'validated' || item.status === 'demo');
}
