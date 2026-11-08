# fanilo-rules — moteur de règles déterministe

Paquet Python autonome qui évalue des **codes de signes normalisés** contre un **jeu de
règles versionné** et produit des **orientations** (AC, conseiller, CSB, structure de
référence) accompagnées de **codes de messages** validés.

- Aucune dépendance d'IA, de framework web ou de base de données (seulement `pydantic`
  et `PyYAML`).
- Ne diagnostique pas, ne prescrit pas : l'enum des actions est fermé et ne contient que
  des orientations.
- Les signes de danger reposent sur une **liste fermée et versionnée** (exigence F-07),
  jamais uniquement sur un modèle probabiliste.

Principes et gouvernance : voir [`docs/securite-medicale.md`](../../docs/securite-medicale.md).

## Installation et tests

```bash
cd services/rules
uv sync
uv run pytest          # couverture à 100 % exigée (branches comprises)
uv run ruff check .
```

## Utilisation

```python
from fanilo_rules import EvaluationContext, EvaluationInput, Module, RuleEngine

engine = RuleEngine.from_files(
    "rulesets/demo/reny_danger_signs.demo.yaml",
    "rulesets/demo/sign_codes.demo.yaml",
    allow_demo=True,  # False en production : seul le statut 'validated' est accepté
)

result = engine.evaluate(
    EvaluationInput(
        module=Module.RENY,
        detected_signs=frozenset({"SIGN_DEMO_01"}),
        detection_confidence=0.93,  # None = saisie déterministe (ex. clavier)
        context=EvaluationContext(pregnant=True),
    )
)
result.max_severity  # Severity.CRITICAL
result.actions  # (Action.REFER_REFERENCE_FACILITY,)
result.is_demo  # True -> l'appelant doit l'afficher / le journaliser
result.trace  # étapes explicables de la décision
```

### Sortie (`EvaluationResult`)

| Champ | Contenu |
|---|---|
| `ruleset_id`, `ruleset_version`, `sign_catalog_version` | Traçabilité de la version utilisée |
| `is_demo` | Vrai si le jeu **ou** le référentiel n'est pas `validated` |
| `triggered_rules` | Règles déclenchées, triées par sévérité décroissante puis identifiant |
| `candidate_rules` | Règles qui auraient été déclenchées mais dont la détection est sous le seuil de confiance (information pour le conseiller, **aucune orientation automatique**) |
| `max_severity` | Sévérité maximale des règles déclenchées (`None` si aucune) |
| `actions`, `message_codes` | Orientations et contenus, dédupliqués, ordre stable |
| `fallback`, `fallback_reasons` | Transfert au conseiller humain et motifs |
| `unknown_signs` | Codes absents du référentiel pour ce module |
| `trace` | Trace explicable, étape par étape |

### Règles de sécurité de l'évaluateur

| Situation | Résultat |
|---|---|
| Entrée vide | `fallback` (`empty_input`) → `transfer_counselor` |
| Code inconnu du référentiel | `fallback` (`unknown_sign_code`) ; les règles déclenchées par les codes **connus** sont conservées (un code inconnu ne masque jamais une alerte) |
| Confiance < `min_detection_confidence` | `fallback` (`low_confidence`) ; aucune orientation automatique, règles exposées en `candidate_rules` |
| Codes connus mais aucune règle déclenchée | `fallback` (`no_rule_matched`) — jamais « rien à signaler » |
| Plusieurs règles | Toutes sont renvoyées, la sévérité maximale l'emporte |
| Contexte inconnu (`pregnant=None`) | Ne supprime jamais une règle conditionnée par le contexte |

Le moteur est pur : même entrée et même jeu de règles ⇒ même sortie.

## Format YAML

Deux fichiers : un **référentiel de codes de signes** et un **jeu de règles** qui le
référence (identifiant + version). Tout champ inconnu est rejeté ; les clés YAML
dupliquées aussi.

### Métadonnées communes

| Champ | Description |
|---|---|
| `version` | Semver (`MAJEUR.MINEUR.CORRECTIF`) |
| `status` | `demo` \| `draft` \| `in_review` \| `validated` \| `retired` |
| `validated_by`, `validated_at` | Obligatoires si `status: validated` (date ISO) |
| `source` | Référence du protocole clinique source |
| `language` | Langue des contenus (`fr`, `mg`…) |

### Référentiel de signes

```yaml
catalog_id: fanilo-demo-signs
version: 0.1.0
status: demo
source: "DÉMO — référentiel fictif"
language: fr
signs:
  - code: SIGN_DEMO_01          # ^SIGN_[A-Z0-9_]+$
    modules: [reny]
    label: "[DÉMO] Signe fictif n° 1"
```

### Jeu de règles

```yaml
ruleset_id: fanilo-reny-danger-signs-demo
version: 0.1.0
status: demo
source: "DÉMO — règles fictives"
language: fr
sign_catalog: {catalog_id: fanilo-demo-signs, version: 0.1.0}
min_detection_confidence: 0.8          # seuil de confiance de la détection amont
fallback_message_code: MSG_DEMO_TRANSFER_COUNSELOR
rules:
  - id: DEMO-RENY-001                  # unique dans le jeu
    version: 0.1.0
    module: reny                       # reny | tanora
    conditions:
      match: any                       # any | all
      signs: [SIGN_DEMO_01, SIGN_DEMO_02]
      context: {pregnant: true}        # optionnel
    severity: critical                 # routine | urgent | critical
    action: refer_reference_facility   # enum fermé, voir ci-dessous
    message_code: MSG_DEMO_CRITICAL    # référence à un contenu validé (^MSG_…)
    response_delay:                    # obligatoire si urgent ou critical
      is_placeholder: true             # démo : pas de valeur chiffrée
      # target_minutes: <entier>       # uniquement si is_placeholder: false
```

Actions autorisées (enum fermé) : `refer_community_agent`, `transfer_counselor`,
`refer_csb`, `refer_reference_facility`.

Contrôles au chargement : champ inconnu, action ou statut hors enum, identifiant de
règle ou code de signe dupliqué, `validated` sans `validated_by`/`validated_at`,
délai placeholder dans un jeu `validated`, règle utilisant un code absent du
référentiel (ou d'un autre module), référentiel dont l'identifiant ou la version ne
correspond pas.

### Politique de chargement

- `allow_demo=False` (production) : seuls les documents `validated` sont acceptés
  (jeu de règles **et** référentiel).
- `allow_demo=True` (développement) : tout statut sauf `retired`.
- `retired` est toujours refusé.

## Cycle de validation clinique

1. **`draft`** — rédaction par l'équipe à partir d'un protocole de référence
   (champ `source`).
2. **`in_review`** — revue par le responsable clinique : liste des signes, sévérités,
   orientations, délais réels (`is_placeholder: false`, `target_minutes`), codes de
   messages et contenus associés.
3. **`validated`** — signature : `validated_by`, `validated_at`, incrément de version.
   Revue de code obligatoire ; seul ce statut est chargeable en production.
4. **`retired`** — remplacé ou suspendu ; plus jamais chargé.

Toute modification d'un jeu `validated` crée une nouvelle version qui repasse par
`draft` → `in_review` → `validated`. Les fichiers `rulesets/demo/*` restent
**à jamais** au statut `demo`.
