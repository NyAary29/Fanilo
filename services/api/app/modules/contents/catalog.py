"""Import d'un catalogue YAML de contenus de **démonstration**.

Le catalogue (``config/contents.demo.yaml``) porte ``status: demo`` : ses
contenus sont importés au statut ``demo``, ne sont servis que si
``FANILO_ALLOW_DEMO_CONTENT=true`` et ne sont jamais promus. Un contenu réel
suit le circuit ``draft`` → ``in_review`` → ``validated`` de l'API.

L'import est idempotent : un (``code``, ``language``, ``version``) déjà présent
est ignoré.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.contents.models import ContentItem, ContentLanguage, ContentModule, ContentStatus
from app.modules.contents.schemas import CODE_PATTERN


class CatalogError(Exception):
    """Catalogue illisible, invalide ou non autorisé."""


class CatalogItem(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    code: str = Field(pattern=CODE_PATTERN, max_length=64)
    module: ContentModule
    language: ContentLanguage
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=10_000)
    version: int = Field(default=1, ge=1)
    audio_url: str | None = Field(None, max_length=500)


class ContentCatalog(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    catalog_id: str = Field(min_length=1)
    version: str = Field(pattern=r"^\d+\.\d+\.\d+$")
    # Seul un catalogue de démonstration peut être importé par cette commande.
    status: Literal["demo"]
    source: str = Field(min_length=1)
    items: tuple[CatalogItem, ...] = Field(min_length=1)

    @property
    def codes(self) -> frozenset[str]:
        return frozenset(item.code for item in self.items)


def load_catalog(path: Path) -> ContentCatalog:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        catalog = ContentCatalog.model_validate(raw)
    except (OSError, yaml.YAMLError, ValidationError) as exc:
        raise CatalogError(f"Catalogue de contenus invalide ({path.name}) : {exc}") from exc
    keys = [(i.code, i.language, i.version) for i in catalog.items]
    if len(set(keys)) != len(keys):
        raise CatalogError("Entrées dupliquées (code, langue, version) dans le catalogue.")
    return catalog


@dataclass
class ImportReport:
    created: int = 0
    skipped: int = 0


def import_catalog(session: Session, catalog: ContentCatalog) -> ImportReport:
    """Importe les contenus au statut ``demo`` (sans valider la transaction)."""
    report = ImportReport()
    for entry in catalog.items:
        exists = session.scalar(
            select(ContentItem.id).where(
                ContentItem.code == entry.code,
                ContentItem.language == entry.language,
                ContentItem.version == entry.version,
            )
        )
        if exists is not None:
            report.skipped += 1
            continue
        session.add(
            ContentItem(
                code=entry.code,
                module=entry.module,
                language=entry.language,
                title=entry.title,
                body=entry.body,
                audio_url=entry.audio_url,
                version=entry.version,
                status=ContentStatus.DEMO,
                author_id=None,
                source_ref=f"{catalog.catalog_id}@{catalog.version} — {catalog.source}"[:500],
            )
        )
        report.created += 1
    session.flush()
    return report
