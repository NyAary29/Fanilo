# Sécurité médicale de FANILO

> Document de référence pour l'équipe technique, l'équipe clinique et le comité de
> pilotage. Il traduit le §7.2 du cahier des charges en règles d'ingénierie.
> Les sections marquées **[À COMPLÉTER PAR LE COMITÉ]** doivent être arrêtées par les
> instances compétentes avant tout déploiement auprès du public.

## 1. Principes non négociables

1. **FANILO ne diagnostique pas, ne prescrit pas et ne remplace pas un professionnel de
   santé.** Il informe à partir de contenus validés et oriente.
2. **Aucune alerte critique ne dépend uniquement d'un modèle probabiliste.** Les signes
   de danger reposent sur une **liste fermée et versionnée**, validée par le responsable
   clinique (exigence F-07), qui déclenche l'orientation prévue.
3. **Toute entrée non couverte ou incertaine est transférée à un humain** (conseiller).
   Le système ne répond jamais « rien à signaler » par défaut.
4. **Ne jamais promettre une prise en charge immédiate.** Les messages indiquent une
   orientation, pas un délai garanti d'intervention.
5. **Aucune prescription, aucun médicament, aucun dosage, aucune conduite
   thérapeutique.** Les seules actions possibles sont des **orientations** (agent
   communautaire, conseiller, CSB, structure de référence) et la diffusion de **contenus
   validés identifiés par un code**.

## 2. Séparation IA / règles

| Couche | Rôle | Nature | Peut décider d'une alerte ? |
|---|---|---|---|
| Reconnaissance vocale, compréhension (IA) | Transformer la parole ou la saisie en **codes de signes normalisés** (`SIGN_…`) avec une confiance | Probabiliste | **Non** |
| Moteur de règles (`services/rules`) | Évaluer les codes contre la liste fermée et versionnée ; produire sévérité, orientation, code de message, trace | Déterministe, sans IA | **Oui**, uniquement via des règles validées |
| Contenus (`message_code`) | Texte ou audio diffusé à l'usager | Validé par le responsable clinique | — |
| Conseiller humain | Reprendre tout cas incertain, non couvert ou en échec | Humain | Oui |

Garanties techniques du moteur de règles :

- le paquet `fanilo-rules` n'importe aucune bibliothèque d'IA, aucun framework web et
  aucune base de données ;
- les règles ne portent **aucun texte médical** : uniquement des codes de signes, une
  sévérité, une action issue d'un **enum fermé d'orientations** et un code de message ;
- tout champ inconnu, toute action hors enum, tout identifiant dupliqué est rejeté au
  chargement ;
- **fallback vers le conseiller** si : entrée vide, code inconnu du référentiel,
  confiance de détection sous le seuil, ou aucune règle déclenchée ;
- un code inconnu ne masque jamais une alerte déclenchée par des codes connus ;
- un contexte inconnu (ex. grossesse non renseignée) ne supprime jamais une règle ;
- l'évaluation est pure et déterministe, et chaque décision porte la version du jeu
  de règles, l'indicateur `is_demo` et une trace explicable, à journaliser.

## 3. Cycle de vie des jeux de règles et des référentiels

```
draft ──► in_review ──► validated ──► retired
  ▲                         │
  └──── nouvelle version ◄──┘        demo : jamais promu, jamais en production
```

| Statut | Signification | Chargeable en production ? |
|---|---|---|
| `demo` | Contenu fictif pour tests et démonstrations, **non validé cliniquement** | Non |
| `draft` | Rédaction en cours à partir d'un protocole source | Non |
| `in_review` | Soumis au responsable clinique | Non |
| `validated` | Signé (`validated_by`, `validated_at`), délais réels renseignés | **Oui** |
| `retired` | Remplacé ou suspendu | Non (jamais) |

- En production, le chargeur est appelé avec `allow_demo=False` : il **refuse** tout jeu
  de règles ou référentiel dont le statut n'est pas `validated`. Côté API, ce
  comportement est piloté par `allow_demo_content` (faux par défaut).
