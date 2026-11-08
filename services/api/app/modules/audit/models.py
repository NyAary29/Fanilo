"""Événement d'audit.

Table en ajout seul, sans clé étrangère : un événement reste lisible même si
l'utilisateur ou le site référencé évolue. **Aucun contenu médical ni
nominatif** : uniquement des identifiants techniques, un rôle et une action.
"""

import uuid
from datetime import datetime

from sqlalchemy import Index, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.types import UTCDateTime, utcnow


class AuditEvent(Base):
    __tablename__ = "audit_events"
    __table_args__ = (Index("ix_audit_events_entity", "entity_type", "entity_id"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False, index=True)
    # Nul pour une tentative de connexion d'un identifiant inconnu ou invalide.
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True, index=True)
    actor_role: Mapped[str | None] = mapped_column(String(32), nullable=True)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    # Nuls pour un échec de connexion (ni acteur ni entité, contrat §10).
    entity_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    site_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True)
    # Empreinte HMAC-SHA256 de l'identifiant tenté lors d'un échec de connexion
    # (corrélation des tentatives sans identifiant en clair). Non exposée par l'API.
    login_fingerprint: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
