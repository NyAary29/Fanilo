# FANILO — service IA (`services/ai`)

Microservice FastAPI **interne** (jamais exposé publiquement) qui **propose** :

- une transcription de l'audio (ASR) ;
- une intention et des codes de signes `SIGN_...` à partir d'un texte.

> **Principe non négociable.** Ce service ne décide jamais d'une conduite médicale. Ses
> sorties sont des propositions, que le moteur de règles déterministe (`services/rules`)
> évalue. Si le service est absent, lent ou peu fiable, l'API répond `fallback` et transfère
> au conseiller (voir `docs/securite-medicale.md` et `docs/api-contrat.md`, sections 6 et 11).
> **Aucune performance n'est revendiquée** : aucun modèle n'a encore été évalué sur un
> corpus FANILO.

## Endpoints (contrat : `docs/api-contrat.md`, section 11)

| Méthode | Chemin | Corps → Réponse |
|---|---|---|
| GET | `/health` | `{status, asr_backend, classifier}` |
| POST | `/transcribe` | multipart `audio`, `language=mg` → `{text, confidence\|null, model, duration_s}` |
| POST | `/classify` | `{text, module}` → `{intent, sign_codes, confidence, model, is_demo}` |

Codes d'erreur de `/transcribe` :

| Code | Cas |
|---|---|
| 503 | aucun backend ASR configuré (`FANILO_AI_ASR_BACKEND=none`, défaut) ou échec d'inférence |
| 413 | audio trop volumineux (octets) ou trop long (secondes) |
| 415 | type MIME non accepté |
| 422 | audio vide ou illisible, `language` invalide |

`confidence` vaut toujours `null` avec les backends actuels : le pipeline Transformers ne
fournit pas de confiance calibrée, et le service n'en invente pas. L'API doit alors traiter
la transcription comme « à revoir ».

## Installation et lancement

```bash
export PATH="$HOME/Library/Python/3.9/bin:$PATH"   # si uv est installé via pip --user
cd services/ai
uv sync                       # sans ASR : léger, /transcribe répond 503
uv run uvicorn app.main:app --port 8001

uv run pytest                 # tests (aucun ne requiert l'extra [asr])
uv run ruff check .
```

### Extra optionnel `[asr]`

Les backends Transformers (`TransformersWhisperBackend`, `CtcBackend`) dépendent de
`torch` et `transformers`, **non installés par défaut**. Le code ne les importe qu'à
l'instanciation d'un backend : sans l'extra, le service démarre et se teste normalement.

```bash
uv sync --extra asr           # + binaire ffmpeg requis (décodage de l'audio)
FANILO_AI_ASR_BACKEND=whisper uv run uvicorn app.main:app --port 8001
```

Si un backend Transformers est demandé sans l'extra, le démarrage échoue avec un message
explicite (pas de bascule silencieuse). Le modèle est téléchargé depuis Hugging Face au
premier démarrage (cache `HF_HOME`).

Docker :

```bash
docker build -t fanilo-ai services/ai                                   # sans ASR
docker build --build-arg INSTALL_ASR=true -t fanilo-ai:asr services/ai  # avec ASR + ffmpeg
```

## Variables d'environnement (préfixe `FANILO_AI_`)

| Variable | Défaut | Rôle |
|---|---|---|
| `FANILO_AI_ASR_BACKEND` | `none` | `none`, `whisper` (TransformersWhisperBackend) ou `ctc` (CtcBackend) |
| `FANILO_AI_ASR_MODEL` | *(vide)* | identifiant Hugging Face ; vide = modèle suggéré ci-dessous |
| `FANILO_AI_ASR_MODEL_REVISION` | *(aucune)* | commit ou tag du modèle, **à épingler en production** |
| `FANILO_AI_ASR_DEVICE` | `cpu` | `cpu`, `cuda`, `cuda:0`... |
| `FANILO_AI_ASR_SAMPLING_RATE` | `16000` | taux de rééchantillonnage du décodage ffmpeg |
| `FANILO_AI_MAX_AUDIO_BYTES` | `5242880` (5 Mio) | taille maximale de l'audio |
| `FANILO_AI_MAX_AUDIO_SECONDS` | `60` | durée maximale de l'audio |
| `FANILO_AI_ALLOWED_MIME_TYPES` | wav, ogg, opus, webm, mpeg, mp4, m4a, flac | liste séparée par des virgules |
| `FANILO_AI_INTENT_LEXICON_PATH` | `lexicons/intents.demo.yaml` | lexique du classifieur |
| `FANILO_AI_MAX_TEXT_CHARS` | `2000` | longueur maximale du texte à classer |
| `FANILO_AI_ENABLE_DOCS` | `false` | expose `/docs` (OpenAPI) |
| `FANILO_AI_LOG_LEVEL` | `INFO` | niveau de journalisation |

## Choix du modèle par défaut

**Le backend par défaut est `none`** : aucun modèle n'est chargé tant qu'il n'a pas été
choisi après évaluation. Les modèles *suggérés* quand un backend est activé respectent le
premier filtre de la note `docs/ia/benchmark-asr-malgache.md` : **aucune licence non
commerciale**.

| Backend | Modèle suggéré | Licence déclarée | Réserves |
|---|---|---|---|
| `whisper` | `waxal-benchmarking/whisper-small-waxal-mlg` | CC-BY-4.0 (attribution requise) ; base Whisper sous licence permissive | données WAXAL malgache sous CC-BY-SA : effet sur les poids à faire valider juridiquement (note, § 6) ; carte de modèle non auditée |
| `ctc` | `Flo976/w2v-bert-malagasy` | CC-BY-4.0 ; base w2v-BERT 2.0 sous MIT | données d'entraînement sans licence déclarée (note, § 3.4) ; décodage glouton, sans KenLM |

