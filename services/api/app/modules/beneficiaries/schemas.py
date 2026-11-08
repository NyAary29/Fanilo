"""Schémas des bénéficiaires, identités et consentements.

Les schémas d'entrée ignorent les champs inconnus (``extra="ignore"``) pour que
la synchronisation puisse renvoyer l'objet complet (``code``, ``version``…)
sans erreur ; les champs gérés par le serveur ne sont jamais pris en compte.
"""

import uuid
from datetime import date, datetime

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, field_validator

from app.modules.beneficiaries.models import ConsentMethod, ConsentScope, PreferredChannel

MIN_BIRTH_YEAR = 1900


def _check_birth_year(value: int | None) -> int | None:
    if value is not None and not MIN_BIRTH_YEAR <= value <= date.today().year:
        raise ValueError("Année de naissance invalide.")
    return value


class SyncFields(BaseModel):
    """Champs communs des entités synchronisables."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None


class BeneficiaryOut(SyncFields):
    code: str
    site_id: uuid.UUID
    birth_year: int | None
    preferred_channel: PreferredChannel


class BeneficiaryCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: uuid.UUID | None = None
    site_id: uuid.UUID | None = None
    birth_year: int | None = None
    preferred_channel: PreferredChannel = PreferredChannel.NONE

    _birth = field_validator("birth_year")(_check_birth_year)


class BeneficiaryPatch(BaseModel):
    model_config = ConfigDict(extra="ignore")

    # Obligatoire (contrat) : absente ou périmée → 409.
    version: int | None = None
    site_id: uuid.UUID | None = None
    birth_year: int | None = None
    preferred_channel: PreferredChannel | None = None

    _birth = field_validator("birth_year")(_check_birth_year)


class IdentityOut(SyncFields):
    beneficiary_id: uuid.UUID
    display_name: str
    phone: str | None
    village: str | None


class IdentityPut(BaseModel):
    model_config = ConfigDict(extra="ignore")

    display_name: str = Field(min_length=1, max_length=200)
    phone: str | None = Field(None, max_length=32)
    village: str | None = Field(None, max_length=200)
    # Facultative à la création ; si fournie lors d'une mise à jour, elle doit
    # correspondre à la version serveur (409 sinon).
    version: int | None = None


class ConsentOut(SyncFields):
    beneficiary_id: uuid.UUID
    scope: ConsentScope
    method: ConsentMethod
    information_version: str
    collected_by_user_id: uuid.UUID
    collected_at: datetime
    withdrawn_at: datetime | None
    withdrawn_by_user_id: uuid.UUID | None


class ConsentCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: uuid.UUID | None = None
    scope: ConsentScope
    method: ConsentMethod
    information_version: str = Field(min_length=1, max_length=32)
    # Recueil hors ligne : horodatage du terrain. Par défaut, maintenant.
    collected_at: AwareDatetime | None = None
