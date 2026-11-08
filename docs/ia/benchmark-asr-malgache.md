# Benchmark documentaire : ASR (et TTS) pour le malgache parlé

> **Statut** : note de recherche documentaire, version 1, novembre 2026.
> **Portée** : aide au choix des modèles de reconnaissance vocale (ASR) et, accessoirement, de synthèse vocale (TTS) pour FANILO.
> **Ce que cette note n'est pas** : une évaluation. Aucun modèle n'a été testé par l'équipe. Tous les chiffres cités viennent de sources publiques (liens fournis) et ont été relevés le 8 novembre 2026. Aucune performance n'est affirmée sans source.

---

## 1. Résumé

1. **Licences** : c'est le premier filtre, avant la performance.
   - **Meta MMS** (ASR `mms-1b-all`, `mms-300m`, TTS `mms-tts-mlg`) est sous **CC-BY-NC 4.0, donc non commercial** ([README MMS](https://github.com/facebookresearch/fairseq/blob/main/examples/mms/README.md), [mms-1b-all](https://huggingface.co/facebook/mms-1b-all), [mms-tts-mlg](https://huggingface.co/facebook/mms-tts-mlg)). Tout modèle affiné à partir de MMS hérite de cette licence ([WAXAL-NET, arXiv 2606.02375](https://arxiv.org/html/2606.02375)).
   - Pour un projet open source qui doit pouvoir être repris par un opérateur, une ONG prestataire ou le ministère, MMS ne convient qu'à la recherche ou comme point de comparaison.
   - **Whisper** (MIT), **XLS-R** (Apache 2.0), **w2v-BERT 2.0** (MIT) et **Omnilingual ASR** (Apache 2.0) n'ont pas cette restriction.
2. **Whisper ne connaît presque pas le malgache.**
   - Le code `mg` existe dans le tokenizer ([tokenizer.py](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py)), mais l'article Whisper ne déclare que **0,2 h** de données de transcription en malgache ([Radford et al., 2022, annexe E](https://arxiv.org/abs/2212.04356)).
   - Sans adaptation, Whisper-large-v3 obtient **100,8 % de WER** sur de la parole spontanée malgache ([WAXAL-NET](https://arxiv.org/html/2606.02375)). Il est donc inutilisable tel quel.
   - Une fois affiné, il devient compétitif (voir § 5).
3. **Omnilingual ASR (Meta, fin 2025, Apache 2.0)** est le successeur ouvert de MMS.
   - Il couvre `mlg_Latn` et neuf variétés régionales malgaches à code ISO propre ([lang_ids.py](https://github.com/facebookresearch/omnilingual-asr/blob/main/src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py), [tableau CER par langue](https://github.com/facebookresearch/omnilingual-asr/blob/main/per_language_results_table_7B_llm_asr.csv)).
   - C'est le candidat de base le plus intéressant sur le plan des licences.
4. **Des données malgaches de parole spontanée existent maintenant.**
   - WAXAL (Google et partenaires, 2026) et Afrivoice (Digital Umuganda) contiennent environ 95 à 102 h de malgache transcrit ([WaxalNLP](https://huggingface.co/datasets/google/WaxalNLP), [Afrivoice](https://huggingface.co/datasets/DigitalUmuganda/Afrivoice)).
   - **Il s'agit très probablement des mêmes enregistrements** (voir § 6). Il faut en tenir compte pour éviter la contamination entre entraînement et test.
5. **FLEURS ne contient pas de malgache.** Common Voice a une locale `mg` à **0 heure** (vérifié le 8/11/2026, § 6). On ne peut donc pas s'appuyer sur ces deux sources.
6. **Les meilleurs résultats publiés** sont ceux de modèles affinés sur WAXAL : **11,7 % de WER** pour Omnilingual LLM et **16,4 à 18,8 %** pour les modèles « edge » de 300 M de paramètres ([WAXAL-NET](https://arxiv.org/html/2606.02375)).
   - Ce jeu de test est fait de parole spontanée décrivant des images, enregistrée sur smartphone à 16 kHz.
   - **Ces chiffres ne prédisent pas la performance de FANILO** : appels téléphoniques à 8 kHz, milieu rural, vocabulaire médical, adolescentes, bruit ambiant.
7. **Aucun gagnant n'est désigné ici.** La recommandation est une évaluation en trois étapes sur un corpus FANILO réel (§ 8 et 9). Dans tous les cas, **la transcription ne doit jamais déclencher seule une alerte, ni l'empêcher** (§ 10).

---

## 2. Avertissement méthodologique

- **Lecture contre spontané** : la plupart des benchmarks multilingues (FLEURS, MMS-lab à partir de lectures bibliques) mesurent de la **parole lue**, propre et enregistrée au micro. Les WER publiés sur ces jeux sont systématiquement plus bas que sur de la parole spontanée.
  - Même WAXAL, pourtant spontané, est de la parole **sollicitée par une image**, avec des phrases descriptives courtes ([carte WaxalNLP](https://huggingface.co/datasets/google/WaxalNLP), [Professor/malagasy-speech-data](https://huggingface.co/datasets/Professor/malagasy-speech-data)).
  - Ce n'est pas une conversation de santé entre une agente communautaire et une adolescente.
- **Téléphonie** : les modèles cités attendent de l'audio à **16 kHz**. La téléphonie classique (IVR via RapidPro et opérateur) est en bande étroite à 8 kHz, avec compression codec.
  - Aucune source trouvée ne publie de résultats malgaches en 8 kHz.
  - Exemples de cette attente de 16 kHz : `SAMPLE_RATE = 16000` dans [whisper/audio.py](https://github.com/openai/whisper/blob/main/whisper/audio.py) ; « audio data is sampled to 16000 » dans la [carte mms-1b-all](https://huggingface.co/facebook/mms-1b-all).
- **Normalisation du texte** : un même modèle peut afficher 20,78 % ou 13,1 % de WER selon que l'on retire ou non la ponctuation et la casse. C'est ce que reconnaît l'auteur de [Flo976/whisper-malagasy-medium](https://huggingface.co/Flo976/whisper-malagasy-medium). On ne compare deux chiffres que s'ils utilisent la même normalisation et le même jeu de test.
- **Versions d'articles** : les chiffres de WAXAL-NET diffèrent entre la v1 et la v2 de l'article, et entre l'article et les cartes de modèles Hugging Face, qui utilisent un filtrage différent du jeu de test. Cette note cite la **v2 (21 octobre 2026)** et signale les écarts.
- **Modèles communautaires** : leurs cartes Hugging Face sont **autodéclaratives**. Ni le jeu de test, ni l'absence de fuite entre entraînement et test, ni la licence des données ne sont audités.

---

## 3. Fiches modèles

### 3.1 OpenAI Whisper (tiny → large-v3, turbo)

| Élément | Constat | Source |
|---|---|---|
| Licence | MIT (dépôt GitHub). Les cartes HF de `whisper-large-v3` et `whisper-small` indiquent Apache 2.0, `whisper-large-v3-turbo` MIT. Ces deux licences sont permissives. | [GitHub](https://github.com/openai/whisper), [HF large-v3](https://huggingface.co/openai/whisper-large-v3), [HF turbo](https://huggingface.co/openai/whisper-large-v3-turbo) |
| Tailles | tiny 39 M (~1 Go VRAM), base 74 M, small 244 M (~2 Go), medium 769 M (~5 Go), large 1 550 M (~10 Go), turbo 809 M (~6 Go, ~8x plus rapide que large) | [README Whisper](https://github.com/openai/whisper) |
| Turbo | « not trained for translation tasks », mais fait de la transcription multilingue | [README Whisper](https://github.com/openai/whisper) |
| Malagasy | Code `mg` présent dans le tokenizer. **0,2 h** de données de transcription et 2 h de traduction en malgache à l'entraînement. | [tokenizer.py](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py), [arXiv 2212.04356, annexe E](https://arxiv.org/abs/2212.04356) |
| Résultat publié (zéro-shot) | Whisper-large-v3 : **100,8 % WER** sur le test WAXAL malgache (spontané) | [WAXAL-NET v2, tableau 2](https://arxiv.org/html/2606.02375) |
| Résultat publié (affiné) | Whisper-Small affiné sur WAXAL : 18,8 % WER / 4,6 % CER. Whisper-Tiny : 24,0 % / 7,4 %. | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |
| Hors ligne / Android | Écosystème mature : whisper.cpp (MIT, exemple Android), sherpa-onnx (Android) | [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) |
| CPU (mesuré sur luganda, pas sur malgache) | Whisper-Tiny : RTF 0,10 (clip de 10 s), 1,0 Go RAM. Whisper-Small : RTF 0,61, 1,9 Go. Mono-thread fp32. | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |

**Lecture** : Whisper sans affinage est à exclure pour le malgache. Après affinage, il reste une option sérieuse grâce à sa licence et à son outillage mobile. L'écart avec MMS-300M n'est pas significatif pour le malgache selon WAXAL-NET.

### 3.2 Meta MMS (mms-1b-all, mms-300m, adaptateurs, MMS-TTS)

| Élément | Constat | Source |
|---|---|---|
| Licence | **CC-BY-NC 4.0** (« The MMS code and model weights are released under the CC-BY-NC 4.0 license ») | [README MMS](https://github.com/facebookresearch/fairseq/blob/main/examples/mms/README.md) |
| Cartes HF | `mms-1b-all`, `mms-300m`, `mms-tts-mlg` : cc-by-nc-4.0 | [mms-1b-all](https://huggingface.co/facebook/mms-1b-all), [mms-300m](https://huggingface.co/facebook/mms-300m), [mms-tts-mlg](https://huggingface.co/facebook/mms-tts-mlg) |
| Malagasy | `mlg` dans la liste des langues de `mms-1b-all` (1 162 langues, adaptateurs par langue) | [mms-1b-all](https://huggingface.co/facebook/mms-1b-all) |
| Données | MMS-lab, à partir d'enregistrements de lectures du Nouveau Testament (donc parole lue, registre religieux), plus FLEURS, CV, VP et MLS pour `mms-1b-all` | [README MMS](https://github.com/facebookresearch/fairseq/blob/main/examples/mms/README.md), [Pratap et al., arXiv 2305.13516](https://arxiv.org/abs/2305.13516) |
| Taille | ~1 B paramètres (`mms-1b-all`), 300 M (`mms-300m`, pré-entraîné seulement) | [mms-1b-all](https://huggingface.co/facebook/mms-1b-all) |
| Résultat publié (zéro-shot) | MMS-1B : **41,0 % WER** sur le test WAXAL malgache | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |
| Résultat publié (affiné) | MMS-300M affiné sur WAXAL : **17,6 % WER / 3,4 % CER** (article v2). La carte du modèle publié annonce 12,8 % / 2,8 % sur un test filtré (≥ 1,5 s, ≥ 4 mots/s). | [WAXAL-NET v2](https://arxiv.org/html/2606.02375), [waxal-benchmarking/mms-300m-waxal-mlg](https://huggingface.co/waxal-benchmarking/mms-300m-waxal-mlg) |
| CPU (luganda) | MMS-300M : RTF 0,24, 2,8 Go RAM | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |
| MMS-TTS | Un modèle VITS par langue, `mms-tts-mlg` existe, CC-BY-NC 4.0 | [mms-tts-mlg](https://huggingface.co/facebook/mms-tts-mlg) |

**Lecture** : techniquement solide, mais la licence **non commerciale** bloque toute pérennisation hors recherche. Cela vaut aussi pour les dérivés, par exemple `waxal-benchmarking/mms-300m-waxal-mlg`, également cc-by-nc-4.0. Il est à utiliser **uniquement comme référence de comparaison** dans un cadre de recherche, jamais comme brique livrée.

### 3.3 wav2vec 2.0 / XLS-R

| Élément | Constat | Source |
|---|---|---|
| Licence | Apache 2.0 (`wav2vec2-xls-r-300m`, `wav2vec2-large-xlsr-53`) | [xls-r-300m](https://huggingface.co/facebook/wav2vec2-xls-r-300m), [xlsr-53](https://huggingface.co/facebook/wav2vec2-large-xlsr-53) |
| Nature | Encodeur **pré-entraîné auto-supervisé**, sans tête de transcription. Il faut **obligatoirement** l'affiner (CTC) sur des données transcrites. | [Babu et al., arXiv 2111.09296](https://arxiv.org/abs/2111.09296) |
| Malagasy dans le pré-entraînement | Non vérifié dans cette note (voir § 14) | — |
| Résultat publié | Modèle communautaire `malagasy-asr/malagasy-wav2vec2-kenlm-asr` (XLS-R 300M + KenLM 4-gram) : **29,03 % WER / 9,23 % CER** sur ~4,96 h de test d'un jeu « malagasy-asr-100h-split » d'origine non documentée, licence « other » | [carte HF](https://huggingface.co/malagasy-asr/malagasy-wav2vec2-kenlm-asr) |
| Effort | Pipeline CTC standard (transformers) : quelques dizaines d'heures transcrites et un GPU de 16 à 24 Go suffisent couramment pour un 300M. C'est un ordre de grandeur d'usage, non sourcé spécifiquement pour le malgache. | — |

**Lecture** : option permissive et éprouvée, mais supplantée en pratique par MMS-300M et Omnilingual W2V/CTC, qui reposent sur la même architecture avec plus de langues. Seul Omnilingual est sous licence permissive.

### 3.4 w2v-BERT 2.0 (Meta, issu de Seamless)

| Élément | Constat | Source |
|---|---|---|
| Licence | MIT | [facebook/w2v-bert-2.0](https://huggingface.co/facebook/w2v-bert-2.0) |
| Modèles malgaches dérivés | `badrex/w2v-bert-2.0-malagasy-asr` (CC-BY-4.0, « 150 hours », « in-domain WER below 11.7% »). `Flo976/w2v-bert-malagasy` (CC-BY-4.0) : 12,68 % WER avec KenLM et 14,33 % en greedy (CER 3,76 %) sur des énoncés de 2 à 8 s du test `badrex/malagasy-speech-full`. | [badrex](https://huggingface.co/badrex/w2v-bert-2.0-malagasy-asr), [Flo976](https://huggingface.co/Flo976/w2v-bert-malagasy) |
| Version CPU | `Flo976/w2v-bert-malagasy-onnx-int8` : 612 Mo, int8, « 2.6 times faster on two cores of a recent CPU », sans perte significative (+0,15 pt, IC95 [−0,10 ; +0,41]) | [carte HF](https://huggingface.co/Flo976/w2v-bert-malagasy-onnx-int8) |
| Latence | 52 ms par énoncé sur GPU, contre 259 ms pour Whisper-medium affiné (autodéclaré, GPU non précisé dans l'extrait consulté) | [Flo976/whisper-malagasy-medium](https://huggingface.co/Flo976/whisper-malagasy-medium) |
| Réserve | Le jeu `badrex/malagasy-speech-full` n'a **pas de licence déclarée** sur sa carte. Ses 34 571 clips et ses champs (genre, tranche d'âge, locale) correspondent de près à Afrivoice/WAXAL (34 293 clips malgaches). C'est probablement la même source. | [badrex/malagasy-speech-full](https://huggingface.co/datasets/badrex/malagasy-speech-full), [Professor/malagasy-speech-data](https://huggingface.co/datasets/Professor/malagasy-speech-data) |

### 3.5 Omnilingual ASR (Meta FAIR, nov. 2025, mis à jour déc. 2025)

| Élément | Constat | Source |
|---|---|---|
| Licence | **Code et modèles Apache 2.0**, corpus CC-BY-4.0 | [GitHub omnilingual-asr](https://github.com/facebookresearch/omnilingual-asr), [corpus HF](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus) |
| Langues | Plus de 1 600, avec une variante zéro-shot (`omniASR_LLM_7B_ZS`) adaptable par quelques exemples | [GitHub](https://github.com/facebookresearch/omnilingual-asr), [arXiv 2511.09690](https://arxiv.org/abs/2511.09690) |
| Malagasy | `mlg_Latn` et variétés `plt` (plateaux), `bmm` (Betsimisaraka du Nord), `msh` (Masikoro), `skg` (Sakalava), `tdx` (Tandroy-Mahafaly), `tkg` (Tesaka), `txy` (Tanosy), `xmv` (Antankarana) dans `supported_langs`. `bhr` (Bara) figure dans le tableau CER mais n'a pas été trouvé dans `lang_ids.py`. | [lang_ids.py](https://github.com/facebookresearch/omnilingual-asr/blob/main/src/omnilingual_asr/models/wav2vec2_llama/lang_ids.py), [CSV](https://github.com/facebookresearch/omnilingual-asr/blob/main/per_language_results_table_7B_llm_asr.csv) |
| CER publiés (7B LLM-ASR) | `mlg_Latn` **2,3 %** (82,6 h d'entraînement) ; `plt_Latn` 7,1 % (10,9 h) ; `skg` 8,7 % ; `msh` 10,1 % ; `txy` 14,8 % ; `tdx` 14,9 % ; `tkg` 16,4 % ; `xmv` 19,5 % ; `bmm` 20,1 % ; `bhr` 25,4 %. **Le jeu de test et le type de parole ne sont pas précisés dans le CSV.** | [CSV](https://github.com/facebookresearch/omnilingual-asr/blob/main/per_language_results_table_7B_llm_asr.csv) |
| Résultats indépendants (malgache, WAXAL) | Zéro-shot : Omni-1B CTC 42,8 %, Omni-7B LLM **21,8 %** (sur un échantillon de 500 énoncés). Affinés : Omni-CTC 16,4 %, **Omni-LLM 11,7 % WER / 2,8 % CER**, le meilleur résultat pour le malgache. | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |
| Tailles et matériel | CTC 300M (~2 Gio VRAM, RTF 0,001 sur A100), 1B (~3 Gio), 3B (~8 Gio), 7B (~15 Gio) ; LLM 300M (1,6 B paramètres au total, ~5 Gio) à 7B (~17 Gio) ; zéro-shot 7B ~20 Gio. Inférence CTC/LLM limitée à des fichiers de moins de 40 s, sauf variantes « Unlimited ». | [README](https://github.com/facebookresearch/omnilingual-asr) |
| CPU (luganda) | Omni-CTC 325M : RTF 0,24, 3,2 Go RAM. Omni-LLM 1,6 B : RTF 3,98, 10,5 Go, donc **plus lent que le temps réel sur CPU**. | [WAXAL-NET v2](https://arxiv.org/html/2606.02375) |
| Corpus | Le corpus Omnilingual (spontané, CC-BY-4.0) contient des dossiers `bhr`, `bmm`, `bzc`, `msh`, `plt`, `skg`, `tdx`, `tkg`, `txy`, `xmv`, `xmw`. Il n'y a **pas** de dossier `mlg`. | [arborescence HF](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus/tree/main/data) |

**Lecture** : c'est le meilleur compromis sur le papier entre licence, couverture dialectale et résultats. Le CTC 300M est la taille réaliste pour un serveur CPU modeste. Le LLM 7B demande un GPU. La couverture des variétés régionales est un atout unique, mais leurs CER publiés sont nettement moins bons que pour `mlg`.

### 3.6 Autres modèles vérifiés

- **SeamlessM4T v2** : CC-BY-NC 4.0 ([carte HF](https://huggingface.co/facebook/seamless-m4t-v2-large)). Il ne supporte pas le malgache selon WAXAL-NET ([v2](https://arxiv.org/html/2606.02375)). À exclure.
- **Suite WAXALNet** : plus de 100 modèles affinés. Licence CC-BY-4.0, sauf les dérivés de MMS qui restent en CC-BY-NC-4.0 ([WAXAL-NET](https://arxiv.org/html/2606.02375)). Pour le malgache : `whisper-small-waxal-mlg` et `whisper-tiny-waxal-mlg` (CC-BY-4.0), `mms-300m-waxal-mlg` (CC-BY-NC-4.0) ([organisation HF](https://huggingface.co/waxal-benchmarking)). Les conditions d'usage interdisent les usages non consentis (clonage de voix, surveillance).
- **Autres modèles communautaires malgaches trouvés sur HF**, avec licence déclarée, non audités :
  - `Flo976/whisper-malagasy-medium` (AGPL-3.0, déclaré obsolète par son auteur) ;
  - `misterkissi/whisper-small-malagasy` et `HobyTahiry/whisper-small-malagasy` (CC-BY-NC-SA-4.0) ;
  - `alphaedge-ai/whisper-medium-mlg-32768` (Apache 2.0) ;
  - `XedriX/whisper-malagasy-medium-v3` (Apache 2.0) ;
  - `joeykurek/malagasy-asr` (CC-BY-NC-4.0).
  - Recherche : [HF « malagasy »](https://huggingface.co/models?search=malagasy).
  - Aucun ne documente de test sur de la parole téléphonique ou médicale.

---

## 4. Tableau comparatif

Légende maturité : **A** = largement utilisé, outillage mature ; **B** = récent, publié par un grand laboratoire, peu de retours terrain ; **C** = communautaire ou expérimental.

| Modèle | Malagasy | Licence / OSS | Taille / matériel | Android hors ligne | Latence (sourcée) | Fine-tuning | Résultats malgaches publiés | Maturité |
|---|---|---|---|---|---|---|---|---|
| Whisper large-v3 / turbo (zéro-shot) | Code `mg`, 0,2 h d'entraînement | MIT/Apache, compatible | 1,55 B / 809 M ; ~10 / ~6 Go VRAM | Non réaliste (taille) | turbo ~8x large (relatif) | Oui | 100,8 % WER (WAXAL, spontané) | A |
| Whisper tiny/small affiné | Après affinage | MIT/Apache (CC-BY-4.0 pour WAXALNet) | 39 M / 244 M ; 1,0 / 1,9 Go RAM CPU | **Plausible** (whisper.cpp, sherpa-onnx) | RTF CPU 0,10 / 0,61 (luganda) | Oui | 24,0 / 18,8 % WER (WAXAL) | A (outillage), C (modèles malgaches) |
| MMS-1B-all | `mlg` | **CC-BY-NC, non commercial** | 1 B | Non | — | Adaptateurs | 41,0 % WER zéro-shot (WAXAL) | A |
| MMS-300M affiné | Après affinage | **CC-BY-NC** | 315 M ; 2,8 Go RAM | Possible techniquement | RTF CPU 0,24 (luganda) | Oui | 17,6 % WER (article) / 12,8 % (carte, test filtré) | B |
| XLS-R 300M affiné | Après affinage | Apache 2.0 | 300 M | Possible (ONNX) | — | Obligatoire | 29,03 % WER (communautaire, test non documenté) | A (base), C (malgache) |
| w2v-BERT 2.0 affiné | Après affinage | MIT (base), CC-BY-4.0 (dérivés) ; données sources sans licence déclarée | ~600 M (estimé d'après les 612 Mo en int8) | Possible (ONNX int8 de 612 Mo) | 52 ms/énoncé GPU (autodéclaré) | Oui | 12,68 % WER (énoncés de 2 à 8 s, badrex test) | C |
| Omnilingual CTC 300M | `mlg` + 9 variétés | **Apache 2.0** | 325 M ; ~2 Gio VRAM ; 3,2 Go RAM CPU | Possible (à prouver) | RTF CPU 0,24 (luganda) | Oui | 42,8 % (1B, zéro-shot) ; 16,4 % affiné (WAXAL) | B |
| Omnilingual LLM 7B | `mlg` + variétés | **Apache 2.0** | 7,8 B ; ~17 Gio VRAM | Non | RTF A100 0,092 | Oui (lourd) | 21,8 % zéro-shot ; 11,7 % affiné (1,6 B) ; CER 2,3 % (CSV Meta, test non précisé) | B |
| SeamlessM4T v2 | **Non** | CC-BY-NC | 2,3 B | Non | — | — | — | — |

Notes :
- Les latences CPU viennent de mesures de WAXAL-NET sur du **luganda**, en mono-thread fp32, sur une machine non précisée dans l'extrait consulté. Ce ne sont **pas** des mesures sur un smartphone Android d'entrée de gamme.
- Aucune source trouvée ne mesure la latence d'un modèle ASR malgache sur un téléphone.
- « Possible » signifie que l'outillage existe et que la taille est compatible avec la mémoire d'un smartphone, ce qui reste à démontrer sur les appareils réels des agentes (souvent 2 à 3 Go de RAM, hypothèse à vérifier).

---

## 5. Résultats publiés sur le malgache : synthèse WAXAL-NET

Source : [Olufemi et al., WAXAL-NET, arXiv 2606.02375 v2](https://arxiv.org/html/2606.02375). Le jeu de test WAXAL malgache compte 2 290 énoncés, dont 2 214 évalués (1,5 à 40 s). La parole est spontanée et sollicitée par des images. L'entraînement porte sur 94,7 h (18 526 énoncés).

| Modèle | Mode | WER % | CER % |
|---|---|---|---|
| Whisper-large-v3 | zéro-shot | 100,8 | — |
| MMS-1B | zéro-shot | 41,0 | — |
| Omnilingual-1B (CTC) | zéro-shot | 42,8 | — |
| Omnilingual-7B (LLM) | zéro-shot (500 énoncés) | 21,8 | — |
| Whisper-Tiny | affiné WAXAL | 24,0 | 7,4 |
| Whisper-Small | affiné WAXAL | 18,8 | 4,6 |
| MMS-300M | affiné WAXAL | 17,6 | 3,4 |
| Omnilingual CTC | affiné WAXAL | 16,4 | 3,5 |
| Omnilingual LLM | affiné WAXAL | **11,7** | **2,8** |

Autres constats de l'article :
- Mutualiser les 19 langues dans un modèle unique ne coûte que 0,6 à 1,0 point de WER en moyenne.
- Le décodeur LLM est environ 5 fois plus gros que le CTC et beaucoup plus lent sur CPU.
- Un audit par locuteurs natifs relève des **boucles de répétition** parmi les défaillances. C'est un mode d'échec dangereux pour une application de santé.
- Pour le malgache, les auteurs considèrent MMS-300M et Whisper-Small comme statistiquement proches.

Autres résultats isolés :
- **VoxMg** (Ramanantsoa, ICLR AfricaNLP 2023) : 10,8 h, 3 873 fichiers, 33 % de WER pour un premier modèle ([mlanthology](https://mlanthology.org/iclrw/2023/ramanantsoa2023iclrw-voxmg)). La licence et la disponibilité du jeu ne sont pas indiquées sur la page consultée.

---

## 6. Corpus audio malgaches recensés

| Corpus | Malagasy ? | Taille | Licence | Type de parole | Dialectes / métadonnées | Source |
|---|---|---|---|---|---|---|
| **WAXAL** (`google/WaxalNLP`, config `mlg_asr`) | Oui | 94,7 h d'entraînement (WAXAL-NET) ; splits train/validation/test/unlabeled | **CC-BY-SA-4.0** pour le malgache (fournisseur Digital Umuganda) selon la carte. WAXAL-NET et les cartes WAXALNet disent CC-BY-4.0 : **incohérence à lever**. | Spontanée, sollicitée par image | speaker_id, genre ; dialecte non documenté | [carte](https://huggingface.co/datasets/google/WaxalNLP), [arXiv 2602.02734](https://arxiv.org/abs/2602.02734) |
| **Afrivoice** (Digital Umuganda) | Oui | 516,21 h au total dont **102,42 h transcrites** (~400 h non transcrites, utiles pour l'adaptation auto-supervisée) | CC-BY-4.0 ; accès conditionné (gated) | Sollicitée (image ou phrase) | âge, genre, locale | [carte](https://huggingface.co/datasets/DigitalUmuganda/Afrivoice) |
| Relation WAXAL / Afrivoice | — | — | — | — | Un tiers affirme, indices à l'appui (format des speaker_id, métadonnées source), que **`mlg_asr` de WAXAL et Afrivoice sont les mêmes données** | [Professor/malagasy-speech-data](https://huggingface.co/datasets/Professor/malagasy-speech-data) |
| `badrex/malagasy-speech-full` | Oui | 34 571 clips (28 371 / 3 099 / 3 101), ~124 Go | **Non déclarée** | Non documenté (probablement Afrivoice) | genre, tranche d'âge, locale | [carte](https://huggingface.co/datasets/badrex/malagasy-speech-full) |
| **Omnilingual ASR Corpus** (Meta) | Variétés régionales seulement : `bhr`, `bmm`, `bzc`, `msh`, `plt`, `skg`, `tdx`, `tkg`, `txy`, `xmv`, `xmw` | Volume par variété non relevé | CC-BY-4.0 | **Spontanée** (réponses à des questions ouvertes), disfluences transcrites | Variété identifiée par code ISO 639-3 et glottocode | [carte](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus), [arborescence](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus/tree/main/data) |
| **FLEURS** (Google) | **Non**, aucun dossier `mg_*` parmi 102 langues | — | CC-BY-4.0 | Lue | — | [arborescence HF](https://huggingface.co/datasets/google/fleurs/tree/main/data) |
| **Common Voice** (Mozilla) | Locale `mg` créée mais **0 h enregistrée**, non ouverte à la contribution (8/11/2026) | 0 | sans objet | — | — | [API stats](https://commonvoice.mozilla.org/api/v1/stats/languages) |
| **MMS-lab** (Bible, Meta) | Oui (`mlg` dans MMS) | Non relevé | Données **non redistribuées** ; modèles CC-BY-NC | Lue, registre biblique | — | [arXiv 2305.13516](https://arxiv.org/abs/2305.13516) |
| `XedriX/malagasy-nwt-bible` | Oui | ~60 h, ~21 900 clips, plusieurs lecteurs | **Non déclarée** ; source JW.org, droits d'auteur probables | Lue, liturgique | aucun speaker_id | [carte](https://huggingface.co/datasets/XedriX/malagasy-nwt-bible) |
| VoxMg | Oui | 10,8 h | Non indiquée | Non précisé | — | [mlanthology](https://mlanthology.org/iclrw/2023/ramanantsoa2023iclrw-voxmg) |
| `Arozo/aiza-malagasy-administrative-asr` | Oui (alternance malgache/français) | 10 clips | CC-BY-NC-4.0 | Lue/auto-enregistrée | — | [carte](https://huggingface.co/datasets/Arozo/aiza-malagasy-administrative-asr) |
| WAXAL TTS | **Non** : le malgache ne figure pas parmi les 17 langues TTS | — | — | — | — | [carte WaxalNLP](https://huggingface.co/datasets/google/WaxalNLP) |

**Conséquences pour FANILO** :
- **Pas de données téléphoniques, pas de vocabulaire de santé, pas de dialectes documentés** dans les corpus malgaches standards (seul Omnilingual étiquette les variétés).
- **Risque de contamination** : WAXAL, Afrivoice, `badrex/malagasy-speech-full` et ses copies sont probablement la même source. Un modèle affiné sur l'un et testé sur l'autre surestimera sa performance. C'est une raison de plus pour constituer un **jeu de test FANILO propre**, jamais publié comme données d'entraînement.
- **Licences** : CC-BY-SA (share-alike) sur WAXAL malagasy pourrait imposer la même licence aux dérivés de données. Son effet sur des **poids de modèle** est juridiquement discuté. À faire valider (§ 14).

---

## 7. Contraintes de déploiement propres à FANILO

| Canal | Contrainte | Implication ASR |
|---|---|---|
| IVR téléphonique (RapidPro + opérateur) | Audio 8 kHz compressé, traitement côté serveur | Modèle serveur (CPU ou GPU). Rééchantillonnage vers 16 kHz obligatoire et **évaluation spécifique 8 kHz** (aucun résultat publié). |
| SMS / USSD | Pas d'audio | ASR sans objet. Ces canaux servent de **repli** quand l'ASR échoue. |
| App Android de l'agente, hors ligne | RAM et CPU limités, batterie, stockage | Seuls les modèles d'environ 300 M ou moins sont envisageables (Whisper-tiny/small, CTC 300M en int8). Faisabilité **non démontrée** pour le malgache sur appareil d'entrée de gamme. |
| App Android connectée | Envoi d'audio, réseau intermittent | File d'attente et envoi différé, ASR serveur. Pas d'exigence temps réel stricte. |

---

## 8. Stratégie recommandée en étapes

Aucun modèle n'est désigné gagnant avant l'étape 2.

**Étape 0 : cadrage (avant tout calcul)**
- Valider juridiquement la liste des licences acceptables. Recommandation : exclure CC-BY-NC du produit livré.
- Définir précisément l'usage de l'ASR. Par exemple : aide à la saisie pour l'agente, routage d'un menu vocal, détection de mots-clés de danger. Chaque usage implique des tolérances différentes.
- Décider si le pilote vise d'abord l'IVR (8 kHz, serveur) ou l'app (16 kHz).

**Étape 1 : baseline sans entraînement (2 à 4 semaines, indicatif)**
- Constituer un **petit jeu de test pilote** FANILO, voir le protocole au § 9. Ordre de grandeur : 2 à 3 h, 30 à 40 locuteurs.
- Évaluer, avec la même normalisation de texte :
  - (a) Omnilingual CTC 300M/1B avec `mlg_Latn` et `plt_Latn` ;
  - (b) Omnilingual LLM 7B en zéro-shot (GPU loué) ;
  - (c) les modèles affinés déjà publiés à licence permissive : `waxal-benchmarking/whisper-small-waxal-mlg`, `Flo976/w2v-bert-malagasy` (sous réserve de la licence des données) ;
  - (d) MMS-1B-all **en référence seulement** (recherche, non livrable).
- Mesurer aussi la latence sur la machine serveur cible et, pour les modèles ≤ 300 M, sur 2 ou 3 smartphones réellement utilisés par les agentes.

**Étape 2 : comparaison complète**
- Étendre le jeu de test (§ 9.3).
- Comparer les 2 ou 3 meilleurs candidats avec intervalles de confiance (bootstrap apparié par locuteur, comme dans [WAXAL-NET](https://arxiv.org/html/2606.02375)), par strate.
- Tester l'ajout d'un modèle de langue n-gram (KenLM) entraîné sur des textes de santé malgaches validés. Les cartes communautaires rapportent un gain de 1 à 2 points ([Flo976/w2v-bert-malagasy](https://huggingface.co/Flo976/w2v-bert-malagasy)).

**Étape 3 : fine-tuning éventuel**
- Seulement si l'étape 2 montre un écart inacceptable, notamment sur les signes de danger.
- Affiner le meilleur candidat permissif sur WAXAL/Afrivoice, plus un **corpus FANILO d'entraînement** distinct du test : parole téléphonique, vocabulaire de santé, adolescentes, variétés locales.
- Envisager l'augmentation : simulation de canal 8 kHz avec codecs AMR-NB/G.711, bruit ambiant rural.
- Pour les variétés régionales, s'appuyer sur le corpus Omnilingual (spontané, CC-BY-4.0).
- Re-mesurer sur le jeu de test gelé.

---

## 9. Protocole d'évaluation proposé

### 9.1 Principes
- **Jeu de test gelé et séparé** : locuteurs, villages et sessions disjoints de tout entraînement. Il n'est jamais publié comme jeu d'entraînement et sa version est contrôlée (hash).
- **Double transcription humaine** d'au moins 10 % du jeu pour mesurer l'accord entre annotateurs. Le WER humain sert de plancher réaliste.
- **Guide de transcription** écrit : orthographe standard du malgache officiel, traitement des emprunts français, nombres, disfluences, balises `<noise>` / `<unintelligible>` alignées sur le [corpus Omnilingual](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus).
- **Normalisation unique** avant calcul : minuscules, ponctuation retirée, nombres en lettres, apostrophes. Elle est publiée avec les scores.

### 9.2 Métriques
- **WER et CER** globaux et par strate. Le CER est utile car le malgache est agglutinant et les erreurs d'affixes gonflent le WER.
- **Rappel sur les signes de danger** (métrique principale de sécurité) :
  - établir une liste fermée de signes de danger et de leurs variantes lexicales et dialectales, validée par le comité médical : saignement, convulsions, fièvre, maux de tête sévères, vision trouble, perte de liquide, absence de mouvements du bébé, idées suicidaires, violences, etc. ;
  - pour chaque mention présente dans la référence, vérifier si elle est retrouvée dans la transcription (exacte ou par variante admise) ;
  - mesurer le **taux de faux négatifs** (mentions manquées) et, secondairement, les faux positifs.
- **Taux d'hallucination et de répétition** : segments transcrits sans parole, boucles. WAXAL-NET signale ce mode d'échec.
- **Latence** (RTF, p50/p95) sur le matériel cible et **empreinte mémoire**.

### 9.3 Stratification
| Axe | Modalités minimales |
|---|---|
| Variété | merina/plateaux (`plt`), parler(s) du Bongolava (**à documenter sur le terrain**), au moins deux variétés côtières selon les zones d'extension prévues |
| Âge | adolescentes (âge exact selon le cadre du consentement, § 11), adultes |
| Genre | femmes, hommes (agents, conjoints) ; majorité féminine attendue |
| Canal | téléphone 8 kHz réel (via l'opérateur et RapidPro), smartphone 16 kHz |
| Environnement | calme, bruit domestique ou extérieur |
| Style | lu (phrases de santé scriptées), spontané (questions ouvertes, jeux de rôle de consultation) |
| Vocabulaire | général, santé maternelle et adolescente, signes de danger |

### 9.4 Taille d'échantillon indicative (à affiner après le pilote)
- **Unité statistique = le locuteur**, pas l'énoncé, car les énoncés d'un même locuteur sont corrélés. Viser **au moins 20 à 30 locuteurs par strate principale** (variété × canal), avec environ 10 min de parole chacun.
  - Pour 3 variétés × 2 canaux, cela donne environ **150 à 200 locuteurs et 25 à 35 h** au total.
  - Pour comparaison, le test WAXAL malgache compte environ 2 200 énoncés ([WAXAL-NET](https://arxiv.org/html/2606.02375)).
- **Signes de danger** : pour estimer un rappel attendu d'environ 90 % avec une demi-largeur d'IC à 95 % de ±5 points, il faut n ≈ 1,96² × 0,9 × 0,1 / 0,05² ≈ **140 mentions** par strate analysée. Pour ±3 points, n ≈ **385**.
  - Les mentions spontanées étant rares, prévoir des **scénarios scriptés et des jeux de rôle** contenant des signes de danger. Prévoir au minimum environ 400 mentions au total et environ 140 par variété principale.
- Ces chiffres sont des **ordres de grandeur de planification**, à recalculer avec la variance inter-locuteurs observée au pilote.

---

## 10. Conséquence architecturale : l'ASR ne décide jamais seul

- Avec un WER de 10 à 20 % dans le meilleur cas publié, sur de la parole plus facile que celle de FANILO, **une mention de danger sur dix ou plus peut être manquée ou déformée**. Ce rapport est indicatif : le rappel sur les mots-clés ne se déduit pas mécaniquement du WER.
- **Règles de conception** :
  1. La transcription est une **entrée parmi d'autres**, jamais l'unique déclencheur ni l'unique inhibiteur d'une alerte.
  2. Les **questions de danger critiques** passent par des réponses fermées robustes : touches DTMF en IVR, boutons dans l'app, oui/non confirmés. Des **règles déterministes** s'appliquent ensuite (arbre de triage validé médicalement).
  3. Une **faible confiance**, un silence, une transcription vide ou une boucle de répétition déclenchent une reformulation, une question fermée ou un **transfert humain** (agente, centre de santé). Ils ne valent jamais un « pas de danger ».
  4. Le seuil de détection penche vers les **faux positifs** plutôt que les faux négatifs.
  5. Les événements où l'ASR a été déterminant sont journalisés, sans conserver l'audio brut (§ 11), pour l'audit.

---

## 11. Éthique, consentement et protection des données

- **Cadre légal** : loi n° 2014-038 du 9 janvier 2015 sur la protection des données à caractère personnel ([texte, Assemblée nationale](https://www.assemblee-nationale.mg/wp-content/uploads/2020/11/Loi-n°2014-038-sur-la-protection-des-données-à-Kre-personnel.pdf), [DLA Piper](https://www.dlapiperdataprotection.com/index.html?t=law&c=MG)).
  - Le statut opérationnel de la **CMIL** (Commission Malagasy de l'Informatique et des Libertés) est rapporté de façon contradictoire selon les sources ([L'Express, févr. 2025](https://www.lexpress.mg/2025/02/gouvernance-numerique-les-donnees.html) ; [NewsMada](https://newsmada.com/?p=169904)). À vérifier.
  - Les dispositions précises sur les données sensibles (santé) n'ont pas été analysées dans cette note.
- **La voix est une donnée personnelle**, potentiellement biométrique. Combinée à un contenu de santé (grossesse, sexualité, violences), elle devient une donnée **sensible**.
- **Séparation stricte** :
  - **Corpus de recherche ASR** : participants volontaires recrutés explicitement pour cela, contenu scripté ou jeux de rôle sans données de santé réelles autant que possible, consentement spécifique.
  - **Suivi clinique** : les appels réels des bénéficiaires **ne sont pas versés au corpus** par défaut. Toute réutilisation exigerait un consentement distinct, révocable, et l'avis d'un comité d'éthique.
- **Mineures** : consentement parental et assentiment de l'adolescente, adaptés à l'âge, avec un protocole pour les situations où l'implication parentale pose un risque (violences). Ce point est à valider avec le comité d'éthique et le ministère de la Santé.
- **Minimisation** :
  - audio brut supprimé dès que la transcription est validée et contrôlée en qualité ;
  - durée maximale définie et documentée ;
  - pseudonymisation des métadonnées (âge en tranches, commune plutôt que village) ;
  - retrait des noms propres dans les transcriptions.
- **Consentement éclairé** en malgache, lu à voix haute si besoin. Il précise la finalité, la durée, le droit de retrait et l'éventuelle publication ouverte. Si le corpus doit être publié, cela doit être dit explicitement et pouvoir être refusé tout en participant.
- **Interdits d'usage** : pas de clonage de voix, pas d'identification de locuteurs, à l'image des conditions WAXALNet ([WAXAL-NET](https://arxiv.org/html/2606.02375)).
- **Rétribution et retour aux communautés** : compensation juste des participants et des transcripteurs malgaches, restitution des résultats.

---

## 12. TTS (synthèse vocale)

- **Cahier des charges** : les messages médicaux sensibles (signes de danger, conduite à tenir, orientation, santé sexuelle et reproductive) sont diffusés à partir d'**enregistrements humains** validés par le comité médical, par des voix locales, avec des variantes par variété si nécessaire.
- **Options TTS trouvées pour le malgache** :
  - `facebook/mms-tts-mlg` : VITS, **CC-BY-NC 4.0**, donc non livrable ([carte](https://huggingface.co/facebook/mms-tts-mlg)). Ses dérivés (`hasiniaina/mms_malagasy_finetuning`, `rleo/mms-tts-mlg-malaga-GGUF`) héritent de CC-BY-NC.
  - WAXAL TTS ne couvre pas le malgache ([carte](https://huggingface.co/datasets/google/WaxalNLP)).
  - `Nelchael/tts-malagasy` existe sans licence déclarée.
  - Aucun TTS malgache à licence permissive et à qualité documentée n'a été identifié.
- **Usage TTS envisageable**, après validation : contenus non critiques et dynamiques (date de rendez-vous, prénom de l'agente). Même dans ce cas, il vaut mieux concaténer des segments enregistrés par des humains (nombres, jours, mois).
- **Piste** : un TTS permissif pourrait être entraîné sur des enregistrements studio FANILO avec une locutrice consentante et une licence explicite. Ce serait un projet à part entière, pas un prérequis du pilote.

---

## 13. Limites de cette note

- **Aucune mesure propre** : tous les chiffres sont repris de publications ou de cartes de modèles, sans reproduction.
- **Transposabilité nulle par défaut** : aucun résultat publié ne porte sur de la parole téléphonique 8 kHz, du vocabulaire de santé, des adolescentes ou les parlers du Bongolava.
- **Cartes communautaires autodéclaratives**, non auditées. Certaines ont des jeux de test d'origine inconnue ou contaminés.
- **Le tableau CER d'Omnilingual** (2,3 % pour `mlg`) ne précise pas le jeu de test. Il est sans doute plus favorable (parole lue possible) que WAXAL (21,8 % WER en zéro-shot pour le 7B).
- **Latences CPU** mesurées sur du luganda, sur une machine non précisée. Aucune mesure sur smartphone.
- **Versions** : les chiffres de WAXAL-NET varient entre la v1 et la v2 de l'article et les cartes HF. Cette note cite la v2.
- **Volatilité** : le domaine évolue vite. Nouveaux modèles et versions sont à revérifier avant toute décision (date de relevé : 8 novembre 2026).
- **Analyse juridique non faite** : interprétation des licences share-alike sur des poids de modèles, droits des enregistrements bibliques, dispositions de la loi 2014-038 sur les données de santé.
- **Dialectologie** : la correspondance entre les codes ISO (`plt`, `skg`, etc.) et les parlers réellement présents au Bongolava n'est pas établie ici.

## 14. À vérifier ou valider par l'équipe

1. **Licences (juriste)** :
   - confirmer l'exclusion de CC-BY-NC du produit ;
   - effet du **CC-BY-SA-4.0** (WAXAL malagasy) contre CC-BY-4.0 (Afrivoice, cartes WAXALNet) sur nos modèles dérivés ;
   - licence réelle de `badrex/malagasy-speech-full`.
2. **Identité des corpus** : vérifier par hash ou speaker_id que WAXAL `mlg_asr`, Afrivoice malagasy et `badrex/malagasy-speech-full` sont la même source, et donc les risques de contamination.
3. **Jeu de test Omnilingual** : retrouver dans l'article ([arXiv 2511.09690](https://arxiv.org/abs/2511.09690)) le jeu d'évaluation et le type de parole derrière le CER de 2,3 % pour `mlg_Latn`.
4. **XLS-R** : vérifier si le malgache figure dans les données de pré-entraînement (VoxLingua107, etc.), dans [arXiv 2111.09296](https://arxiv.org/abs/2111.09296).
5. **Bongolava** : avec les équipes terrain, identifier les parlers effectivement utilisés (plateaux, migrants d'autres régions) pour fixer les strates dialectales.
6. **Matériel** : inventorier les smartphones des agentes (RAM, CPU, version d'Android) et le serveur cible (CPU seul ou GPU disponible, hébergement à Madagascar ou à l'étranger, ce qui pose aussi une question de transfert de données).
7. **Téléphonie** : obtenir de l'opérateur ou de RapidPro des échantillons réels pour connaître le codec et la fréquence d'échantillonnage du flux IVR.
8. **CMIL** : vérifier son statut opérationnel et les formalités (déclaration ou autorisation) pour un corpus vocal impliquant des mineures et des données de santé.
9. **Comité d'éthique** : soumettre le protocole de collecte (consentement et assentiment des mineures, minimisation, durée de conservation).
10. **Liste des signes de danger** et de leurs variantes lexicales dialectales : à valider par le comité médical avant de construire le jeu de test.
11. **Modèles communautaires** : contacter les auteurs (Flo976, badrex, malagasy-asr) pour connaître l'origine des données et les conditions de test, et une éventuelle collaboration.

---

## 15. Sources principales

- Whisper : [GitHub](https://github.com/openai/whisper) · [tokenizer.py](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py) · [arXiv 2212.04356](https://arxiv.org/abs/2212.04356) · [HF large-v3](https://huggingface.co/openai/whisper-large-v3) · [HF large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo)
- MMS : [README fairseq/MMS](https://github.com/facebookresearch/fairseq/blob/main/examples/mms/README.md) · [arXiv 2305.13516](https://arxiv.org/abs/2305.13516) · [mms-1b-all](https://huggingface.co/facebook/mms-1b-all) · [mms-300m](https://huggingface.co/facebook/mms-300m) · [mms-tts-mlg](https://huggingface.co/facebook/mms-tts-mlg)
- XLS-R : [arXiv 2111.09296](https://arxiv.org/abs/2111.09296) · [wav2vec2-xls-r-300m](https://huggingface.co/facebook/wav2vec2-xls-r-300m)
- w2v-BERT 2.0 : [facebook/w2v-bert-2.0](https://huggingface.co/facebook/w2v-bert-2.0)
- Omnilingual ASR : [GitHub](https://github.com/facebookresearch/omnilingual-asr) · [arXiv 2511.09690](https://arxiv.org/abs/2511.09690) · [corpus](https://huggingface.co/datasets/facebook/omnilingual-asr-corpus) · [CER par langue](https://github.com/facebookresearch/omnilingual-asr/blob/main/per_language_results_table_7B_llm_asr.csv)
- WAXAL / WAXAL-NET : [arXiv 2602.02734](https://arxiv.org/abs/2602.02734) · [google/WaxalNLP](https://huggingface.co/datasets/google/WaxalNLP) · [arXiv 2606.02375 (v2)](https://arxiv.org/html/2606.02375) · [waxal-benchmarking](https://huggingface.co/waxal-benchmarking)
- Afrivoice : [DigitalUmuganda/Afrivoice](https://huggingface.co/datasets/DigitalUmuganda/Afrivoice)
- Modèles communautaires : [badrex/w2v-bert-2.0-malagasy-asr](https://huggingface.co/badrex/w2v-bert-2.0-malagasy-asr) · [Flo976/w2v-bert-malagasy](https://huggingface.co/Flo976/w2v-bert-malagasy) · [Flo976/w2v-bert-malagasy-onnx-int8](https://huggingface.co/Flo976/w2v-bert-malagasy-onnx-int8) · [Flo976/whisper-malagasy-medium](https://huggingface.co/Flo976/whisper-malagasy-medium) · [malagasy-asr/malagasy-wav2vec2-kenlm-asr](https://huggingface.co/malagasy-asr/malagasy-wav2vec2-kenlm-asr)
- Autres corpus : [FLEURS](https://huggingface.co/datasets/google/fleurs/tree/main/data) · [Common Voice stats API](https://commonvoice.mozilla.org/api/v1/stats/languages) · [VoxMg](https://mlanthology.org/iclrw/2023/ramanantsoa2023iclrw-voxmg) · [XedriX/malagasy-nwt-bible](https://huggingface.co/datasets/XedriX/malagasy-nwt-bible) · [Professor/malagasy-speech-data](https://huggingface.co/datasets/Professor/malagasy-speech-data)
- Outillage mobile : [whisper.cpp](https://github.com/ggml-org/whisper.cpp) · [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- Cadre légal : [Loi 2014-038 (Assemblée nationale)](https://www.assemblee-nationale.mg/wp-content/uploads/2020/11/Loi-n°2014-038-sur-la-protection-des-données-à-Kre-personnel.pdf) · [DLA Piper](https://www.dlapiperdataprotection.com/index.html?t=law&c=MG)