Exclusions et remarques :

- **Meta MMS et tous ses dérivés** (`mms-1b-all`, `mms-300m`, `mms-300m-waxal-mlg`...) sont
  sous **CC-BY-NC 4.0** : à ne jamais configurer comme brique livrée (référence de
  comparaison en recherche uniquement).
- **Whisper sans affinage** est inutilisable en malgache : ne jamais pointer
  `FANILO_AI_ASR_MODEL` vers `openai/whisper-*` en production.
- **Omnilingual ASR** (Apache 2.0) est le candidat le plus intéressant sur le plan des
  licences, mais il est distribué avec sa propre bibliothèque ; il n'est pas branché ici.
  Un backend dédié pourra être ajouté derrière l'interface `AsrBackend`.
- Ces suggestions sont un point de départ technique, **pas une recommandation** : le choix
  final suit l'évaluation en trois étapes de la note (§ 8 et 9) et la validation juridique
  des licences.

## Limites de l'audio et protection des données

- Types MIME : liste blanche (paramètres comme `; codecs=opus` ignorés), sinon 415.
- Taille : `FANILO_AI_MAX_AUDIO_BYTES`. Le corps HTTP est plafonné **avant** parsing
  (`Content-Length`, puis comptage des octets en transfert « chunked »), sinon 413.
- Durée : `FANILO_AI_MAX_AUDIO_SECONDS`, vérifiée dès l'en-tête pour un WAV, sinon après
  décodage par le backend, sinon 413.
- **L'audio n'est jamais écrit sur disque** : le seuil de débordement sur fichier temporaire
  du parseur multipart est relevé au-dessus de la limite de taille, et le décodage passe
  par un pipe ffmpeg (stdin/stdout). Ni l'audio ni le texte ne sont journalisés.

## Classifieur d'intention baseline

`LexiconIntentClassifier` (interface `IntentClassifier`, remplaçable plus tard par un modèle
Transformers) lit `lexicons/intents.demo.yaml` (**`status: demo`, DÉMONSTRATION — NON
VALIDÉ**). Les mots-clés malgaches n'ont **pas** été relus : ils doivent l'être par des
locuteurs natifs et par le responsable clinique. Les codes `SIGN_DEMO_xx` sont ceux du
référentiel fictif `services/rules/rulesets/demo/sign_codes.demo.yaml` (vérifié par un test).

- Normalisation : minuscules, accents retirés, apostrophes et ponctuation → espace.
- Correspondance sur mots entiers (« ra » ne correspond pas dans « rano »).
- Signes de danger prioritaires → `report_danger_sign` ; signes non filtrés par module (un
  code hors module provoque un fallback côté moteur de règles, plutôt qu'un faux négatif).
- Confiance heuristique, non calibrée : `min(0,9 ; 0,6 + 0,1 × (n − 1))` pour `n` mots-clés
  distincts ; 0,4 en cas d'égalité entre intentions ; `out_of_scope` à 0,1 (0,0 si texte
  vide). Avec le seuil de démo du moteur de règles (`min_detection_confidence: 0.8`), un seul
  mot-clé (0,6) conduit à un fallback vers le conseiller : c'est voulu pour un lexique non
  validé.
- Pas de gestion de la négation : « tsy misy ra » déclenche le signe (biais assumé vers les
  faux positifs). Pas de lemmatisation : les variantes doivent être listées.

## Évaluation (`eval/`)

Protocole de référence : `docs/ia/benchmark-asr-malgache.md`, § 9 (jeu gelé, double
transcription, stratification, effectifs par locuteur). Le harnais calcule :

- WER et CER (`jiwer`, au niveau du corpus) globaux et par strate (`dialect`, `age_group`,
  `gender`, `channel`, `speech_type`), avec le nombre de locuteurs par strate ;
- le taux de faux négatifs sur les mentions de signes de danger (et les faux positifs),
  via le classifieur appliqué à l'hypothèse ;
- une sortie JSON et Markdown, avec l'empreinte SHA-256 du manifeste et la normalisation.

Manifeste CSV ou JSONL : `audio_path`, `reference`, `speaker_id`, `dialect`, `age_group`,
`gender`, `channel`, `speech_type` ; facultatifs : `utt_id`, `module`, `hypothesis`,
`expected_sign_codes` (annotation humaine ; à défaut, les signes attendus sont déduits de la
référence par le classifieur, ce qui isole l'effet de l'ASR).

```bash
# Exemple factice fourni (aucun audio réel, transcriptions inventées) :
uv run python -m eval.run_eval --manifest eval/samples/manifest.example.jsonl \
    --out-json rapport.json --out-md rapport.md
# Prédictions produites ailleurs :
uv run python -m eval.run_eval --manifest test.jsonl --predictions hyp.jsonl --asr-system nom
# Transcription par le backend configuré :
FANILO_AI_ASR_BACKEND=ctc uv run --extra asr python -m eval.run_eval --manifest test.jsonl --transcribe
```

Les strates de moins de `--min-speakers` locuteurs (défaut 20) sont signalées comme non
interprétables. Les chiffres produits sur l'exemple factice n'ont aucune valeur.

## Structure

```
app/            main.py (endpoints), config.py, audio.py (limites), schemas.py
app/asr/        base.py (AsrBackend), none_backend.py, transformers_backend.py, factory.py
app/nlu/        base.py (IntentClassifier), lexicon.py, normalize.py
lexicons/       intents.demo.yaml (DÉMO, non validé)
eval/           manifest.py, metrics.py, report.py, run_eval.py, samples/
tests/
```

Voir aussi `docs/ia/modeles.md` (architecture IA, implémenté / non implémenté).
