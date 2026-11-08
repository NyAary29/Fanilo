/**
 * Données FICTIVES pour le mode mock. Aucun nom, téléphone ni lieu réel :
 * toute ressemblance serait fortuite. Ne jamais copier ces données en production.
 */
import type {
  AlertDetail,
  AuditEvent,
  Beneficiary,
  BeneficiaryIdentity,
  ContentItem,
  Interaction,
  Referral,
  Role,
  Site,
  User,
} from '../types';

export const MOCK_PASSWORD = 'demo';

export interface MockUser extends User {
  password: string;
}

export interface MockDb {
  sites: Site[];
  users: MockUser[];
  beneficiaries: Beneficiary[];
  identities: BeneficiaryIdentity[];
  alerts: AlertDetail[];
  referrals: Referral[];
  contents: ContentItem[];
  interactions: Interaction[];
  audit: AuditEvent[];
}

const id = (prefix: string, n: number) => `${prefix}-0000-4000-8000-${String(n).padStart(12, '0')}`;

export const SITE_IDS = {
  district: id('5ad00000', 1),
  csbA: id('5ad00000', 2),
  csbB: id('5ad00000', 3),
  zone: id('5ad00000', 4),
};

export const USER_IDS: Record<string, string> = {
  agent: id('a5e00000', 1),
  conseiller: id('a5e00000', 2),
  chefcsb: id('a5e00000', 3),
  chefcsb2: id('a5e00000', 4),
  responsable: id('a5e00000', 5),
  responsable2: id('a5e00000', 6),
  admin: id('a5e00000', 7),
  donnees: id('a5e00000', 8),
  technique: id('a5e00000', 9),
};

function user(login: string, role: Role, siteId: string | null, lastLogin: string | null = null): MockUser {
  const userId = USER_IDS[login.replace('.', '')];
  if (!userId) throw new Error(`id inconnu pour ${login}`);
  return {
    id: userId,
    login,
    role,
    site_id: siteId,
    is_active: true,
    last_login_at: lastLogin,
    password: MOCK_PASSWORD,
  };
}

function iso(base: number, minutesOffset: number): string {
  return new Date(base + minutesOffset * 60_000).toISOString();
}

const sync = (createdAt: string) => ({ version: 1, created_at: createdAt, updated_at: createdAt, deleted_at: null });

