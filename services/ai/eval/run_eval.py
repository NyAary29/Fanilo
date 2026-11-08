"""Harnais d'évaluation reproductible : WER/CER globaux et par strate, faux négatifs sur les
signes de danger. Sorties JSON et Markdown.

Exemples (depuis services/ai) :

    # Hypothèses déjà présentes dans le manifeste (exemple factice fourni) :
    uv run python -m eval.run_eval --manifest eval/samples/manifest.example.jsonl \
        --out-json /tmp/rapport.json --out-md /tmp/rapport.md

    # Hypothèses produites séparément :
    uv run python -m eval.run_eval --manifest test.jsonl --predictions hyp.jsonl ...

    # Transcription par le backend configuré (extra [asr], FANILO_AI_ASR_BACKEND...) :
    uv run --extra asr python -m eval.run_eval --manifest test.jsonl --transcribe ...

Voir le protocole : docs/ia/benchmark-asr-malgache.md, § 9.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from app.config import DEFAULT_LEXICON_PATH
from app.nlu.lexicon import LexiconIntentClassifier
from eval.manifest import ManifestRow, load_manifest, load_predictions
from eval.metrics import (
    NORMALIZATION_DESCRIPTION,
    score_utterances,
    stratified_report,
)
from eval.report import to_markdown

WARNING = (
    "Ces chiffres ne valent que pour ce manifeste. Ils ne constituent pas une "
    "revendication de performance tant que le protocole (jeu gelé, double transcription, "
    "effectifs suffisants par strate) n'a pas été respecté."
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _transcribe_all(rows: list[ManifestRow], base_dir: Path) -> tuple[dict[str, str], str]:
    """Transcrit chaque audio avec le backend configuré (lecture en mémoire, rien n'est écrit)."""
    from app.asr.factory import build_asr_backend
    from app.audio import AudioInput, normalize_mime
    from app.config import get_settings

    settings = get_settings()
    backend = build_asr_backend(settings)
    if not backend.available:
        raise SystemExit(backend.unavailable_reason)
    hypotheses: dict[str, str] = {}
    for row in rows:
        path = Path(row.audio_path)
        if not path.is_absolute():
            path = base_dir / path
        mime = normalize_mime("audio/" + path.suffix.lstrip(".").lower())
        result = backend.transcribe(
            AudioInput(data=path.read_bytes(), mime_type=mime, language="mg"),
            settings.max_audio_seconds,
        )
        hypotheses[row.utt_id] = result.text
    return hypotheses, backend.describe()


def build_report(
    manifest_path: Path,
    *,
    predictions_path: Path | None = None,
    transcribe: bool = False,
    lexicon_path: Path = DEFAULT_LEXICON_PATH,
    strip_accents: bool = False,
    min_speakers: int = 20,
    asr_system: str | None = None,
) -> dict[str, Any]:
    rows = load_manifest(manifest_path)
    if transcribe:
        hypotheses, system = _transcribe_all(rows, manifest_path.parent)
        source = "transcription par le backend configuré"
    elif predictions_path is not None:
        preds = load_predictions(predictions_path)
        hypotheses = {r.utt_id: preds.get(r.utt_id, preds.get(r.audio_path, "")) for r in rows}
        system = asr_system or "inconnu (fichier de prédictions)"
        source = f"fichier de prédictions `{predictions_path}`"
    else:
        missing = [r.utt_id for r in rows if r.hypothesis is None]
        if missing:
            raise SystemExit(
                f"{len(missing)} énoncé(s) sans colonne `hypothesis` : fournir --predictions "
                "ou --transcribe."
            )
        hypotheses = {r.utt_id: r.hypothesis or "" for r in rows}
        system = asr_system or "inconnu (colonne hypothesis du manifeste)"
        source = "colonne `hypothesis` du manifeste"

    classifier = LexiconIntentClassifier.from_path(lexicon_path)

    def detect(text: str, module: str) -> list[str]:
        return classifier.classify(text, module).sign_codes

    scored, expected_source = score_utterances(
        rows, hypotheses, detect, strip_accents=strip_accents
    )
    report = stratified_report(scored, min_speakers=min_speakers)
    report["meta"] = {
        "generated_at": datetime.now(UTC).isoformat(timespec="seconds"),
        "manifest": str(manifest_path),
        "manifest_sha256": _sha256(manifest_path),
        "hypothesis_source": source,
        "asr_system": system,
        "sign_detector": classifier.model_id,
        "sign_detector_is_demo": classifier.is_demo,
        "expected_signs_source": expected_source,
        "normalization": NORMALIZATION_DESCRIPTION.format(
            accents="retirés" if strip_accents else "conservés"
        ),
        "min_speakers": min_speakers,
        "warning": WARNING,
    }
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Évaluation ASR (WER/CER) et signes de danger.")
    parser.add_argument("--manifest", type=Path, required=True)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--predictions", type=Path)
    group.add_argument("--transcribe", action="store_true")
    parser.add_argument("--asr-system", help="nom du système évalué (pour le rapport)")
    parser.add_argument("--lexicon", type=Path, default=DEFAULT_LEXICON_PATH)
    parser.add_argument("--strip-accents", action="store_true")
    parser.add_argument("--min-speakers", type=int, default=20)
    parser.add_argument("--out-json", type=Path)
    parser.add_argument("--out-md", type=Path)
    args = parser.parse_args(argv)

    report = build_report(
        args.manifest,
        predictions_path=args.predictions,
        transcribe=args.transcribe,
        lexicon_path=args.lexicon,
        strip_accents=args.strip_accents,
        min_speakers=args.min_speakers,
        asr_system=args.asr_system,
    )
    as_json = json.dumps(report, ensure_ascii=False, indent=2)
    markdown = to_markdown(report)
    if args.out_json:
        args.out_json.write_text(as_json + "\n", encoding="utf-8")
    if args.out_md:
        args.out_md.write_text(markdown, encoding="utf-8")
    if not args.out_json and not args.out_md:
        sys.stdout.write(markdown)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
