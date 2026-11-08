"""Modèle utilisateur.

Minimisation des données : seuls un identifiant de connexion, le rôle et le
site de rattachement sont conservés. Ni e-mail ni nom complet.
"""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, Enum, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin
from app.db.types import UTCDateTime
from app.modules.users.roles import Role

LOGIN_MAX_LENGTH = 64


def normalize_login(raw: str) -> str:
    """Normalise l'identifiant (nom d'utilisateur ou téléphone) avant stockage/recherche."""
    return "".join(raw.split()).lower()


class User(SyncMixin, Base):
    __tablename__ = "users"

    # Nom d'utilisateur ou numéro de téléphone, normalisé (voir normalize_login).
    login: Mapped[str] = mapped_column(String(LOGIN_MAX_LENGTH), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[Role] = mapped_column(
        Enum(
            Role,
            name="user_role",
            native_enum=False,
            create_constraint=True,
            length=32,
            values_callable=lambda enum: [member.value for member in enum],
        ),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Rattachement à un site / CSB (lot P0.4). Détermine le périmètre de données
    # (voir app.modules.sites.scope).
    site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True, index=True
    )
    last_login_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)

    @property
    def can_authenticate(self) -> bool:
        return self.is_active and self.deleted_at is None

    def __repr__(self) -> str:  # pas de donnée sensible dans la représentation
        return f"<User id={self.id} role={self.role}>"
