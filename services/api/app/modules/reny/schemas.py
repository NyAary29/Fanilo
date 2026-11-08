"""Schémas RENY (grossesse, visites CPN)."""

import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict

from app.modules.beneficiaries.schemas import SyncFields
from app.modules.reny.models import AncVisitStatus, DatesConfirmedBy, PregnancyStatus


class PregnancyOut(SyncFields):
    beneficiary_id: uuid.UUID
    status: PregnancyStatus
    lmp_date: date | None
    estimated_due_date: date | None
    dates_confirmed_by: DatesConfirmedBy


class PregnancyCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: uuid.UUID | None = None
    lmp_date: date | None = None
    estimated_due_date: date | None = None
    dates_confirmed_by: DatesConfirmedBy = DatesConfirmedBy.AC_DECLARED


class PregnancyPatch(BaseModel):
    model_config = ConfigDict(extra="ignore")

    # Facultative ; si fournie, doit correspondre à la version serveur (409).
    version: int | None = None
    status: PregnancyStatus | None = None
    lmp_date: date | None = None
    estimated_due_date: date | None = None
    dates_confirmed_by: DatesConfirmedBy | None = None


class AncVisitOut(SyncFields):
    pregnancy_id: uuid.UUID
    sequence: int
    scheduled_date: date
    status: AncVisitStatus
    done_date: date | None
    site_id: uuid.UUID | None


class AncVisitPatch(BaseModel):
    model_config = ConfigDict(extra="ignore")

    version: int | None = None
    status: AncVisitStatus | None = None
    done_date: date | None = None
    scheduled_date: date | None = None
    site_id: uuid.UUID | None = None
