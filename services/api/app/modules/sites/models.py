"""Sites : CSB, structures de référence et zones communautaires, en hiérarchie."""

import uuid
from enum import StrEnum

from sqlalchemy import Boolean, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, SyncSequenced
from app.db.types import str_enum


class SiteKind(StrEnum):
    CSB = "csb"
    REFERENCE_FACILITY = "reference_facility"
    COMMUNITY_ZONE = "community_zone"


class Site(SyncMixin, SyncSequenced, Base):
    """Un site. ``parent_site_id`` forme un arbre (ex. zone communautaire → CSB).

    Jamais supprimé physiquement : on le désactive (``is_active = False``).
    """

    __tablename__ = "sites"

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    kind: Mapped[SiteKind] = mapped_column(str_enum(SiteKind, "site_kind"), nullable=False)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    district: Mapped[str] = mapped_column(String(100), nullable=False)
    region: Mapped[str] = mapped_column(String(100), nullable=False)
    parent_site_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("sites.id"), nullable=True, index=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
