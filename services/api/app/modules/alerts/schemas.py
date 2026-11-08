"""Schémas des alertes (section 7 du contrat)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.modules.alerts.models import AlertEventType, AlertSeverity, AlertStatus


class AlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    beneficiary_id: uuid.UUID | None
    site_id: uuid.UUID | None
    interaction_id: uuid.UUID | None
    rule_id: str
    ruleset_version: str
    severity: AlertSeverity
    status: AlertStatus
    recipient_user_id: uuid.UUID | None
    backup_user_id: uuid.UUID | None
    due_at: datetime
    due_at_is_demo: bool
    acknowledged_at: datetime | None
    acknowledged_by_user_id: uuid.UUID | None
    resolved_at: datetime | None
    escalated_at: datetime | None
    is_demo: bool


class AlertEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    alert_id: uuid.UUID
    at: datetime
    actor_user_id: uuid.UUID | None
    type: AlertEventType
    note: str | None


class AlertDetail(AlertOut):
    events: list[AlertEventOut]


class AlertNote(BaseModel):
    model_config = ConfigDict(extra="forbid")

    note: str = Field(min_length=1, max_length=2_000)
