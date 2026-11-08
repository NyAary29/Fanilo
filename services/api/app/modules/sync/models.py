"""Journal des modifications reçues par ``/sync/push`` (idempotence par ``change_id``)."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import JSON, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import UTCDateTime, utcnow


class SyncChange(Base):
    """Une modification déjà traitée et son résultat, renvoyé tel quel si le même
    ``change_id`` est présenté à nouveau.

    ``result`` ne contient jamais d'identité en clair : pour les entités
    nominatives (``beneficiary_identity``), le résultat est stocké chiffré
    (``{"encrypted": <jeton Fernet>}``).
    """

    __tablename__ = "sync_changes"

    change_id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False, index=True
    )
    device_id: Mapped[str] = mapped_column(String(128), nullable=False)
    entity: Mapped[str] = mapped_column(String(32), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    op: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    result: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