- Un jeu `validated` ne peut contenir aucun délai placeholder.
- Toute modification d'un jeu validé crée une **nouvelle version** qui repasse par
  `draft` → `in_review` → `validated`. Les versions antérieures restent archivées dans
  le dépôt pour la traçabilité.
- Les fichiers de `services/rules/rulesets/demo/` portent l'en-tête
  « DÉMONSTRATION — NON VALIDÉ CLINIQUEMENT — NE PAS UTILISER EN SOINS » et restent au
  statut `demo`.

## 4. Qui valide quoi

| Objet | Rédige | Valide | Trace de validation |
|---|---|---|---|
| Liste des signes de danger et référentiel de codes (F-07) | Équipe clinique | **Responsable clinique** | `validated_by`, `validated_at`, `source` dans le YAML |
| Règles : sévérités, orientations, délais de réponse attendus | Équipe clinique avec l'équipe technique | **Responsable clinique** | Idem |
| Contenus diffusés (textes, audios, traductions malgache/français) | Équipe contenus | **Responsable clinique** | Registre des contenus par `message_code` **[À COMPLÉTER PAR LE COMITÉ]** |
| Protocoles d'orientation (AC, CSB, structure de référence) | Équipe clinique, partenaires sanitaires | **Responsable clinique** | Référence du protocole (`source`) |
| Seuil de confiance de la détection (`min_detection_confidence`) | Équipe technique (mesures) | Responsable clinique et responsable technique | Version du jeu de règles |
| Code du moteur et des intégrations | Équipe technique | Revue de code par un pair | Revue de la demande de fusion |

## 5. Ce qui exige une validation humaine

- Toute création, modification ou suppression d'un signe de danger, d'une règle, d'une
  sévérité, d'une orientation ou d'un délai.
- Tout nouveau contenu diffusé ou toute modification d'un contenu existant, y compris
  les traductions.
- Le passage d'un document au statut `validated`, et son retrait (`retired`).
- L'activation d'un module (`reny`, `tanora`) auprès du public.
- Toute réponse dans une situation non couverte : elle relève du conseiller humain, pas
  du système.
- Le paramétrage de l'environnement autorisant des contenus de démonstration.

## 6. Suspension d'un module en cas d'incident grave

> **[À COMPLÉTER PAR LE COMITÉ]** — la procédure ci-dessous est une trame technique ;
> les rôles, délais, critères et circuits de notification doivent être arrêtés par le
> comité de pilotage et le responsable clinique.

1. **Signalement** : tout membre de l'équipe, conseiller ou partenaire signale un
   incident grave présumé (orientation erronée, signe de danger manqué, contenu
   inapproprié) au responsable clinique et au responsable technique.
   Canal et délai de signalement : **[À COMPLÉTER]**.
2. **Décision de suspension** : prise par **[À COMPLÉTER — ex. responsable clinique ou
   comité]**. En cas de doute, la suspension est privilégiée.
3. **Mise en œuvre technique** : le jeu de règles concerné passe au statut `retired`
   (refusé par le chargeur) et/ou le module est désactivé dans la configuration ; les
   appels sont redirigés vers le conseiller humain avec un message validé
   n'impliquant aucune promesse de prise en charge immédiate.
4. **Analyse** : reconstitution à partir des journaux (version du jeu de règles, trace
   de l'évaluateur, indicateur `is_demo`), identification de la cause.
5. **Correction et revalidation** : nouvelle version passant par `draft` →
   `in_review` → `validated`.
6. **Réactivation** : décidée par **[À COMPLÉTER]**, consignée avec sa justification.
7. **Information** des partenaires et autorités compétentes : **[À COMPLÉTER]**.

## 7. Références

- Cahier des charges FANILO, §7.2 (sécurité médicale) et exigence F-07.
- `services/rules/README.md` : format des règles, politique de chargement, cycle de
  validation.
