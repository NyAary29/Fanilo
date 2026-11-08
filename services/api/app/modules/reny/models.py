"""Grossesse, visites CPN et rappels."""

import uuid
from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import Date, ForeignKey, Index, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, SyncSequenced
from app.db.types import UTCDateTime, str_enum, utcnow
from app.modules.beneficiaries.models import PreferredChannel


class PregnancyStatus(StrEnum):
    ACTIVE = "active"
    DELIVERED = "delivered"
    ENDED = "ended"
    TRANSFERRED = "transferred"


class DatesConfirmedBy(StrEnum):
    AC_DECLARED = "ac_declared"
    HEALTH_WORKER = "health_worker"
    ULTRASOUND = "ultrasound"


class AncVisitStatus(StrEnum):
    PLANNED = "planned"
    DONE = "done"
    MISSED = "missed"
    CANCELLED = "cancelled"


class ReminderStatus(StrEnum):
    SCHEDULED = "scheduled"
    SENT = "sent"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Pregnancy(SyncMixin, SyncSequenced, Base):
    __tablename__ = "pregnancies"
    __table_args__ = (Index("ix_pregnancies_sync", "updated_at", "id"),)

    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=False, index=True
    )
    status: Mapped[PregnancyStatus] = mapped_column(
        str_enum(PregnancyStatus, "pregnancy_status", length=16),
        default=PregnancyStatus.ACTIVE,
        nullable=False,
    )
    lmp_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    estimated_due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    dates_confirmed_by: Mapped[DatesConfirmedBy] = mapped_column(
        str_enum(DatesConfirmedBy, "dates_confirmed_by"), nullable=False
    )
    # Traçabilité : calendrier ayant servi à générer les visites.
    anc_schedule_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    anc_schedule_version: Mapped[str | None] = mapped_column(String(16), nullable=True)


class AncVisit(SyncMixin, SyncSequenced, Base):
    __tablename__ = "anc_visits"
    __table_args__ = (Index("ix_anc_visits_sync", "updated_at", "id"),)

    pregnancy_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("pregnancies.id"), nullable=False, index=True
    )
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    status: Mapped[AncVisitStatus] = mapped_column(
        str_enum(AncVisitStatus, "anc_visit_status", length=16),
        default=AncVisitStatus.PLANNED,
        nullable=False,
    )
    done_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Site où la visite a lieu (facultatif) ; le périmètre suit le site de la bénéficiaire.
    site_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("sites.id"), nullable=True)


class Reminder(Base):
    """Rappel planifié. Table serveur (non synchronisée) ; aucun contenu libre :
    seul un ``message_code`` référence un contenu validé."""

    __tablename__ = "reminders"
    __table_args__ = (Index("ix_reminders_due", "status", "scheduled_at"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=False, index=True
    )
    anc_visit_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("anc_visits.id"), nullable=True, index=True
    )
    channel: Mapped[PreferredChannel] = mapped_column(
        str_enum(PreferredChannel, "reminder_channel", length=16), nullable=False
    )
    scheduled_at: Mapped[datetime] = mapped_column(UTCDateTime, nullable=False)
    status: Mapped[ReminderStatus] = mapped_column(
        str_enum(ReminderStatus, "reminder_status", length=16),
        default=ReminderStatus.SCHEDULED,
        nullable=False,
    )
    message_code: Mapped[str] = mapped_column(String(64), nullable=False)
    sent_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    # Code d'erreur technique court (jamais de donnée personnelle).
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime, default=utcnow, onupdate=utcnow, nullable=False
    )
