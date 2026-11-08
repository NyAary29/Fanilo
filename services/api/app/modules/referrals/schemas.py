"""Schémas des références (section 7 du contrat).

Les schémas d'entrée ignorent les champs inconnus : la synchronisation renvoie
la représentation complète (``version``, ``created_at``…), jamais prise en compte.
"""

import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.modules.beneficiaries.schemas import SyncFields
from app.modules.referrals.models import ReferralStatus


class ReferralOut(SyncFields):
    beneficiary_id: uuid.UUID
    alert_id: uuid.UUID | None
    from_site_id: uuid.UUID | None
    to_site_id: uuid.UUID
    status: ReferralStatus
    reason: str | None
    outcome_note: str | None


class ReferralCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: uuid.UUID | None = None
    beneficiary_id: uuid.UUID
    alert_id: uuid.UUID | None = None
    from_site_id: uuid.UUID | None = None
    to_site_id: uuid.UUID
    # Une référence est toujours créée au statut ``proposed``.
    status: ReferralStatus = ReferralStatus.PROPOSED
    reason: str | None = Field(None, max_length=1_000)
    outcome_note: str | None = Field(None, max_length=2_000)


class ReferralSyncUpdate(BaseModel):
    """Représentation complète envoyée par la synchronisation (mise à jour)."""

    model_config = ConfigDict(extra="ignore")

    beneficiary_id: uuid.UUID | None = None
    alert_id: uuid.UUID | None = None
    from_site_id: uuid.UUID | None = None
    to_site_id: uuid.UUID | None = None
    status: ReferralStatus | None = None
    reason: str | None = Field(None, max_length=1_000)
    outcome_note: str | None = Field(None, max_length=2_000)


class ReferralTransition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    to_status: ReferralStatus
    reason: str | None = Field(None, max_length=1_000)
    outcome_note: str | None = Field(None, max_length=2_000)
