# Architecture FANILO

## Vue d'ensemble

```text
 Agent communautaire            CSB / admin                 Bénéficiaire
 ┌──────────────────┐     ┌──────────────────┐     ┌─────────────────────────┐
 │ apps/mobile      │     │ apps/dashboard   │     │ IVR / SMS / USSD        │
 │ Flutter, SQLite  │     │ React + TS       │     │ (RapidPro, à confirmer) │
 │ chiffrée, outbox │     │                  │     │                         │
 └────────┬─────────┘     └────────┬─────────┘     └────────────┬────────────┘
          │ /sync/push|pull        │ REST                       │ (P1)
          └───────────────┬────────┴────────────────────────────┘
                          ▼
             ┌──────────────────────────┐   HTTP interne   ┌──────────────────┐
             │ services/api (FastAPI)   │ ───────────────▶ │ services/ai      │
             │ auth, RBAC, site scope,  │  /transcribe     │ ASR (interface), │
             │ consentement, RENY,      │  /classify       │ classifieur      │
             │ alertes, références,     │ ◀─────────────── │ (propose)        │
             │ audit, sync, contenus    │                  └──────────────────┘
             │        │                 │
             │        ▼ import          │
             │ services/rules           │  ← décide (déterministe, versionné,
             │ (fanilo-rules)           │     validé par le responsable clinique)
             └────────────┬─────────────┘
                          ▼
                   PostgreSQL
```

## Principes

| Principe | Mise en œuvre |
|---|---|
| **L'IA propose, les règles décident** | `services/ai` renvoie une transcription et des codes de signes avec une confiance. Seul `services/rules`, sans IA, choisit une orientation. Tout cas incertain va en fallback vers un conseiller humain. |
| **Rien de non validé en production** | Règles, contenus, calendrier CPN et référentiels portent un `status`. Le statut `demo` est refusé si `FANILO_ALLOW_DEMO_CONTENT=false`, ce qui est imposé en production. |
| **Séparation identité / suivi** | `beneficiaries` est pseudonymisée (code `FAN-…`). `beneficiary_identities` est chiffrée en Fernet, accessible aux seuls rôles nominatifs, avec chaque lecture auditée. |
| **Moindre privilège** | 7 rôles, périmètre par site (site et sites descendants). Les rôles `admin`, `data_officer` et `technical` n'ont aucun accès nominatif. |
| **Offline-first** | UUID générés côté client, `version` (verrou optimiste), suppression logique, push idempotent par `change_id`, conflits renvoyés sans écrasement. |
| **Confidentialité des logs** | Logs JSON sans corps de requête, query string ni gabarit d'identifiant. L'audit ne contient aucun contenu médical. L'audio n'est jamais persisté. |

## Composants

| Dossier | Rôle | Doc |
|---|---|---|
| `services/api` | API métier | [contrat](api-contrat.md), `/docs` (OpenAPI) |
| `services/rules` | Moteur de règles médicales | [README](../services/rules/README.md), [sécurité médicale](securite-medicale.md) |
| `services/ai` | ASR et classification d'intentions, harnais d'évaluation | [README](../services/ai/README.md), [modèles](ia/modeles.md), [benchmark](ia/benchmark-asr-malgache.md) |
| `apps/dashboard` | Interface CSB et administration | [README](../apps/dashboard/README.md) |
| `apps/mobile` | Application de l'agent communautaire | [README](../apps/mobile/README.md) |

## Limites connues (architecture)

- Migrations exécutées sur PostgreSQL 17 (local et CI : montée, `alembic check`, descente, remontée).
- Limitation des tentatives de login en mémoire : insuffisante en multi-instance (Redis ou proxy à prévoir).
- Canaux IVR/SMS/USSD : seul un adaptateur `log` existe ; le canal vocal est simulé dans le dashboard (menu à touches, question écrite ou orale). L'intégration RapidPro dépend des accords avec les opérateurs.
- Chiffrement SQLCipher du mobile vérifié sur Linux (fichier illisible sans clé) ; pas encore vérifié sur un appareil Android.
- Aucun modèle ASR activé par défaut. Aucune performance n'est revendiquée avant évaluation sur un corpus réel.
