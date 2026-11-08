# Matrice de traçabilité des exigences

Source : *Cahier des charges FANILO v1.0 (novembre 2026)*, document de travail soumis à validation métier, clinique et technique. Le document source n'est pas versionné dans ce dépôt.

Légende du statut : ⬜ à faire · 🟨 en cours · ✅ fait et testé · 🔒 bloqué par une validation externe

## Exigences fonctionnelles

| ID | Prio | Fonction | Lot technique | Statut | Validation externe requise |
|---|---|---|---|---|---|
| F-01 | P0 | Consentement (oral ou écrit, horodatage, auteur, version de l'information, retrait) | P0.5 Consentement | ⬜ | Texte et versions de l'information présentée (clinique et juridique) |
| F-02 | P0 | Dossier de grossesse pseudonymisé | P0.7 RENY | ⬜ | Liste des données minimales (responsable données) |
| F-03 | P0 | Calendrier CPN | P0.7 RENY | 🔒 | Calendrier CPN de référence (responsable clinique) |
| F-04 | P0 | Rappels selon canal et règles approuvées | P0.7 RENY + couche canaux | 🔒 | Opérateurs et RapidPro à confirmer |
| F-05 | P0 | Question vocale transcrite en malgache | Service IA (prototype) | ⬜ | Corpus vocal et consentement |
| F-06 | P0 | Réponse uniquement à partir de contenus approuvés, sinon transfert | P0.6 Contenus + règles | ⬜ | Contenus validés |
| F-07 | P0 | Liste fermée et versionnée de signes de danger | `services/rules` | 🟨 | Liste validée par le responsable clinique |
| F-08 | P0 | Alerte (destinataire nommé, délai, suppléant, statut, journal) | P0.8 Alertes | ⬜ | Destinataires désignés par CSB/SDSP, délais |
| F-09 | P0 | Suivi de référence (proposée, acceptée, arrivée, transférée, non aboutie) | P0.8 Références | ⬜ | — |
| F-10 | P0 | Saisie hors connexion chiffrée et synchronisation avec gestion des conflits | Schéma (P0.2) + `/sync` + mobile | 🟨 | Tests terrain avec les AC |
| F-11 | P0 | Accès limité au rôle et au site | P0.3 Auth et rôles | 🟨 | — |
| F-12 | P0 | Journal d'audit | P0.9 Audit | ⬜ | Politique d'accès au journal |
| F-13 | P0 | Contenus versionnés (auteur, validateur, date, version, langue, statut) | P0.6 Contenus | ⬜ | Comité scientifique |
| F-14 | P0 | Tableau de bord CSB | Dashboard React | ⬜ | Indicateurs à définir (suivi-évaluation) |
| F-15 | P1 | TANORA | Module TANORA | ⬜ | Thèmes et protocole de conseil |
| F-16 | P1 | Statistiques thématiques anonymisées | Analytique | ⬜ | Seuils d'agrégation |
| F-17 | P1 | Interfaces documentées pour CommCare/DHIS2 | API | ⬜ | Autorisation institutionnelle |
| F-18 | P2 | Module FO (santé mentale) | — | 🔒 | Circuit de prise en charge validé |

## Exigences non fonctionnelles (extrait)

| Domaine | Réponse technique | Statut |
|---|---|---|
| Sécurité | Secrets par variables d'environnement, garde-fous au démarrage en production, RBAC | 🟨 |
| Confidentialité | Logs sans corps de requête ni query string ; pseudonymisation (à venir) | 🟨 |
| Connectivité | UUID côté client, `version`, suppression logique dès le schéma | 🟨 |
| Traçabilité | Identifiant de requête dans chaque log ; journal d'audit (à venir) | 🟨 |
| Maintenabilité | Tests automatisés, ruff, CI GitHub Actions | 🟨 |
| Open source | Licence à choisir | 🔒 |
