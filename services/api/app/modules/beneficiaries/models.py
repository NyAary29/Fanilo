"""Bénéficiaire pseudonymisée, identité chiffrée et consentements.

Séparation stricte : ``Beneficiary`` ne contient aucun nom ni téléphone.
L'identité est dans ``BeneficiaryIdentity``, dont les colonnes nominatives sont
**chiffrées** (Fernet, voir app.core.crypto) : la base ne contient jamais le
nom en clair.
"""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import ForeignKey, Index, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, SyncSequenced
from app.db.types import UTCDateTime, str_enum


class PreferredChannel(StrEnum):
    SMS = "sms"
    IVR = "ivr"
    AC_VISIT = "ac_visit"
    NONE = "none"


class ConsentScope(StrEnum):
    RENY = "reny"
    TANORA = "tanora"
    REMINDERS = "reminders"
    VOICE_PROCESSING = "voice_processing"


class ConsentMethod(StrEnum):
    ORAL = "oral"
    WRITTEN = "written"


class Beneficiary(SyncMixin, SyncSequenced, Base):
    __tablename__ = "beneficiaries"
    __table_args__ = (Index("ix_beneficiaries_sync", "updated_at", "id"),)

    # Code pseudonyme FAN-XXXXXX, aléatoire et non séquentiel.
    code: Mapped[str] = mapped_column(String(16), unique=True, nullable=False)
    site_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=False, index=True
    )
    birth_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    preferred_channel: Mapped[PreferredChannel] = mapped_column(
        str_enum(PreferredChannel, "preferred_channel", length=16),
        default=PreferredChannel.NONE,
        nullable=False,
    )


class BeneficiaryIdentity(SyncMixin, SyncSequenced, Base):
    """Identité nominative. ``id`` est toujours égal à ``beneficiary_id``.

    Les colonnes ``*_encrypted`` contiennent un jeton Fernet (texte ASCII).
    """

    __tablename__ = "beneficiary_identities"
    __table_args__ = (Index("ix_beneficiary_identities_sync", "updated_at", "id"),)

    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), unique=True, nullable=False
    )
    display_name_encrypted: Mapped[str] = mapped_column(Text, nullable=False)
    phone_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    village_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)


class Consent(SyncMixin, SyncSequenced, Base):
    __tablename__ = "consents"
    __table_args__ = (Index("ix_consents_sync", "updated_at", "id"),)

    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("beneficiaries.id"), nullable=False, index=True
    )
    scope: Mapped[ConsentScope] = mapped_column(
        str_enum(ConsentScope, "consent_scope"), nullable=False
    )
    method: Mapped[ConsentMethod] = mapped_column(
        str_enum(ConsentMethod, "consent_method", length=16), nullable=False
    )
    # Version du texte d'information présenté à la bénéficiaire.
    information_version: Mapped[str] = mapped_column(String(32), nullable=False)
    collected_by_user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False
    )
    collected_at: Mapped[datetime] = mapped_column(UTCDateTime, nullable=False)
    withdrawn_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    withdrawn_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=True
    )

    @property
    def is_active(self) -> bool:
        return self.withdrawn_at is None and self.deleted_at is None
