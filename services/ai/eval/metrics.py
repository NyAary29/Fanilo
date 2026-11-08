"""Calcul des métriques : WER, CER (jiwer), globaux et par strate, et faux négatifs sur les
signes de danger.

Conventions
-----------
- WER et CER sont calculés **au niveau du corpus** (somme des erreurs / somme des mots ou
  caractères de référence), pas en moyenne d'énoncés.
- Normalisation avant calcul (publiée dans le rapport) : minuscules, apostrophes et
  ponctuation remplacées par une espace, espaces réduites. Les accents sont **conservés**
  par défaut (option `strip_accents`). Les nombres ne sont pas convertis en lettres : le
  guide de transcription doit fixer cette convention.
- Les énoncés dont la référence est vide après normalisation sont exclus du WER/CER et
  comptés à part.
- Signes de danger : une « mention » est un couple (énoncé, code de signe). Taux de faux
  négatifs = mentions attendues non retrouvées / mentions attendues.
- Le nombre de locuteurs distincts est donné pour chaque strate : c'est l'unité
  statistique pertinente (docs/ia/benchmark-asr-malgache.md, § 9.4).
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass

import jiwer

from eval.manifest import STRATA_AXES, ManifestRow

_APOSTROPHES_RE = re.compile("['’‘ʼ`´]")
_PUNCT_RE = re.compile(r"[^\w\s<>]|_", re.UNICODE)

NORMALIZATION_DESCRIPTION = (
    "minuscules ; apostrophes et ponctuation -> espace (balises <...> conservées) ; "
    "espaces réduites ; accents {accents} ; nombres non convertis"
)


def normalize_for_wer(text: str, *, strip_accents: bool = False) -> str:
    lowered = text.casefold()
    if strip_accents:
        lowered = "".join(
            ch for ch in unicodedata.normalize("NFKD", lowered) if not unicodedata.combining(ch)
        )
    else:
        lowered = unicodedata.normalize("NFC", lowered)
    lowered = _APOSTROPHES_RE.sub(" ", lowered)
    lowered = _PUNCT_RE.sub(" ", lowered)
    return " ".join(lowered.split())


@dataclass(frozen=True)
class ScoredUtterance:
    utt_id: str
    speaker_id: str
    strata: dict[str, str]
    reference: str  # normalisée
    hypothesis: str  # normalisée
    expected_signs: frozenset[str]
    predicted_signs: frozenset[str]


def error_rates(pairs: Sequence[tuple[str, str]]) -> dict[str, object]:
    """WER/CER corpus sur des couples (référence, hypothèse) déjà normalisés."""
    usable = [(r, h) for r, h in pairs if r.strip()]
    excluded = len(pairs) - len(usable)
    if not usable:
        return {
            "n_utterances": 0,
            "n_excluded_empty_reference": excluded,
            "wer": None,
            "cer": None,
        }
    refs = [r for r, _ in usable]
    hyps = [h for _, h in usable]
    words = jiwer.process_words(refs, hyps)
    chars = jiwer.process_characters(refs, hyps)
    n_ref_words = words.hits + words.substitutions + words.deletions
    n_ref_chars = chars.hits + chars.substitutions + chars.deletions
    return {
        "n_utterances": len(usable),
        "n_excluded_empty_reference": excluded,
        "n_reference_words": n_ref_words,
        "n_reference_chars": n_ref_chars,
        "wer": round(words.wer, 6),
        "cer": round(chars.cer, 6),
        "word_substitutions": words.substitutions,
        "word_deletions": words.deletions,
        "word_insertions": words.insertions,
    }


def danger_sign_rates(utterances: Iterable[ScoredUtterance]) -> dict[str, object]:
    tp = fn = fp = 0
    utt_with_expected = utt_missed_all = 0
    for u in utterances:
        tp += len(u.expected_signs & u.predicted_signs)
        fn += len(u.expected_signs - u.predicted_signs)
        fp += len(u.predicted_signs - u.expected_signs)
        if u.expected_signs:
            utt_with_expected += 1
            if not (u.expected_signs & u.predicted_signs):
                utt_missed_all += 1
    expected = tp + fn
    return {
        "expected_mentions": expected,
        "true_positives": tp,
        "false_negatives": fn,
        "false_positives": fp,
        "false_negative_rate": round(fn / expected, 6) if expected else None,
        "recall": round(tp / expected, 6) if expected else None,
        "utterances_with_expected_sign": utt_with_expected,
        "utterances_all_signs_missed": utt_missed_all,
    }


def _group_metrics(utterances: Sequence[ScoredUtterance]) -> dict[str, object]:
    rates = error_rates([(u.reference, u.hypothesis) for u in utterances])
    return {
        "n_speakers": len({u.speaker_id for u in utterances}),
        "n_utterances_total": len(utterances),
        **rates,
        "danger_signs": danger_sign_rates(utterances),
    }


def stratified_report(
    utterances: Sequence[ScoredUtterance],
    *,
    axes: Sequence[str] = STRATA_AXES,
    min_speakers: int = 20,
) -> dict[str, object]:
    """Métriques globales puis, pour chaque axe, par modalité.

    Une strate avec moins de `min_speakers` locuteurs est marquée `insufficient_speakers` :
    ses chiffres ne doivent pas être interprétés.
    """
    by_axis: dict[str, dict[str, object]] = {}
    for axis in axes:
        groups: dict[str, list[ScoredUtterance]] = {}
        for u in utterances:
            groups.setdefault(u.strata.get(axis, "inconnu"), []).append(u)
        by_axis[axis] = {}
        for value in sorted(groups):
            metrics = _group_metrics(groups[value])
            metrics["insufficient_speakers"] = metrics["n_speakers"] < min_speakers
            by_axis[axis][value] = metrics
    overall = _group_metrics(utterances)
    overall["insufficient_speakers"] = overall["n_speakers"] < min_speakers
    return {"overall": overall, "by_stratum": by_axis}


def score_utterances(
    rows: Sequence[ManifestRow],
    hypotheses: dict[str, str],
    sign_detector: Callable[[str, str], Sequence[str]],
    *,
    strip_accents: bool = False,
) -> tuple[list[ScoredUtterance], str]:
    """Associe références, hypothèses et signes. Renvoie aussi la source des signes attendus."""
    scored: list[ScoredUtterance] = []
    annotated = 0
    for row in rows:
        hyp_raw = hypotheses.get(row.utt_id, "")
        if row.expected_sign_codes is not None:
            expected = frozenset(row.expected_sign_codes)
            annotated += 1
        else:
            expected = frozenset(sign_detector(row.reference, row.module))
        predicted = frozenset(sign_detector(hyp_raw, row.module))
        scored.append(
            ScoredUtterance(
                utt_id=row.utt_id,
                speaker_id=row.speaker_id,
                strata=row.strata,
                reference=normalize_for_wer(row.reference, strip_accents=strip_accents),
                hypothesis=normalize_for_wer(hyp_raw, strip_accents=strip_accents),
                expected_signs=expected,
                predicted_signs=predicted,
            )
        )
    if annotated == len(rows):
        source = "annotation"
    elif annotated == 0:
        source = "classifier_on_reference"
    else:
        source = "mixed"
    return scored, source
