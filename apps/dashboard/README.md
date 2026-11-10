# FANILO — Tableau de bord web (`apps/dashboard`)

Interface web destinée aux CSB, à l'équipe clinique et à l'administration (exigence **F-14**,
plus les écrans de gestion liés à F-08, F-09, F-11, F-12 et F-13). Elle est codée contre le
contrat [`docs/api-contrat.md`](../../docs/api-contrat.md), qui reste la référence.

> FANILO ne remplace pas un professionnel de santé. Ce rappel figure en pied de page sur tous les écrans.

## Design

Le design suit la maquette « écosystème FANILO » : barre latérale vert forêt avec icônes
([lucide-react](https://lucide.dev)), fond crème, cartes de chiffres colorées, police Nunito
embarquée (`@fontsource-variable/nunito`, aucun appel à un CDN : utilisable hors Internet).
Jetons dans `src/styles/tokens.css`. Les deux couleurs du graphique d'activité ont été
vérifiées (daltonisme, contraste) ; l'identité des courbes ne dépend jamais de la seule couleur
(ligne pleine/pointillée, marqueurs rond/carré, étiquettes directes, vue tableau).

En local, `scripts/dev.sh` active `VITE_DEMO_ACCOUNTS=true` : l'écran de connexion propose
alors des boutons « Chef CSB », « Agent communautaire »… qui remplissent le formulaire.

## Stack

React 19, TypeScript strict, Vite 8, React Router 7, TanStack Query 5. Le style repose sur des
jetons CSS (`src/styles/tokens.css`) et une feuille globale légère, sans framework UI.
Les tests utilisent Vitest, Testing Library et jsdom, et le lint ESLint avec typescript-eslint.

## Installation

```bash
cd apps/dashboard
npm install
cp .env.example .env.local   # puis ajuster VITE_API_URL
npm run dev                  # http://localhost:5173 (scripts/dev.sh utilise le port 5174)
```

Node 22 ou plus récent est requis (le projet est testé avec Node 24 et npm 11).

| Script | Rôle |
|---|---|
| `npm run dev` | serveur de développement contre l'API définie par `VITE_API_URL` |
| `npm run dev:mock` | serveur de développement en **mode mock**, sans backend |
| `npm run build` | `tsc` strict, puis build de production dans `dist/` |
| `npm run lint` | ESLint |
| `npm test -- --run` | tests Vitest (une seule passe) |

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `VITE_API_URL` | — (obligatoire hors mock) | URL de base de `services/api`, sans barre oblique finale. Le backend doit autoriser cette origine dans `cors_origins`. |
| `VITE_USE_MOCKS` | `false` | `true` : l'interface tourne sur des données **fictives** en mémoire. `npm run dev:mock` (mode Vite `mock`) l'active aussi. |

Les variables `VITE_*` sont **intégrées au bundle au moment du build** : n'y mettez jamais de secret.

## Mode mock

L'adaptateur est maison (`src/api/mock/mockFetch.ts`) : une fonction compatible `fetch`
injectée dans le client API, sans service worker ni dépendance. Il reproduit les règles utiles
à l'interface (rôles, périmètre de site simplifié, accès aux données nominatives, machine à
états des références, cycle de vie des contenus, rotation des jetons). En production, son code
est chargé à part (import dynamique) et seulement si le mode mock est actif.

Les comptes fictifs ont tous le mot de passe `demo` :

| Identifiant | Rôle | Écrans |
|---|---|---|
| `chef.csb` | `csb_head` (CSB Démo A) | tableau de bord, alertes, références |
| `conseiller` | `clinical_advisor` | alertes, références, questions à revoir |
| `responsable`, `responsable2` | `clinical_lead` | tout sauf utilisateurs, sites et audit ; validation des contenus |
| `admin` | `admin` | tableau de bord, contenus, utilisateurs, sites |
| `donnees` | `data_officer` | tableau de bord, journal d'audit |
| `agent` | `community_agent` | simulateur vocal |
| `technique` | `technical` | aucun écran (message d'accueil) |

Toutes les données (noms « Personne fictive N », sites « CSB Démo », etc.) sont inventées.
Le jeu de données est recréé à chaque chargement de page : un rechargement invalide donc la
session mock, ce qui est normal.

## Architecture

```
src/
  api/          types.ts (types du contrat, en un seul endroit), client.ts (HTTP, refresh),
                tokenStore.ts, endpoints.ts (une fonction par endpoint), config.ts, mock/
  auth/         AuthContext (session, /auth/me), permissions.ts, RequireRole (garde de route)
  domain/       règles d'affichage : machine à états des références, retard d'alerte, formats
  components/   Layout, Footer, DemoBanner, ReferralTransitionForm, BeneficiaryRef…
  pages/        un fichier par écran
```

Les écrans sont les suivants :

| Route | Écran | Rôles (côté client) |
|---|---|---|
| `/connexion` | Connexion | — |
| `/tableau-de-bord` | Indicateurs agrégés (`/dashboard/summary`) | `csb_head`, `clinical_lead`, `admin`, `data_officer` |
| `/alertes`, `/alertes/:id` | Liste filtrable, retards, détail, journal, acquitter, résoudre, noter | `csb_head`, `clinical_advisor`, `clinical_lead` |
| `/references`, `/references/:id` | Liste, détail, transitions | idem |
| `/questions` | Questions à revoir (`/interactions`) | `clinical_advisor`, `clinical_lead` |
| `/contenus` | Contenus : brouillons, soumission, validation, retrait | `clinical_lead`, `admin` |
| `/utilisateurs`, `/sites` | Gestion des comptes et des sites | `admin` |
| `/patientes` | Espace agent : liste de travail (à suivre / à jour, recherche), détail, prochain rappel, alerte ouverte (`/followup/patients`, lectures d'identité auditées) | `community_agent`, `csb_head`, `clinical_advisor`, `clinical_lead` |
| `/simulateur` | Simulateur vocal : menu à touches (`/reference/menus`), question écrite ou orale (micro, multipart), signes (`/reference/sign-codes`) ; vraie chaîne `/interactions/ask` | `community_agent`, `csb_head`, `clinical_advisor`, `clinical_lead` |
| `/statistiques` | Statistiques thématiques agrégées (`/dashboard/topics`, petites cellules masquées) ; export DHIS2 pour `data_officer` | `csb_head`, `clinical_lead`, `admin`, `data_officer` |
| `/audit` | Journal d'audit | `data_officer` |

## Sécurité

### Jetons et risque XSS

- Le **jeton d'accès** reste **en mémoire uniquement** : il n'est jamais écrit dans le stockage du navigateur.
- Le **jeton de rafraîchissement** est gardé dans **`sessionStorage`**. Ce choix évite de
  redemander le mot de passe à chaque rechargement de l'onglet, ce qui arrive souvent sur
  tablette avec une connexion instable. Il est limité à l'onglet, effacé à sa fermeture, à la
  déconnexion et à tout échec de rafraîchissement, et il tourne à chaque rafraîchissement.
  Si le stockage n'est pas disponible, le jeton reste en mémoire.
- Sur un 401, le client tente **un seul** rafraîchissement, partagé entre les requêtes
  concurrentes, puis rejoue la requête. Si le serveur refuse le rafraîchissement, les jetons
  sont effacés et l'utilisateur revient à l'écran de connexion. Une coupure réseau pendant le
  rafraîchissement ne détruit pas la session.
- **Risque** : un script injecté (XSS) dans l'origine du dashboard peut lire `sessionStorage`
  et exfiltrer le jeton de rafraîchissement. Il peut aussi, de toute façon, appeler l'API tant
  que la page est ouverte.
- **Recommandation à terme** : que le backend émette le jeton de rafraîchissement dans un
  cookie `HttpOnly; Secure; SameSite=Strict` limité à `/auth`, et que `/auth/refresh` le lise
  depuis ce cookie (avec une protection CSRF). Il faut aussi servir le dashboard avec une
  **CSP stricte** (`script-src 'self'`, sans `unsafe-inline`). Seul `src/api/tokenStore.ts`
  serait à modifier.

### Contrôle d'accès

Le filtrage par rôle (navigation, routes, boutons) est **purement ergonomique** : il est
signalé en commentaire dans `src/auth/permissions.ts`, `RequireRole.tsx` et `App.tsx`. L'API
reste la seule autorité : elle applique le rôle, le périmètre de site et l'accès aux données
nominatives.

### Données nominatives

- Le dashboard affiche le **code pseudonyme** (`FAN-…`) des bénéficiaires, jamais leur nom.
- L'identité (`/beneficiaries/{id}/identity`) n'est jamais chargée automatiquement. Un rôle
  nominatif (`community_agent`, `clinical_advisor`, `csb_head`, `clinical_lead`) peut la
  demander explicitement sur le détail d'une alerte ou d'une référence ; la lecture est
  auditée côté serveur et le résultat n'est pas gardé en cache.
- Les rôles `admin`, `data_officer` et `technical` ne voient jamais ce bouton. Leurs écrans
  (comptes, sites, audit, indicateurs agrégés) ne contiennent aucun champ nominatif de bénéficiaire.

### Démonstration

Un bandeau « **DÉMO — non validé cliniquement** » s'affiche sur toute alerte ou interaction
dont `is_demo` vaut vrai. Les contenus au statut `demo` portent un badge équivalent.

## Tests

`npm test -- --run` couvre :

- le client API : en-tête Bearer, rafraîchissement et rotation sur 401, mutualisation, échec et déconnexion, coupure réseau, messages d'erreur ;
- le stockage des jetons ;
- les gardes de rôle et la navigation par rôle, la redirection vers la connexion et l'expiration de session ;
- la machine à états des références (matrice complète) et le formulaire de motif obligatoire ;
- le bandeau démo ;
- le parcours alertes (retards, filtre, acquittement, note), le bouton « Valider » masqué pour l'auteur, et l'absence de données nominatives pour l'administrateur.

## Limites et hypothèses

- **`GET /interactions`** : le type `Interaction` suit désormais le schéma réel de l'API (intention, signes, contenu servi affichés pour la revue).
- **Filtres `status`** : ils sont envoyés à `GET /contents` et `GET /referrals` alors que le
  contrat ne les liste que pour `GET /alerts`.
- **Audit** : le format de `from` et `to` n'est pas précisé ; le dashboard envoie un datetime
  ISO UTC (début et fin de journée).
- **Rôles des alertes et références** : le contrat ne liste pas de rôles (seulement « dans le
  périmètre du site »). Le dashboard les ouvre à `csb_head`, `clinical_advisor` et `clinical_lead`.
- **Contenus** : seul un brouillon est modifiable. Le contrat évoque une « nouvelle version »
  quand on modifie un contenu publié, sans dire par quel endpoint ; ce cas n'est pas géré. Le
  retrait est proposé pour les statuts `validated` et `demo` uniquement.
- **Mot de passe initial** : le dashboard impose au moins 12 caractères à la création. Ce n'est
  pas dans le contrat ; la règle doit être alignée sur la politique du backend.
- **Pas de création de référence ni de bénéficiaire** : ces actions relèvent de l'application
  mobile. Pas non plus d'écran de bénéficiaires, de grossesses ou de CPN.
- Les identifiants d'utilisateurs (destinataire, auteur…) s'affichent sous forme abrégée :
  `GET /users` est réservé à `admin` et `data_officer`, donc un chef CSB ne peut pas résoudre
  les identifiants en noms de compte.
- Vérifié en navigateur réel (Chrome headless, Playwright) contre le backend local et
  PostgreSQL, pour chaque rôle : tous les écrans chargent sans erreur HTTP ni erreur JS,
  simulateur (menu, texte, micro simulé, signes → alerte) et export DHIS2 compris.
  Corrigé à cette occasion : `limit=500` refusé par `/sites` (max 200), requête `/auth/me`
  envoyée sans jeton après un rechargement (le client rafraîchit désormais d'abord).
