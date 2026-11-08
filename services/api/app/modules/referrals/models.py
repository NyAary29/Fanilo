"""Référence d'une bénéficiaire vers un site (CSB, structure de référence).

Synchronisable en écriture. Machine à états stricte (voir ``service.py``).
"""

import uuid
from enum import StrEnum

from sqlalchemy import ForeignKey, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, SyncSequenced
from app.db.types import str_enum


class ReferralStatus(StrEnum):
    PROPOSED = "proposed"
    ACCEPTED = "accepted"
    ARRIVED = "arrived"
    TRANSFERRED = "transferred"
    NOT_COMPLETED = "not_completed"


class Referral(SyncMixin, SyncSequenced, Base):
    __tablename__ = "referrals"

    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=False, index=True
    )
    alert_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("alerts.id"), nullable=True, index=True
    )
    from_site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True
    )
    to_site_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=False, index=True
    )
    status: Mapped[ReferralStatus] = mapped_column(
        str_enum(ReferralStatus, "referral_status", length=16), nullable=False
    )
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    outcome_note: Mapped[str | None] = mapped_column(Text, nullable=True)
