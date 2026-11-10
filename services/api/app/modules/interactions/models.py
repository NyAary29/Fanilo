"""Interaction journalisée : question, décision du moteur de règles, revue.

Table serveur (non synchronisée). **L'audio n'est jamais stocké** ; le
transcript est conservé selon la politique de rétention (à définir).
``alert_id`` n'a pas de clé étrangère (référence circulaire avec
``alerts.interaction_id``, qui en porte une).
"""

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import JSON, Boolean, Float, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import UTCDateTime, str_enum, utcnow


class InteractionModule(StrEnum):
    RENY = "reny"
    TANORA = "tanora"


class InputKind(StrEnum):
    AUDIO = "audio"
    TEXT = "text"
    SIGN_CODES = "sign_codes"


class Outcome(StrEnum):
    ANSWER = "answer"
    DANGER_SIGN = "danger_sign"
    FALLBACK = "fallback"


class Severity(StrEnum):
    ROUTINE = "routine"
    URGENT = "urgent"
    CRITICAL = "critical"


class Triage(StrEnum):
    """Classement par le conseiller."""

    URGENT = "urgent"
    FOLLOW_UP = "follow_up"  # à suivre
    INFO = "info"  # simple information


class FollowUpStatus(StrEnum):
    """Suivi par le centre de santé vers lequel la personne est orientée."""

    EXPECTED = "expected"  # attendue au centre
    CAME = "came"  # venue
    NO_SHOW = "no_show"  # pas venue


class ReviewStatus(StrEnum):
    PENDING = "pending"
    REVIEWED = "reviewed"
    NOT_REQUIRED = "not_required"


class Interaction(Base):
    __tablename__ = "interactions"
    __table_args__ = (Index("ix_interactions_review", "review_status", "created_at"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime, default=utcnow, nullable=False, index=True
    )
    module: Mapped[InteractionModule] = mapped_column(
        str_enum(InteractionModule, "interaction_module", length=16), nullable=False
    )
    beneficiary_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=True, index=True
    )
    # Site de la bénéficiaire, à défaut celui de l'auteur de la question (périmètre).
    site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True, index=True
    )
    # Nul pour une question anonyme (application publique « Femmes & Adolescentes »).
    asked_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    # Canal : « agent » (comptes FANILO) ou « public_app » (anonyme).
    channel: Mapped[str] = mapped_column(String(16), nullable=False, default="agent")
    # Empreinte SHA-256 du jeton de suivi remis à l'utilisatrice anonyme (jamais le jeton).
    follow_up_token_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    input_kind: Mapped[InputKind] = mapped_column(
        str_enum(InputKind, "interaction_input_kind", length=16), nullable=False
    )
    language: Mapped[str] = mapped_column(String(8), nullable=False)
    transcript: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_needs_review: Mapped[bool] = mapped_column(Boolean, nullable=False)
    # Codes SIGN_... proposés (IA) ou saisis (AC) ; confiance nulle = saisie déterministe.
    sign_codes: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    # Intention proposée par le classifieur (statistiques thématiques, F-16).
    intent: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    detection_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    outcome: Mapped[Outcome] = mapped_column(
        str_enum(Outcome, "interaction_outcome", length=16), nullable=False
    )
    actions: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    severity: Mapped[Severity | None] = mapped_column(
        str_enum(Severity, "interaction_severity", length=16), nullable=True
    )
    content_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    alert_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True)
    is_demo: Mapped[bool] = mapped_column(Boolean, nullable=False)
    # Traçabilité de la décision (jeu de règles, motifs de fallback, trace).
    ruleset_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    ruleset_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    fallback_reasons: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    decision_trace: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    review_status: Mapped[ReviewStatus] = mapped_column(
        str_enum(ReviewStatus, "interaction_review_status", length=16), nullable=False
    )
    reviewed_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Centre de santé vers lequel le conseiller oriente la personne (facultatif).
    orientation_site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True, index=True
    )
    triage: Mapped[Triage | None] = mapped_column(
        str_enum(Triage, "interaction_triage", length=16), nullable=True
    )
    # Code court à montrer au centre (anonyme) ; présent si un suivi est attendu.
    follow_up_code: Mapped[str | None] = mapped_column(String(8), nullable=True, index=True)
    follow_up_status: Mapped[FollowUpStatus | None] = mapped_column(
        str_enum(FollowUpStatus, "interaction_follow_up_status", length=16), nullable=True
    )
    follow_up_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    follow_up_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    follow_up_note: Mapped[str | None] = mapped_column(Text, nullable=True)
