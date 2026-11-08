"""Contenu de santé versionné.

Un contenu est identifié par son ``code`` (``MSG_...``) et sa ``language`` ;
chaque modification d'un contenu validé crée une **nouvelle version** qui
repasse par ``draft`` → ``in_review`` → ``validated``. Au plus une version
``validated`` par (``code``, ``language``) : la précédente passe à ``retired``.

``demo`` : contenu de démonstration importé par la commande CLI, **non validé
cliniquement**, servi uniquement si ``FANILO_ALLOW_DEMO_CONTENT=true``.
"""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import ForeignKey, Index, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import UTCDateTime, str_enum, utcnow


class ContentModule(StrEnum):
    RENY = "reny"
    TANORA = "tanora"
    COMMON = "common"


class ContentLanguage(StrEnum):
    MG = "mg"
    FR = "fr"


class ContentStatus(StrEnum):
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    VALIDATED = "validated"
    RETIRED = "retired"
    DEMO = "demo"


class ContentItem(Base):
    __tablename__ = "content_items"
    __table_args__ = (
        UniqueConstraint("code", "language", "version", name="uq_content_items_code_lang_version"),
        Index("ix_content_items_lookup", "code", "language", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(64), nullable=False)
    module: Mapped[ContentModule] = mapped_column(
        str_enum(ContentModule, "content_module", length=16), nullable=False
    )
    language: Mapped[ContentLanguage] = mapped_column(
        str_enum(ContentLanguage, "content_language", length=8), nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Version du CONTENU (1, 2, ...), pas un verrou optimiste.
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[ContentStatus] = mapped_column(
        str_enum(ContentStatus, "content_status", length=16), nullable=False
    )
    # Nul pour un contenu importé par la commande CLI (catalogue de démonstration).
    author_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    validator_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    source_ref: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Dernière note de rejet du responsable clinique (revue éditoriale).
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime, default=utcnow, onupdate=utcnow, nullable=False
    )
