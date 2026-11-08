"""Alerte déclenchée par une règle ``urgent`` ou ``critical``, et son journal.

``Alert`` est synchronisable **en lecture seule** (``version``, ``deleted_at``,
``sync_seq``). ``site_id`` (site de la bénéficiaire, à défaut celui de l'auteur
de la question) porte le périmètre.
"""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Boolean, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, SyncSequenced
from app.db.types import UTCDateTime, str_enum, utcnow


class AlertStatus(StrEnum):
    OPEN = "open"
    ACKNOWLEDGED = "acknowledged"
    RESOLVED = "resolved"
    ESCALATED = "escalated"
    CANCELLED = "cancelled"


class AlertSeverity(StrEnum):
    ROUTINE = "routine"
    URGENT = "urgent"
    CRITICAL = "critical"


class AlertEventType(StrEnum):
    CREATED = "created"
    ACKNOWLEDGED = "acknowledged"
    ESCALATED = "escalated"
    NOTE = "note"
    RESOLVED = "resolved"
    CANCELLED = "cancelled"


class Alert(SyncMixin, SyncSequenced, Base):
    __tablename__ = "alerts"
    __table_args__ = (Index("ix_alerts_status_due", "status", "due_at"),)

    # Nul pour une question posée sans bénéficiaire identifiée.
    beneficiary_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=True, index=True
    )
    site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True, index=True
    )
    interaction_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("interactions.id"), nullable=True
    )
    rule_id: Mapped[str] = mapped_column(String(64), nullable=False)
    ruleset_version: Mapped[str] = mapped_column(String(32), nullable=False)
    severity: Mapped[AlertSeverity] = mapped_column(
        str_enum(AlertSeverity, "alert_severity", length=16), nullable=False
    )
    status: Mapped[AlertStatus] = mapped_column(
        str_enum(AlertStatus, "alert_status", length=16), nullable=False
    )
    # Nul uniquement si aucun destinataire éligible : l'alerte est alors escaladée.
    recipient_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True, index=True
    )
    backup_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    due_at: Mapped[datetime] = mapped_column(UTCDateTime, nullable=False)
    # Vrai si due_at provient du délai par défaut de démonstration (règle placeholder).
    due_at_is_demo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    acknowledged_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    acknowledged_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    resolved_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    escalated_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    is_demo: Mapped[bool] = mapped_column(Boolean, nullable=False)


class AlertEvent(Base):
    """Journal d'une alerte (ajout seul)."""

    __tablename__ = "alert_events"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    alert_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("alerts.id"), nullable=False, index=True
    )
    at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
    # Nul pour un événement système (création automatique, escalade planifiée).
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )
    type: Mapped[AlertEventType] = mapped_column(
        str_enum(AlertEventType, "alert_event_type", length=16), nullable=False
    )
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