/** Crée un jeu de données neuf (chaque test obtient le sien). */
export function createMockDb(now: Date = new Date()): MockDb {
  const t = now.getTime();

  const sites: Site[] = [
    { id: SITE_IDS.district, name: 'Centre de référence fictif', kind: 'reference_facility', code: 'REF-DEMO', district: 'District Démo', region: 'Région Démo', parent_site_id: null, is_active: true },
    { id: SITE_IDS.csbA, name: 'CSB Démo A', kind: 'csb', code: 'CSB-DEMO-A', district: 'District Démo', region: 'Région Démo', parent_site_id: SITE_IDS.district, is_active: true },
    { id: SITE_IDS.csbB, name: 'CSB Démo B', kind: 'csb', code: 'CSB-DEMO-B', district: 'District Démo', region: 'Région Démo', parent_site_id: SITE_IDS.district, is_active: true },
    { id: SITE_IDS.zone, name: 'Zone communautaire Démo A1', kind: 'community_zone', code: 'ZC-DEMO-A1', district: 'District Démo', region: 'Région Démo', parent_site_id: SITE_IDS.csbA, is_active: true },
  ];

  const users: MockUser[] = [
    user('agent', 'community_agent', SITE_IDS.zone, iso(t, -60 * 24)),
    user('conseiller', 'clinical_advisor', SITE_IDS.csbA, iso(t, -120)),
    user('chef.csb', 'csb_head', SITE_IDS.csbA, iso(t, -30)),
    user('chef.csb2', 'csb_head', SITE_IDS.csbB),
    user('responsable', 'clinical_lead', null, iso(t, -300)),
    user('responsable2', 'clinical_lead', null),
    user('admin', 'admin', null, iso(t, -10)),
    user('donnees', 'data_officer', null),
    user('technique', 'technical', null),
  ];

  const beneficiaries: Beneficiary[] = [1, 2, 3, 4, 5].map((n) => ({
    id: id('be0e0000', n),
    code: `FAN-DEMO0${n}`,
    site_id: n <= 4 ? SITE_IDS.csbA : SITE_IDS.csbB,
    birth_year: 1995 + n,
    preferred_channel: n % 2 ? 'sms' : 'ac_visit',
    ...sync(iso(t, -60 * 24 * 30)),
  }));

  const identities: BeneficiaryIdentity[] = beneficiaries.map((b, i) => ({
    beneficiary_id: b.id,
    display_name: `Personne fictive ${i + 1}`,
    phone: null,
    village: 'Village fictif',
  }));

  const ben = (n: number) => id('be0e0000', n);
  const U = USER_IDS as Record<string, string>;
  const alerts: AlertDetail[] = [
    {
      id: id('a1e00000', 1), beneficiary_id: ben(1), interaction_id: id('1e700000', 1), rule_id: 'DEMO_R01', ruleset_version: 'demo-0.1',
      severity: 'critical', status: 'open', recipient_user_id: U.chefcsb!, backup_user_id: U.conseiller!, due_at: iso(t, -45),
      acknowledged_at: null, acknowledged_by_user_id: null, resolved_at: null, is_demo: true, created_at: iso(t, -75),
      events: [{ id: id('e0e00000', 1), alert_id: id('a1e00000', 1), at: iso(t, -75), actor_user_id: null, type: 'created', note: null }],
    },
    {
      id: id('a1e00000', 2), beneficiary_id: ben(2), interaction_id: null, rule_id: 'DEMO_R02', ruleset_version: 'demo-0.1',
      severity: 'urgent', status: 'open', recipient_user_id: U.chefcsb!, backup_user_id: U.conseiller!, due_at: iso(t, 90),
      acknowledged_at: null, acknowledged_by_user_id: null, resolved_at: null, is_demo: true, created_at: iso(t, -30),
      events: [{ id: id('e0e00000', 2), alert_id: id('a1e00000', 2), at: iso(t, -30), actor_user_id: null, type: 'created', note: null }],
    },
    {
      id: id('a1e00000', 3), beneficiary_id: ben(3), interaction_id: null, rule_id: 'DEMO_R01', ruleset_version: 'demo-0.1',
      severity: 'critical', status: 'acknowledged', recipient_user_id: U.chefcsb!, backup_user_id: U.conseiller!, due_at: iso(t, -200),
      acknowledged_at: iso(t, -230), acknowledged_by_user_id: U.chefcsb!, resolved_at: null, is_demo: true, created_at: iso(t, -260),
      events: [
        { id: id('e0e00000', 3), alert_id: id('a1e00000', 3), at: iso(t, -260), actor_user_id: null, type: 'created', note: null },
        { id: id('e0e00000', 4), alert_id: id('a1e00000', 3), at: iso(t, -230), actor_user_id: U.chefcsb!, type: 'acknowledged', note: null },
        { id: id('e0e00000', 5), alert_id: id('a1e00000', 3), at: iso(t, -220), actor_user_id: U.chefcsb!, type: 'note', note: 'Agent communautaire contacté (note fictive).' },
      ],
    },
    {
      id: id('a1e00000', 4), beneficiary_id: ben(4), interaction_id: null, rule_id: 'DEMO_R03', ruleset_version: 'demo-0.1',
      severity: 'urgent', status: 'escalated', recipient_user_id: U.conseiller!, backup_user_id: null, due_at: iso(t, -600),
      acknowledged_at: null, acknowledged_by_user_id: null, resolved_at: null, is_demo: true, created_at: iso(t, -700),
      events: [
        { id: id('e0e00000', 6), alert_id: id('a1e00000', 4), at: iso(t, -700), actor_user_id: null, type: 'created', note: null },
        { id: id('e0e00000', 7), alert_id: id('a1e00000', 4), at: iso(t, -595), actor_user_id: null, type: 'escalated', note: 'Non acquittée dans le délai : réassignée au suppléant.' },
      ],
    },
    {
      id: id('a1e00000', 5), beneficiary_id: ben(1), interaction_id: null, rule_id: 'R-VALID-EXEMPLE', ruleset_version: '1.0.0',
      severity: 'routine', status: 'resolved', recipient_user_id: U.chefcsb!, backup_user_id: null, due_at: iso(t, -60 * 24 * 2),
      acknowledged_at: iso(t, -60 * 24 * 3), acknowledged_by_user_id: U.chefcsb!, resolved_at: iso(t, -60 * 24 * 2 - 30), is_demo: false, created_at: iso(t, -60 * 24 * 3 - 20),
      events: [
        { id: id('e0e00000', 8), alert_id: id('a1e00000', 5), at: iso(t, -60 * 24 * 3 - 20), actor_user_id: null, type: 'created', note: null },
        { id: id('e0e00000', 9), alert_id: id('a1e00000', 5), at: iso(t, -60 * 24 * 3), actor_user_id: U.chefcsb!, type: 'acknowledged', note: null },
        { id: id('e0e00000', 10), alert_id: id('a1e00000', 5), at: iso(t, -60 * 24 * 2 - 30), actor_user_id: U.chefcsb!, type: 'resolved', note: 'Orientation effectuée (note fictive).' },
      ],
    },
    {
      id: id('a1e00000', 6), beneficiary_id: ben(5), interaction_id: null, rule_id: 'DEMO_R02', ruleset_version: 'demo-0.1',
      severity: 'urgent', status: 'open', recipient_user_id: U.chefcsb2!, backup_user_id: null, due_at: iso(t, 120),
      acknowledged_at: null, acknowledged_by_user_id: null, resolved_at: null, is_demo: true, created_at: iso(t, -10),
      events: [{ id: id('e0e00000', 11), alert_id: id('a1e00000', 6), at: iso(t, -10), actor_user_id: null, type: 'created', note: null }],
    },
  ];

  const referrals: Referral[] = [
    { id: id('4ef00000', 1), beneficiary_id: ben(1), alert_id: id('a1e00000', 1), from_site_id: SITE_IDS.csbA, to_site_id: SITE_IDS.district, status: 'proposed', reason: null, outcome_note: null, ...sync(iso(t, -70)) },
    { id: id('4ef00000', 2), beneficiary_id: ben(3), alert_id: id('a1e00000', 3), from_site_id: SITE_IDS.csbA, to_site_id: SITE_IDS.district, status: 'accepted', reason: null, outcome_note: null, ...sync(iso(t, -225)) },
    { id: id('4ef00000', 3), beneficiary_id: ben(2), alert_id: null, from_site_id: SITE_IDS.zone, to_site_id: SITE_IDS.csbA, status: 'transferred', reason: null, outcome_note: null, ...sync(iso(t, -60 * 24)) },
    { id: id('4ef00000', 4), beneficiary_id: ben(4), alert_id: null, from_site_id: SITE_IDS.csbA, to_site_id: SITE_IDS.district, status: 'arrived', reason: null, outcome_note: 'Arrivée confirmée (note fictive).', ...sync(iso(t, -60 * 24 * 4)) },
    { id: id('4ef00000', 5), beneficiary_id: ben(1), alert_id: null, from_site_id: SITE_IDS.csbA, to_site_id: SITE_IDS.district, status: 'not_completed', reason: 'Transport indisponible (motif fictif).', outcome_note: null, ...sync(iso(t, -60 * 24 * 10)) },
  ];

  const contents: ContentItem[] = [
    { id: id('c0e00000', 1), code: 'MSG_DEMO_CPN_RAPPEL', module: 'reny', language: 'mg', title: 'Rappel CPN (démo)', body: 'Texte de démonstration, non validé cliniquement.', audio_url: null, version: 1, status: 'demo', author_id: U.responsable!, validator_id: null, validated_at: null, source_ref: null },
    { id: id('c0e00000', 2), code: 'MSG_DEMO_ORIENTATION_CSB', module: 'reny', language: 'fr', title: 'Orientation vers le CSB (brouillon)', body: 'Brouillon fictif : se rendre au CSB le plus proche.', audio_url: null, version: 1, status: 'draft', author_id: U.admin!, validator_id: null, validated_at: null, source_ref: 'Protocole fictif v0' },
    { id: id('c0e00000', 3), code: 'MSG_DEMO_HYGIENE', module: 'common', language: 'fr', title: 'Hygiène (en revue, rédigé par responsable2)', body: 'Contenu fictif soumis à validation.', audio_url: null, version: 1, status: 'in_review', author_id: U.responsable2!, validator_id: null, validated_at: null, source_ref: null },
    { id: id('c0e00000', 4), code: 'MSG_DEMO_SOMMEIL', module: 'tanora', language: 'mg', title: 'Sommeil (en revue, rédigé par responsable)', body: 'Contenu fictif soumis à validation.', audio_url: null, version: 1, status: 'in_review', author_id: U.responsable!, validator_id: null, validated_at: null, source_ref: null },
    { id: id('c0e00000', 5), code: 'MSG_DEMO_EAU', module: 'common', language: 'fr', title: 'Eau potable (validé, fictif)', body: 'Contenu fictif marqué validé pour la démonstration.', audio_url: null, version: 2, status: 'validated', author_id: U.responsable2!, validator_id: U.responsable!, validated_at: iso(t, -60 * 24 * 7), source_ref: 'Source fictive' },
    { id: id('c0e00000', 6), code: 'MSG_DEMO_ANCIEN', module: 'reny', language: 'fr', title: 'Ancien message (retiré)', body: 'Contenu fictif retiré.', audio_url: null, version: 1, status: 'retired', author_id: U.responsable2!, validator_id: U.responsable!, validated_at: iso(t, -60 * 24 * 60), source_ref: null },
  ];

  const interactions: Interaction[] = [
    { id: id('1e700000', 1), module: 'reny', beneficiary_id: ben(1), transcript: 'Transcription fictive : saignement signalé.', transcript_needs_review: true, outcome: 'danger_sign', severity: 'critical', actions: ['refer_csb'], alert_id: id('a1e00000', 1), is_demo: true, created_at: iso(t, -76), reviewed_at: null, reviewed_by_user_id: null, review_note: null },
    { id: id('1e700000', 2), module: 'reny', beneficiary_id: ben(2), transcript: 'Transcription fictive : question non couverte.', transcript_needs_review: true, outcome: 'fallback', severity: null, actions: ['transfer_advisor'], alert_id: null, is_demo: true, created_at: iso(t, -50), reviewed_at: null, reviewed_by_user_id: null, review_note: null },
    { id: id('1e700000', 3), module: 'tanora', beneficiary_id: null, transcript: null, transcript_needs_review: false, outcome: 'fallback', severity: null, actions: ['transfer_advisor'], alert_id: null, is_demo: false, created_at: iso(t, -60 * 5), reviewed_at: iso(t, -60 * 4), reviewed_by_user_id: U.conseiller!, review_note: 'Rappel effectué par le conseiller (note fictive).' },
  ];

  const audit: AuditEvent[] = [
    { id: id('ad100000', 1), at: iso(t, -10), actor_user_id: U.admin!, actor_role: 'admin', action: 'auth.login.success', entity_type: 'user', entity_id: U.admin!, request_id: 'req-demo-0001', site_id: null },
    { id: id('ad100000', 2), at: iso(t, -30), actor_user_id: U.chefcsb!, actor_role: 'csb_head', action: 'auth.login.success', entity_type: 'user', entity_id: U.chefcsb!, request_id: 'req-demo-0002', site_id: SITE_IDS.csbA },
    { id: id('ad100000', 3), at: iso(t, -225), actor_user_id: U.chefcsb!, actor_role: 'csb_head', action: 'referral.transition', entity_type: 'referral', entity_id: id('4ef00000', 2), request_id: 'req-demo-0003', site_id: SITE_IDS.csbA },
    { id: id('ad100000', 4), at: iso(t, -230), actor_user_id: U.chefcsb!, actor_role: 'csb_head', action: 'alert.acknowledge', entity_type: 'alert', entity_id: id('a1e00000', 3), request_id: 'req-demo-0004', site_id: SITE_IDS.csbA },
    { id: id('ad100000', 5), at: iso(t, -60 * 24 * 7), actor_user_id: U.responsable!, actor_role: 'clinical_lead', action: 'content.validate', entity_type: 'content', entity_id: id('c0e00000', 5), request_id: 'req-demo-0005', site_id: null },
    { id: id('ad100000', 6), at: iso(t, -60 * 24 * 8), actor_user_id: U.chefcsb!, actor_role: 'csb_head', action: 'beneficiary.identity.read', entity_type: 'beneficiary', entity_id: ben(1), request_id: 'req-demo-0006', site_id: SITE_IDS.csbA },
  ];

  return { sites, users, beneficiaries, identities, alerts, referrals, contents, interactions, audit };
}
