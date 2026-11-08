"""Information présentée lors du recueil du consentement (fichier YAML versionné).

Politique (alignée sur les autres référentiels) : un élément ``retired`` n'est
jamais servi ; ``validated`` l'est toujours ; tout autre statut (``demo``,
``draft``, ``in_review``) seulement si ``FANILO_ALLOW_DEMO_CONTENT=true``.
Le statut d'un élément est, à défaut, celui du fichier.
"""

from functools import lru_cache
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.modules.beneficiaries.models import ConsentScope

Status = Literal["demo", "draft", "in_review", "validated", "retired"]


class ConsentInformationError(Exception):
    """Fichier absent ou invalide."""


class ConsentInformationItem(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    scope: ConsentScope
    version: str = Field(min_length=1, max_length=32)
    status: Status | None = None
    summary_fr: str = Field(min_length=1, max_length=4_000)
    summary_mg: str | None = Field(None, max_length=4_000)


class ConsentInformationFile(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    catalog_id: str = Field(min_length=1)
    version: str = Field(pattern=r"^\d+\.\d+\.\d+$")
    status: Status
    source: str = Field(min_length=1)
    validated_by: str | None = None
    validated_at: str | None = None
    items: tuple[ConsentInformationItem, ...] = Field(min_length=1)


@lru_cache(maxsize=8)
def _parse(path: Path, mtime_ns: int) -> ConsentInformationFile:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        return ConsentInformationFile.model_validate(raw)
    except (OSError, yaml.YAMLError, ValidationError) as exc:
        raise ConsentInformationError(f"Fichier d'information invalide : {exc}") from exc


def load_consent_information(path: Path) -> ConsentInformationFile:
    try:
        mtime = path.stat().st_mtime_ns
    except OSError as exc:
        raise ConsentInformationError(f"Fichier introuvable : {path.name}.") from exc
    return _parse(path, mtime)


def served_items(document: ConsentInformationFile, *, allow_demo: bool) -> list[dict]:
    items = []
    for item in document.items:
        status = item.status or document.status
        if status == "retired" or (status != "validated" and not allow_demo):
            continue
        items.append(
            {
                "scope": item.scope,
                "version": item.version,
                "status": status,
                "summary_fr": item.summary_fr,
                "summary_mg": item.summary_mg,
            }
        )
    return items
