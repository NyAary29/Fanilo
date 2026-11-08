# Modèles d'IA de FANILO : architecture et état d'avancement

> **Statut** : version 1, novembre 2026. Ce document décrit ce qui existe dans
> `services/ai`. **Il ne contient et ne revendique aucun chiffre de performance** : aucun
> modèle n'a été évalué sur un corpus FANILO. Les résultats publiés par des tiers sont
> recensés, avec leurs limites, dans [benchmark-asr-malgache.md](benchmark-asr-malgache.md).

## 1. Place de l'IA dans la chaîne de décision

```
audio ──► [services/ai] /transcribe ──► texte ─┐
                                               ├─► [services/ai] /classify ──► intention + SIGN_... + confiance
texte saisi / signes cochés par l'AC ──────────┘                                       │
                                                                                       ▼
                                         [services/rules] moteur déterministe (liste fermée, validée)
                                                                                       │
                                                         orientation / contenu validé / fallback conseiller
```

- L'IA **propose** ; le moteur de règles **décide** ; tout cas incertain va au conseiller
  ([securite-medicale.md](../securite-medicale.md), § 2).
- La transcription n'est jamais l'unique déclencheur ni l'unique inhibiteur d'une alerte
  (benchmark, § 10). Les questions de danger critiques passent par des réponses fermées.
- L'API appelle `services/ai` avec un délai court ; en cas d'échec, elle répond `fallback`
  ([api-contrat.md](../api-contrat.md), § 6 et 11).

## 2. Ce qui est implémenté

| Élément | Implémentation | État |
|---|---|---|
| Endpoints `/health`, `/transcribe`, `/classify` | FastAPI, conformes au contrat § 11 | Fait, testé |
| Interface ASR `AsrBackend` | `NoneBackend` (défaut, 503 explicite) | Fait, testé |
| Backends Transformers | `TransformersWhisperBackend`, `CtcBackend` (pipeline `automatic-speech-recognition`), extra optionnel `[asr]`, modèle configurable | Code écrit ; logique testée avec un faux module `transformers` ; **jamais exécuté avec un vrai modèle** dans ce dépôt |
| Limites audio | liste blanche MIME, taille plafonnée avant parsing, durée (en-tête WAV ou après décodage) | Fait, testé |
| Données audio | traitement en mémoire, pas de fichier temporaire, aucun journal de contenu | Fait (parseur multipart configuré, décodage par pipe) |
| Interface `IntentClassifier` | `LexiconIntentClassifier`, déterministe, lexique YAML `status: demo` | Fait, testé |
| Lexique | `services/ai/lexicons/intents.demo.yaml` : 3 intentions + 6 codes `SIGN_DEMO_xx` | **Démonstration, non validé** ; malgache non relu |
| Harnais d'évaluation | `services/ai/eval/` : WER/CER globaux et par strate, faux négatifs sur les signes de danger, JSON + Markdown | Fait, testé sur un manifeste factice |

### Confiance renvoyée

- `/transcribe` : `confidence = null` (le pipeline ne fournit pas de confiance calibrée ;
  le service n'en fabrique pas).
- `/classify` : heuristique documentée, `min(0,9 ; 0,6 + 0,1 × (n − 1))` pour `n` mots-clés
  distincts, 0,4 en cas d'égalité, 0,1 pour `out_of_scope`. Ce n'est **pas une
  probabilité**. Le seuil appliqué est celui du moteur de règles
  (`min_detection_confidence`), à fixer et valider (securite-medicale.md, § 4).

## 3. Choix de modèles et licences

Premier filtre : **aucune licence non commerciale** dans le produit livré (benchmark, § 1
et § 8). Le backend par défaut est `none`. Modèles suggérés à l'activation d'un backend :

| Backend | Modèle suggéré | Licence | Réserve principale |
|---|---|---|---|
| `whisper` | `waxal-benchmarking/whisper-small-waxal-mlg` | CC-BY-4.0 | données WAXAL sous CC-BY-SA, effet sur les poids à valider juridiquement |
| `ctc` | `Flo976/w2v-bert-malagasy` | CC-BY-4.0 | données d'entraînement sans licence déclarée |

Écartés : **MMS et dérivés** (CC-BY-NC 4.0) ; **Whisper sans affinage** (inutilisable en
malgache). **Omnilingual ASR** (Apache 2.0), candidat le plus intéressant sur le plan des
licences, n'est pas branché : il est distribué avec sa propre bibliothèque et demandera un
backend dédié derrière `AsrBackend`.

Ces suggestions sont des points de départ techniques, pas des recommandations : le choix
suit l'évaluation sur corpus FANILO (benchmark, § 8 et 9).

## 4. Ce qui n'est pas implémenté

- Aucun modèle n'est livré, téléchargé ni évalué dans le dépôt ; aucun chiffre de WER, CER
  ou rappel n'est revendiqué.
- Pas de confiance ASR calibrée (ni log-probabilités Whisper, ni score CTC).
- Pas de modèle de langue (KenLM) ni de vocabulaire de santé pour le décodage.
- Pas de backend Omnilingual ASR, ni d'ASR embarqué sur Android (hors ligne).
- Pas de détection de silence, d'hallucination ou de boucle de répétition (benchmark, § 9.2
  et § 10.3) : à ajouter avant tout usage réel.
- Classifieur : pas de négation, pas de lemmatisation, pas de modèle appris ; lexique
  malgache **non relu** par des locuteurs natifs ni par le responsable clinique.
- Évaluation : pas de corpus, pas de calcul d'intervalles de confiance par locuteur, pas de
  mesure de latence (RTF) ni du taux d'hallucination ; pas de conversion des nombres en
  lettres dans la normalisation.
- Pas de TTS.
- Le service n'est pas encore déclaré dans `docker-compose.yml` ni appelé par l'API.

## 5. Prochaines étapes

1. Relecture du lexique par des locuteurs natifs (plusieurs variétés) et par le responsable
   clinique ; passage `demo` → `draft` → `in_review` → `validated` comme les référentiels.
2. Constitution du corpus d'évaluation selon le protocole du benchmark (§ 9) et validation
   juridique des licences (§ 14).
3. Évaluation des candidats (§ 8, étape 2) avec `services/ai/eval`, en priorité sur le
   **taux de faux négatifs des signes de danger**, par variété et par canal.
4. Ajout des garde-fous (silence, boucles, confiance) et d'un backend Omnilingual si retenu.
