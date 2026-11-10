# Contrat d'API FANILO (v0.1 — P0)

Ce contrat est la **référence commune** du backend (`services/api`), du dashboard (`apps/dashboard`), de l'application mobile (`apps/mobile`) et du service IA (`services/ai`). Toute divergence se corrige ici d'abord.

Conventions :
- JSON, champs en `snake_case`, dates ISO 8601. Les `date` sont au format `YYYY-MM-DD` ; les `datetime` sont en UTC avec fuseau.
- Identifiants : UUID v4. Pour les entités synchronisables, l'UUID **peut être généré par le client**.
- Authentification : en-tête `Authorization: Bearer <access_token>`, sur tous les endpoints sauf `/health` et `/auth/login|refresh`.
- Erreurs : format FastAPI `{"detail": ...}`. Codes : 401 non authentifié, 403 rôle ou site interdit, 404 introuvable **ou hors périmètre** (on ne révèle pas l'existence), 409 conflit de version, 422 validation.
- Pagination : `?limit=50&offset=0` → `{"items": [...], "total": n}`. **Toutes** les listes (`GET` sur une collection) sont paginées ainsi, `/sites` compris, et acceptent `?status=` quand l'entité a un statut.
- Mots de passe : 12 caractères minimum, contrôlés **côté serveur** (422).
- **Périmètre par site** : un utilisateur rattaché à un site ne voit que les données de son site et des sites enfants. `admin`, `clinical_lead` et `data_officer` ont une vue globale, mais `admin`, `data_officer` et `technical` n'ont **pas** accès aux champs nominatifs (voir `NOMINATIVE_DATA_ROLES`).
- Entités synchronisables : elles exposent toujours `id`, `version`, `created_at`, `updated_at` et `deleted_at`.

## 1. Authentification (existant)

| Méthode | Chemin | Corps → Réponse |
|---|---|---|
| POST | `/auth/login` | `{login, password}` → `{access_token, token_type, expires_in, refresh_token, refresh_expires_in}` |
| POST | `/auth/refresh` | `{refresh_token}` → même réponse (rotation) |
| POST | `/auth/logout` | `{refresh_token}` → 204 |
| GET | `/auth/me` | → `{id, login, role, site_id, is_active}` |

Rôles : `community_agent`, `clinical_advisor`, `csb_head`, `clinical_lead`, `admin`, `data_officer`, `technical`.

## 2. Sites et utilisateurs (P0.4)

`Site` : `{id, name, kind: "csb"|"reference_facility"|"community_zone", code, district, region, parent_site_id|null, is_active}`

| Méthode | Chemin | Rôles |
|---|---|---|
| GET | `/sites` | tous les utilisateurs authentifiés (lecture) |
| POST / PATCH | `/sites`, `/sites/{id}` | `admin`. Corps du POST : `Site` sans `id` ; PATCH partiel |
| GET | `/users` | `admin`, `data_officer` |
| POST | `/users` | `admin`. Corps : `{login, password, role, site_id}` |
| PATCH | `/users/{id}` | `admin`. Corps : `{role?, site_id?, is_active?}` |
| GET | `/users/directory` | tout rôle sauf `technical` : annuaire minimal paginé `{items: [{id, login, role, site_id}], total}` des comptes du périmètre (utilisé pour afficher destinataires et auteurs) |

`User` (lecture) : `{id, login, role, site_id, is_active, last_login_at}`

## 3. Bénéficiaires, identité et consentement (P0.5, F-01, F-02)

L'identité est **séparée** du suivi. `Beneficiary` ne contient aucun nom :

`Beneficiary` : `{id, code: "FAN-XXXXXX", site_id, birth_year|null, preferred_channel: "sms"|"ivr"|"ac_visit"|"none", ...sync}`

`BeneficiaryIdentity` (chiffrée au repos, rôles nominatifs uniquement) : `{beneficiary_id, display_name, phone|null, village|null, ...sync}`. **Son `id` est égal à `beneficiary_id`** (relation 1-1).

Le `code` `FAN-XXXXXX` est **toujours attribué par le serveur**, y compris pour une création hors ligne. Le client le reçoit dans `server_data`.

`Consent` : `{id, beneficiary_id, scope: "reny"|"tanora"|"reminders"|"voice_processing", method: "oral"|"written", information_version, collected_by_user_id, collected_at, withdrawn_at|null, withdrawn_by_user_id|null, ...sync}`

| Méthode | Chemin | Notes |
|---|---|---|
| GET / POST | `/beneficiaries` | création possible avec un `id` fourni par le client ; filtre `?site_id=` |
| GET / PATCH | `/beneficiaries/{id}` | PATCH exige `version` dans le corps, sinon 409 |
| GET / PUT | `/beneficiaries/{id}/identity` | rôles nominatifs uniquement |
| GET / POST | `/beneficiaries/{id}/consents` | |
| POST | `/consents/{id}/withdraw` | renseigne `withdrawn_at` ; les traitements liés s'arrêtent (rappels annulés) |

**Règle :** sans consentement actif `reny`, la création d'une grossesse est refusée (422). Sans consentement `reminders`, aucun rappel n'est planifié.

## 4. RENY : grossesse, CPN et rappels (P0.7, F-02 à F-04)

`Pregnancy` : `{id, beneficiary_id, status: "active"|"delivered"|"ended"|"transferred", lmp_date|null, estimated_due_date|null, dates_confirmed_by: "ac_declared"|"health_worker"|"ultrasound", ...sync}`

`AncVisit` (CPN) : `{id, pregnancy_id, sequence, scheduled_date, status: "planned"|"done"|"missed"|"cancelled", done_date|null, site_id|null, ...sync}`

| Méthode | Chemin | Notes |
|---|---|---|
| GET / POST | `/beneficiaries/{id}/pregnancies` | à la création, le calendrier CPN est généré à partir du **calendrier configuré**, **à condition** qu'une date de référence soit connue (`lmp_date` ou `estimated_due_date`). Sans date, la grossesse est créée sans visite ; le calendrier est généré dès que l'une de ces dates est renseignée (PATCH ou sync), tant qu'aucune visite n'existe |
| GET / PATCH | `/pregnancies/{id}` | |
| GET | `/pregnancies/{id}/anc-visits` | |
| PATCH | `/anc-visits/{id}` | marquer `done` ou `missed`, ou replanifier |
| GET | `/anc-visits/upcoming?days=7` | dans le périmètre du site |

Si le calendrier n'est pas `validated` et que le mode démo est inactif, la création renvoie **422**. Le calendrier CPN est **un fichier de configuration versionné** (`status: demo` tant qu'il n'est pas validé cliniquement), jamais codé en dur.

`Reminder` : `{id, beneficiary_id, anc_visit_id|null, channel, scheduled_at, status: "scheduled"|"sent"|"failed"|"cancelled", message_code}`. Il est envoyé par un adaptateur de canal. Seul l'adaptateur `log` (aucun opérateur) existe en P0 ; RapidPro est à confirmer.

## 5. Contenus de santé (P0.6, F-13)

`ContentItem` : `{id, code: "MSG_...", module: "reny"|"tanora"|"common", language: "mg"|"fr", title, body, audio_url|null, version, status: "draft"|"in_review"|"validated"|"retired"|"demo", author_id|null, validator_id|null, validated_at|null, source_ref|null, review_note|null}`. `author_id` est nul pour un contenu importé (catalogue de démo). La validation et le retrait s'appliquent par couple (`code`, `language`). `/contents/published` renvoie un seul contenu par code et par langue (le validé avant la démo), et le filtre `module` inclut `common`.

| Méthode | Chemin | Rôles |
|---|---|---|
| GET | `/contents`, `/contents/{id}` | gestion : `clinical_lead`, `admin` (tous statuts ; filtres `?status=&module=&language=`) |
| POST | `/contents` | `clinical_lead`, `admin` : crée un `draft` (version 1) |
| PATCH | `/contents/{id}` | `clinical_lead`, `admin`, **`draft` uniquement** (sinon 409) |
| POST | `/contents/{id}/new-version` | copie un contenu `validated` en nouveau `draft` (même `code`, version + 1). La version validée reste servie jusqu'à la validation de la nouvelle |
| POST | `/contents/{id}/submit` | `draft` → `in_review` |
| POST | `/contents/{id}/reject` | **`clinical_lead`** : `in_review` → `draft`, corps `{note}` |
| POST | `/contents/{id}/validate` | **`clinical_lead` uniquement** : `in_review` → `validated`. Un auteur ne valide pas son propre contenu (403). La version validée précédente du même `code` passe à `retired` |
| POST | `/contents/{id}/retire` | `clinical_lead` : depuis `validated` ou `demo` |
| GET | `/contents/published?module=&language=` | tout utilisateur authentifié. Ne renvoie que `validated`, plus `demo` si `FANILO_ALLOW_DEMO_CONTENT=true` |

## 6. Question, réponse contrôlée et interactions (F-05, F-06, F-07)

| Méthode | Chemin | Notes |
|---|---|---|
| POST | `/interactions/ask` | voir ci-dessous |
| GET | `/interactions?review_status=pending` | `clinical_advisor`, `clinical_lead` : questions transférées ou non couvertes, pour revue |
| POST | `/interactions/{id}/review` | `clinical_advisor`, `clinical_lead`. Corps `{note}` : le conseiller documente sa réponse ou son orientation |

`Interaction` (lecture) : `{id, created_at, module, beneficiary_id|null, site_id|null, asked_by_user_id, transcript|null, sign_codes, intent|null, outcome, actions, severity|null, content_code|null, alert_id|null, is_demo, review_status: "pending"|"reviewed"|"not_required", reviewed_by_user_id|null, reviewed_at|null, review_note|null}`. `review_status` vaut `pending` dès que `outcome = fallback` ou `danger_sign`.

`POST /interactions/ask`, deux formes possibles :
- `multipart/form-data` avec `audio` (fichier), `module` et `beneficiary_id?` : transcription par le service IA ;
- JSON `{module, beneficiary_id?, text?, sign_codes?, language?}` : texte déjà transcrit ou signes cochés par l'AC (saisie déterministe, `confidence = null`).

`language` vaut `mg` par défaut, avec repli sur `fr`. Rôles : rôles de soin (`NOMINATIVE_DATA_ROLES`). Si `beneficiary_id` est fourni, un consentement actif sur le module est exigé, plus `voice_processing` pour la forme audio ; sinon 422 `consent_required`.

Réponse :
```json
{
  "interaction_id": "uuid",
  "transcript": "texte|null",
  "transcript_needs_review": true,
  "outcome": "answer|danger_sign|fallback",
  "actions": ["refer_csb"],
  "severity": "critical|urgent|routine|null",
  "content": null | {"code": "MSG_...", "title": "...", "body": "...", "audio_url": null, "status": "validated|demo"},
  "alert_id": "uuid|null",
  "is_demo": true,
  "disclaimer": "FANILO ne remplace pas un professionnel de santé."
}
```

Règles :
- La décision vient du moteur de règles (`services/rules`), jamais du modèle IA.
- **Question informative** : si aucun signe n'est détecté et qu'aucune règle n'est déclenchée, l'intention proposée par l'IA peut être servie par un contenu publié, selon la configuration versionnée `information*.yaml` (`outcome = "answer"`, `actions = []`). Les modules listés dans `counselor_confirmation_modules` (TANORA) passent toujours en `review_status = pending`. Voir [sécurité médicale §2 bis](securite-medicale.md).
- Un `danger_sign` n'est **jamais** rétrogradé en fallback : si le contenu associé n'est pas publié, l'alerte est conservée, le contenu de fallback est servi et `transfer_counselor` est ajouté.
- Si le service IA est indisponible ou peu fiable, ou si l'entrée n'est pas couverte, la réponse est `outcome = "fallback"` avec un transfert au conseiller.
- **L'audio brut n'est jamais stocké** par l'API. Le transcript est conservé selon la politique de rétention.

## 7. Alertes (F-08) et références (F-09)

`Alert` (synchronisable en lecture seule, porte donc `version` et `deleted_at`) : `{id, beneficiary_id|null, site_id|null, interaction_id|null, rule_id, ruleset_version, severity, status: "open"|"acknowledged"|"resolved"|"escalated"|"cancelled", recipient_user_id|null, backup_user_id|null, due_at, due_at_is_demo, escalated_at|null, acknowledged_at|null, acknowledged_by_user_id|null, resolved_at|null, is_demo, created_at}`

`AlertEvent` : `{id, alert_id, at, actor_user_id|null, type: "created"|"acknowledged"|"escalated"|"note"|"resolved"|"cancelled", note|null}`

| Méthode | Chemin | Notes |
|---|---|---|
| GET | `/alerts?status=open&sort=due\|recent` | lecture : `community_agent`, `csb_head`, `clinical_advisor`, `clinical_lead`, dans le périmètre du site |
| GET | `/alerts/{id}` | inclut `events` |
| POST | `/alerts/{id}/acknowledge` | destinataire, suppléant, ou `csb_head` du site |
| POST | `/alerts/{id}/resolve` | `{note}` |
| POST | `/alerts/{id}/notes` | `{note}` |

Destinataire : un `csb_head` actif du site, ou à défaut du site ancêtre le plus proche ; sinon un `clinical_advisor`. Le suppléant est la personne éligible suivante. S'il n'y a personne, l'alerte est créée directement en `escalated` avec `recipient_user_id = null` et un log d'erreur. Résolution possible seulement après acquittement, par le destinataire, le suppléant, le `csb_head` du site ou le `clinical_lead`.

L'escalade est une tâche (`python -m app.modules.alerts.cli escalate`, à planifier par cron) : une alerte non acquittée après `due_at` passe à `escalated` et est réassignée au suppléant. Un message n'indique jamais une prise en charge tant que l'accusé de réception n'est pas enregistré.

`Referral` : `{id, beneficiary_id, alert_id|null, from_site_id|null, to_site_id, status: "proposed"|"accepted"|"arrived"|"transferred"|"not_completed", reason|null, outcome_note|null, ...sync}`

Transitions autorisées :
- `proposed` → `accepted` ou `not_completed` ;
- `accepted` → `arrived`, `transferred` ou `not_completed` ;
- `transferred` → `arrived` ou `not_completed`.

Toute autre transition renvoie 409. `not_completed` exige `reason`. Une référence est créée au statut `proposed` (en sync aussi) et ne peut être supprimée qu'à ce statut. Elle est visible si le site de la bénéficiaire **ou** le site destinataire est dans le périmètre.

| Méthode | Chemin |
|---|---|
| GET / POST | `/referrals` : lecture et création par `community_agent`, `csb_head`, `clinical_advisor` et `clinical_lead` (lecture seule pour ce dernier), dans le périmètre du site |
| GET | `/referrals/{id}` |
| POST | `/referrals/{id}/transition` : `{to_status, reason?, outcome_note?}` |

## 8. Synchronisation hors ligne (F-10)

| Méthode | Chemin | Notes |
|---|---|---|
| GET | `/sync/pull?since=<cursor>&limit=500` | → `{changes: [{entity, id, version, deleted_at, data}], next_cursor, has_more}` |
| POST | `/sync/push` | `{device_id, changes: [{change_id, entity, op: "upsert"\|"delete", id, base_version\|null, data}]}` |

Réponse de `push` : `{results: [{change_id, status: "applied"|"conflict"|"rejected", server_version?, server_data?, error?}]}`

- Entités synchronisables en écriture : `beneficiary`, `beneficiary_identity`, `consent`, `pregnancy`, `anc_visit`, `referral`. En **lecture seule** (pull uniquement) : `alert` et `site`. Les sites servent au choix de `to_site_id` hors ligne.
- **Contenu de `data`** : la représentation **complète** des champs modifiables par le client. Les champs gérés par le serveur (`version`, `created_at`, `updated_at`, `deleted_at`, `code`, `collected_by_user_id`, `withdrawn_by_user_id`, etc.) sont ignorés s'ils sont envoyés. Pour `op: "delete"`, `data` peut être `null` : le serveur pose `deleted_at`.
- **Mêmes règles métier que les endpoints REST** :
  - grossesse refusée sans consentement `reny` actif ;
  - transitions de référence et motif obligatoire pour `not_completed` ;
  - périmètre de site.
  Une violation donne `status: "rejected"` **pour ce changement seulement**, avec `error: {code, message}`. Exemples de `code` : `consent_required`, `invalid_transition`, `forbidden`, `validation_error`.
- **Retrait de consentement** : un `upsert` qui renseigne `withdrawn_at` équivaut à `POST /consents/{id}/withdraw`. Le serveur renseigne `withdrawn_by_user_id` et annule les rappels. Vider `withdrawn_at` pour annuler un retrait est `rejected` : il faut recueillir un nouveau consentement.
- **`server_version` et `server_data` sont renvoyés pour `applied` comme pour `conflict`.**
- Un lot contient au maximum 100 changements. Le 422 global est réservé à une **enveloppe** mal formée (JSON invalide, plus de 100 changements). Le client ne doit pas le réessayer tel quel ; il le signale à l'utilisateur.
- **Idempotence :** un `change_id` déjà traité renvoie le même résultat sans réappliquer la modification.
- **Conflit :** si `base_version` ≠ version serveur, le serveur n'écrase rien et renvoie l'état serveur. Le client décide (par défaut, la version serveur l'emporte et la modification locale est conservée pour revue).
- Pour une ligne supprimée, le pull renvoie `deleted_at` renseigné et `data: null`.
- **Périmètre du pull** : les entités de suivi (bénéficiaires, identités, consentements, grossesses, CPN, références, alertes) suivent le périmètre du site de l'utilisateur. **Exception : `site`**, référentiel non nominatif, est envoyé en entier (sites actifs et inactifs) pour permettre de choisir hors ligne une structure de destination de référence hors de son périmètre.
- Le curseur est opaque. Il repose sur une **séquence de modification côté serveur** (`sync_seq`, strictement croissante et attribuée à chaque écriture), et non sur l'horloge. Le périmètre suit le site de l'utilisateur.

## 8 bis. Référentiels distribués aux applications

Ces référentiels répondent **503** lorsqu'aucune version utilisable n'est servie (fichier absent ou invalide, ou statut non `validated` hors mode démo). Les applications conservent alors leur dernière copie en cache.

| Méthode | Chemin | Notes |
|---|---|---|
| GET | `/reference/sign-codes?module=` | référentiel des codes de signes utilisé par le moteur de règles : `{catalog_id, version, status, is_demo, items: [{code, label_fr, label_mg\|null, modules}]}`. Il n'est servi que s'il est `validated`, ou si `FANILO_ALLOW_DEMO_CONTENT=true` |
| GET | `/reference/menus?module=reny\|tanora&language=mg` | menu vocal (IVR/USSD, simulateur) : `{config_id, version, is_demo, module, items: [{key, code, title, body, audio_url, status}]}`. Seuls les contenus publiés sont proposés ; 503 si la configuration n'est pas servie (statut non `validated` hors mode démo) |
| GET | `/reference/consent-information` | versions de l'information présentée lors du consentement : `{items: [{scope, version, status, summary_fr, summary_mg\|null}]}`, depuis un fichier de configuration versionné |

**Énumération fermée des `actions`** (moteur de règles) : `refer_community_agent`, `transfer_counselor`, `refer_csb`, `refer_reference_facility`.

## 9. Tableau de bord (F-14)

`GET /dashboard/summary?site_id=` →
```json
{
  "open_alerts": 0, "overdue_alerts": 0, "pending_referrals": 0,
  "upcoming_anc_7d": 0, "missed_anc_30d": 0,
  "active_agents_30d": 0, "total_agents": 0,
  "active_pregnancies": 0, "interactions_30d": 0, "fallback_rate_30d": 0.0,
  "generated_at": "datetime"
}
```

Réponse **agrégée uniquement**, sans aucun nominatif, accessible à `csb_head`, `clinical_lead`, `admin` et `data_officer`.

`GET /dashboard/topics?days=30&site_id=` (F-16, mêmes rôles et même périmètre) → `{period_days, min_cell_size, total, suppressed_cells, suppressed_total, items: [{module, intent|null, outcome, content_code|null, count}], generated_at}`. Toute cellule de moins de `FANILO_STATS_MIN_CELL_SIZE` questions (5 par défaut) est masquée et seulement comptée dans `suppressed_*`.

`GET /dashboard/activity?months=6&site_id=` (mêmes rôles) → `{months: [{month: "AAAA-MM", pregnancies, alerts, questions, anc_done}], sites: [{site_id, name, code, region, active_pregnancies, open_alerts}], generated_at}`. Agrégats uniquement ; une zone communautaire est comptée dans son CSB parent.

## 9 ter. Espace agent : liste de travail

`GET /followup/patients?q=&status=a_jour|a_suivre` : rôles nominatifs (`NOMINATIVE_DATA_ROLES`), périmètre du site. → `{items: [{beneficiary_id, code, site_id, site_name, age|null, display_name|null, village|null, pregnancy|null: {id, month|null, lmp_date, estimated_due_date}, next_anc|null: {visit_id, sequence, scheduled_date, days}, anc_done, anc_total, missed_anc, open_alerts, latest_alert_id|null, status, reasons: ["alerte_ouverte"|"cpn_manquee"|"dates_inconnues"]}], total}`. Les « à suivre » viennent en premier. **Chaque identité renvoyée produit un événement d'audit `identity.read`.** `month` est indicatif (calculé depuis la DDR), jamais une donnée clinique.

## 9 bis. Interopérabilité (F-17, préparatoire)

`GET /interop/dhis2/data-value-set?period=AAAAMM&include_small_cells=false` : `data_officer` uniquement, audité (`export.aggregates`). Export agrégé mensuel par CSB au format DHIS2 `dataValueSet`. Rien n'est transmis à un système tiers. Voir [interoperabilite.md](interoperabilite.md).

## 10. Audit (F-12)

`GET /audit?entity_type=&actor_user_id=&from=&to=` : `data_officer` uniquement.

`AuditEvent` : `{id, at, actor_user_id|null, actor_role|null, action, entity_type|null, entity_id|null, request_id|null, site_id|null}`. Les filtres `from` et `to` sont des datetimes ISO 8601. Un échec de connexion n'a ni acteur ni entité. **Aucun contenu médical ni nominatif dans un événement d'audit.**

Actions tracées : connexion (réussie ou non), lecture d'une identité, création ou modification de bénéficiaire, consentement et retrait, alertes, transitions de référence, validation de contenu, exports, changements de rôle.

## 11. Service IA (`services/ai`, interne, non exposé publiquement)

| Méthode | Chemin | Corps → Réponse |
|---|---|---|
| GET | `/health` | `{status, asr_backend, classifier}` |
| POST | `/transcribe` | multipart `audio`, `language=mg` → `{text, confidence\|null, model, duration_s}` ; renvoie 503 si aucun backend ASR n'est configuré |
| POST | `/classify` | `{text, module}` → `{intent, sign_codes: [...], confidence, model, is_demo}` |

L'API appelle ce service via `FANILO_AI_SERVICE_URL`, avec un délai maximal court. En cas d'échec, la réponse est `fallback`.
