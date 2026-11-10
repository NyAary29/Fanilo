# Matrice de traçabilité des exigences

Source : *Cahier des charges FANILO v1.0 (novembre 2026)*, document de travail soumis à validation métier, clinique et technique. Le document source n'est pas versionné dans ce dépôt.

Légende du statut : ⬜ à faire · 🟨 en cours · ✅ fait et testé · 🔒 bloqué par une validation externe

## Exigences fonctionnelles

| ID | Prio | Fonction | Lot technique | Statut | Validation externe requise |
|---|---|---|---|---|---|
| F-01 | P0 | Consentement (oral ou écrit, horodatage, auteur, version de l'information, retrait) | P0.5 Consentement | ✅ | Texte et versions de l'information présentée (clinique et juridique) |
| F-02 | P0 | Dossier de grossesse pseudonymisé | P0.7 RENY | ✅ | Liste des données minimales (responsable données) |
| F-03 | P0 | Calendrier CPN | P0.7 RENY | ✅ technique · 🔒 contenu | Calendrier CPN de référence (responsable clinique) ; fichier de démo en attendant |
| F-04 | P0 | Rappels selon canal et règles approuvées | P0.7 RENY + couche canaux | 🟨 | Planification et envoi faits (adaptateur `log`) ; opérateurs et RapidPro à confirmer |
| F-05 | P0 | Question vocale transcrite en malgache | Service IA + simulateur vocal | 🟨 | Chaîne complète en place ; aucun modèle ASR activé par défaut, corpus vocal et benchmark requis |
| F-06 | P0 | Réponse uniquement à partir de contenus approuvés, sinon transfert | Contenus + règles + `information.yaml` | ✅ technique · 🔒 contenu | Contenus et associations intention → contenu validés |
| F-07 | P0 | Liste fermée et versionnée de signes de danger | `services/rules` | ✅ technique · 🔒 contenu | Liste validée par le responsable clinique |
| F-08 | P0 | Alerte (destinataire nommé, délai, suppléant, statut, journal) | P0.8 Alertes + tâche d'escalade | ✅ | Destinataires désignés par CSB/SDSP, délais |
| F-09 | P0 | Suivi de référence (proposée, acceptée, arrivée, transférée, non aboutie) | P0.8 Références (web + mobile) | ✅ | — |
| F-10 | P0 | Saisie hors connexion chiffrée et synchronisation avec gestion des conflits | `/sync` + mobile (SQLCipher) | ✅ technique · 🟨 terrain | Tests terrain avec les AC ; vérification sur appareil Android |
| F-11 | P0 | Accès limité au rôle et au site | P0.3 Auth et rôles | ✅ | — |
| F-12 | P0 | Journal d'audit | P0.9 Audit (exports compris) | ✅ | Politique d'accès au journal |
| F-13 | P0 | Contenus versionnés (auteur, validateur, date, version, langue, statut) | P0.6 Contenus | ✅ | Comité scientifique |
| F-14 | P0 | Tableau de bord CSB | Dashboard React | ✅ | Indicateurs à définir (suivi-évaluation) |
| F-15 | P1 | TANORA | Menus vocaux, app anonyme `apps/femmes` (API `/public`), réponse du conseiller par jeton, confirmation conseiller | ✅ technique · 🔒 contenu | Thèmes et protocole de conseil |
| F-16 | P1 | Statistiques thématiques anonymisées | `/dashboard/topics` + écran Statistiques | ✅ | Seuil d'agrégation (5 par défaut, à valider) |
| F-17 | P1 | Interfaces documentées pour CommCare/DHIS2 | OpenAPI + export DHIS2 ([interoperabilite.md](interoperabilite.md)) | ✅ préparatoire | Autorisation institutionnelle, correspondance des UID |
| F-18 | P2 | Module FO (santé mentale) | — | 🔒 | Circuit de prise en charge validé |

## Exigences non fonctionnelles (extrait)

| Domaine | Réponse technique | Statut |
|---|---|---|
| Sécurité | Secrets par variables d'environnement, garde-fous au démarrage en production, RBAC, chiffrement Fernet des identités, SQLCipher sur mobile | ✅ (TLS : hébergement à choisir) |
| Confidentialité | Pseudonymisation (`FAN-…`), identité séparée et chiffrée, logs sans données, secret statistique | ✅ |
| Connectivité | Offline-first mobile, sync idempotente par `change_id`, conflits sans écrasement | ✅ |
| Traçabilité | Identifiant de requête dans chaque log ; journal d'audit | ✅ |
| Sauvegarde | Sauvegarde chiffrée et test de restauration scriptés ([exploitation.md](exploitation.md)) | ✅ local · RPO/RTO à valider |
| Maintenabilité | Tests automatisés, ruff, ESLint, CI (dont migrations et parcours sur PostgreSQL réel) | ✅ |
| Open source | Licence à choisir | 🔒 |
