"""Lecture des manifestes d'évaluation (CSV ou JSONL).

Colonnes obligatoires : `audio_path`, `reference`, `speaker_id`, `dialect`, `age_group`,
`gender`, `channel`, `speech_type`. Une valeur de strate vide est remplacée par `inconnu`.

Colonnes facultatives :
- `utt_id` : identifiant de l'énoncé (par défaut : `audio_path`) ;
- `module` : `reny` (défaut) ou `tanora`, transmis au classifieur ;
- `hypothesis` : transcription déjà produite par un système (sinon, voir `--predictions`
  ou `--transcribe`) ;
- `expected_sign_codes` : codes de signes annotés par un humain dans la référence
  (liste JSON, ou chaîne séparée par `;` en CSV). Absent = codes déduits de la référence par
  le classifieur (on mesure alors l'effet de l'ASR seul, pas celui du classifieur).

Dans un JSONL, les lignes vides et celles qui commencent par `#` sont ignorées.
"""

from __future__ import annotations

import csv
import json
from dataclasses import dataclass, field
from pathlib import Path

STRATA_FIELDS = ("speaker_id", "dialect", "age_group", "gender", "channel", "speech_type")
# Axes de stratification des scores (le locuteur sert d'unité de comptage, pas d'axe).
STRATA_AXES = ("dialect", "age_group", "gender", "channel", "speech_type")
REQUIRED_FIELDS = ("audio_path", "reference", *STRATA_FIELDS)
UNKNOWN = "inconnu"


class ManifestError(ValueError):
    pass


@dataclass(frozen=True)
class ManifestRow:
    utt_id: str
    audio_path: str
    reference: str
    strata: dict[str, str]
    module: str = "reny"
    hypothesis: str | None = None
    expected_sign_codes: tuple[str, ...] | None = None
    extra: dict[str, str] = field(default_factory=dict)

    @property
    def speaker_id(self) -> str:
        return self.strata["speaker_id"]


def _parse_codes(value: object) -> tuple[str, ...] | None:
    if value is None:
        return None
    if isinstance(value, list):
        return tuple(sorted({str(v).strip() for v in value if str(v).strip()}))
    text = str(value).strip()
    if text == "":
        return None
    if text.startswith("["):
        return _parse_codes(json.loads(text))
    return tuple(sorted({part.strip() for part in text.split(";") if part.strip()}))


def _row_from_mapping(raw: dict[str, object], line: int) -> ManifestRow:
    missing = [f for f in REQUIRED_FIELDS if f not in raw]
    if missing:
        raise ManifestError(f"ligne {line} : colonnes manquantes {missing}")
    audio_path = str(raw["audio_path"]).strip()
    if not audio_path:
        raise ManifestError(f"ligne {line} : audio_path vide")
    strata = {
        f: (str(raw[f]).strip() if raw[f] is not None else "") or UNKNOWN for f in STRATA_FIELDS
    }
    hypothesis = raw.get("hypothesis")
    module = str(raw.get("module") or "reny").strip() or "reny"
    if module not in {"reny", "tanora"}:
        raise ManifestError(f"ligne {line} : module inconnu {module!r}")
    return ManifestRow(
        utt_id=str(raw.get("utt_id") or audio_path),
        audio_path=audio_path,
        reference=str(raw["reference"] or ""),
        strata=strata,
        module=module,
        hypothesis=None if hypothesis is None else str(hypothesis),
        expected_sign_codes=_parse_codes(raw.get("expected_sign_codes")),
    )


def _read_records(path: Path) -> list[tuple[int, dict[str, object]]]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open(encoding="utf-8", newline="") as fh:
            return [(i + 2, dict(r)) for i, r in enumerate(csv.DictReader(fh))]
    if suffix in {".jsonl", ".ndjson"}:
        records: list[tuple[int, dict[str, object]]] = []
        with path.open(encoding="utf-8") as fh:
            for i, line in enumerate(fh, start=1):
                stripped = line.strip()
                if not stripped or stripped.startswith("#"):
                    continue
                obj = json.loads(stripped)
                if not isinstance(obj, dict):
                    raise ManifestError(f"ligne {i} : objet JSON attendu")
                records.append((i, obj))
        return records
    raise ManifestError(f"format non pris en charge : {path.suffix} (attendu .csv ou .jsonl)")


def load_manifest(path: Path) -> list[ManifestRow]:
    rows = [_row_from_mapping(raw, line) for line, raw in _read_records(path)]
    ids = [r.utt_id for r in rows]
    if len(ids) != len(set(ids)):
        raise ManifestError("identifiants d'énoncés (utt_id / audio_path) dupliqués")
    return rows


def load_predictions(path: Path) -> dict[str, str]:
    """Fichier de prédictions : colonnes `utt_id` ou `audio_path`, et `hypothesis`."""
    predictions: dict[str, str] = {}
    for line, raw in _read_records(path):
        key = raw.get("utt_id") or raw.get("audio_path")
        if not key or "hypothesis" not in raw:
            raise ManifestError(
                f"prédictions, ligne {line} : utt_id/audio_path et hypothesis requis"
            )
        predictions[str(key)] = str(raw["hypothesis"] or "")
    return predictions
