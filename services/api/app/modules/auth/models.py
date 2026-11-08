"""Jetons de rafraîchissement, stockés uniquement sous forme hachée."""

import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import UTCDateTime, utcnow


class RefreshToken(Base):
    """Un jeton de rafraîchissement opaque.

    Tous les jetons issus d'une même connexion partagent un ``family_id``.
    Chaque rafraîchissement consomme le jeton (``used_at``) et en émet un
    nouveau dans la même famille. Présenter un jeton déjà consommé ou révoqué
    révoque toute la famille (détection de vol).

    Table purement serveur : elle n'hérite pas de SyncMixin.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    family_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False, index=True)
    # SHA-256 (hexadécimal) du jeton : le jeton en clair n'est jamais stocké.
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(UTCDateTime, nullable=False)
    used_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)
    replaced_by_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True)
