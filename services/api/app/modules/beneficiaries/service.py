"""Logique métier des bénéficiaires, identités et consentements.

Toutes les fonctions prennent un :class:`ActorContext` : elles appliquent le
contrôle de rôle, le périmètre par site et l'audit, puis ``flush`` sans valider
(l'appelant — routeur REST ou synchronisation — décide du commit).
"""

import logging
import secrets
import uuid
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.crypto import get_cipher
from app.core.errors import (
    InvalidDataError,
    NotFoundError,
    StateConflictError,
    check_version,
)
from app.db.types import utcnow
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import (
    Beneficiary,
    BeneficiaryIdentity,
    Consent,
    ConsentScope,
)
from app.modules.beneficiaries.schemas import (
    BeneficiaryCreate,
    BeneficiaryPatch,
    ConsentCreate,
    IdentityOut,
    IdentityPut,
)
from app.modules.reny.reminders import (
    cancel_scheduled_reminders,
    has_active_consent,
    plan_reminders_for_beneficiary,
)
from app.modules.reny.schedule import ScheduleUnavailableError, get_schedule
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext
from app.modules.users.roles import NOMINATIVE_DATA_ROLES, Role

logger = logging.getLogger("fanilo.beneficiaries")

# Rôles autorisés à créer ou modifier des données de suivi (bénéficiaires,
# consentements, grossesses, visites). Les rôles d'administration, de données
# et techniques consultent sans écrire.
CARE_ROLES: frozenset[Role] = NOMINATIVE_DATA_ROLES

CODE_PREFIX = "FAN-"
# Alphabet sans caractères ambigus (0/O, 1/I/L) : 31^6 ≈ 8,9e8 combinaisons.
CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
_CODE_MAX_ATTEMPTS = 20
# Tolérance d'horloge pour les horodatages saisis sur le terrain.
CLOCK_SKEW = timedelta(minutes=10)


# --- Bénéficiaires ------------------------------------------------------------


def generate_code(session: Session) -> str:
    """Code ``FAN-XXXXXX`` tiré aléatoirement (``secrets``), non séquentiel."""
    for _ in range(_CODE_MAX_ATTEMPTS):
        code = CODE_PREFIX + "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
        if session.scalar(select(Beneficiary.id).where(Beneficiary.code == code)) is None:
            return code
    raise RuntimeError("Impossible de générer un code bénéficiaire unique.")  # pragma: no cover


def get_beneficiary(ctx: ActorContext, beneficiary_id: uuid.UUID) -> Beneficiary:
    """Bénéficiaire visible et non supprimée, sinon 404."""
    beneficiary = ctx.session.get(Beneficiary, beneficiary_id)
    if beneficiary is None or beneficiary.deleted_at is not None:
        raise NotFoundError
    ctx.scope.ensure_contains(beneficiary.site_id)
    return beneficiary


def _ensure_target_site(ctx: ActorContext, site_id: uuid.UUID | None) -> uuid.UUID:
    if site_id is None:
        raise InvalidDataError("site_id est obligatoire.")
    if ctx.session.get(Site, site_id) is None:
        raise InvalidDataError("Site introuvable.")
    ctx.scope.ensure_writable(site_id)
    return site_id


def create_beneficiary(ctx: ActorContext, data: BeneficiaryCreate) -> Beneficiary:
    ctx.ensure_role(CARE_ROLES)
    site_id = _ensure_target_site(ctx, data.site_id or ctx.actor.site_id)
    if data.id is not None and ctx.session.get(Beneficiary, data.id) is not None:
        raise StateConflictError("Une bénéficiaire existe déjà avec cet identifiant.")
    beneficiary = Beneficiary(
        code=generate_code(ctx.session),
        site_id=site_id,
        birth_year=data.birth_year,
        preferred_channel=data.preferred_channel,
    )
    if data.id is not None:
        beneficiary.id = data.id
    ctx.session.add(beneficiary)
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.BENEFICIARY_CREATE,
        "beneficiary",
        beneficiary.id,
        site_id=site_id,
    )
    return beneficiary


def update_beneficiary(
    ctx: ActorContext, beneficiary: Beneficiary, data: BeneficiaryPatch
) -> Beneficiary:
    ctx.ensure_role(CARE_ROLES)
    check_version(beneficiary.version, data.version)
    changes = data.model_dump(exclude_unset=True, exclude={"version"})
    if "preferred_channel" in changes and changes["preferred_channel"] is None:
        raise InvalidDataError("preferred_channel ne peut pas être nul.")
    if "site_id" in changes:
        changes["site_id"] = _ensure_target_site(ctx, changes["site_id"])
    for field, value in changes.items():
        setattr(beneficiary, field, value)
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.BENEFICIARY_UPDATE,
        "beneficiary",
        beneficiary.id,
        site_id=beneficiary.site_id,
    )
    return beneficiary


def delete_beneficiary(ctx: ActorContext, beneficiary: Beneficiary) -> None:
    """Suppression logique en cascade (identité, consentements, grossesses, visites)
    et annulation des rappels. Les suppressions se propagent aux appareils."""
    # Import local : reny.service dépend de ce module.
    from app.modules.reny.service import soft_delete_pregnancy_tree

    ctx.ensure_role(CARE_ROLES)
    session = ctx.session
    identity = session.scalar(
        select(BeneficiaryIdentity).where(BeneficiaryIdentity.beneficiary_id == beneficiary.id)
    )
    if identity is not None:
        identity.soft_delete()
    for consent in session.scalars(select(Consent).where(Consent.beneficiary_id == beneficiary.id)):
        consent.soft_delete()
    soft_delete_pregnancy_tree(session, beneficiary_id=beneficiary.id)
    cancel_scheduled_reminders(session, beneficiary_id=beneficiary.id)
    beneficiary.soft_delete()
    session.flush()
    record_audit(
        session,
        ctx.actor,
        AuditAction.BENEFICIARY_DELETE,
        "beneficiary",
        beneficiary.id,
        site_id=beneficiary.site_id,
    )


# --- Identité (chiffrée) ------------------------------------------------------


def serialize_identity(ctx: ActorContext, identity: BeneficiaryIdentity) -> IdentityOut:
    cipher = get_cipher(ctx.settings)
    return IdentityOut(
        id=identity.id,
        version=identity.version,
        created_at=identity.created_at,
        updated_at=identity.updated_at,
        deleted_at=identity.deleted_at,
        beneficiary_id=identity.beneficiary_id,
        display_name=cipher.decrypt(identity.display_name_encrypted) or "",
        phone=cipher.decrypt(identity.phone_encrypted),
        village=cipher.decrypt(identity.village_encrypted),
    )


def find_identity(session: Session, beneficiary_id: uuid.UUID) -> BeneficiaryIdentity | None:
    return session.scalar(
        select(BeneficiaryIdentity).where(BeneficiaryIdentity.beneficiary_id == beneficiary_id)
    )


def read_identity(ctx: ActorContext, beneficiary: Beneficiary) -> IdentityOut:
    """Lecture nominative : rôles nominatifs uniquement, toujours auditée."""
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    identity = find_identity(ctx.session, beneficiary.id)
    if identity is None or identity.deleted_at is not None:
        raise NotFoundError("Aucune identité enregistrée.")
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.IDENTITY_READ,
        "beneficiary_identity",
        identity.id,
        site_id=beneficiary.site_id,
    )
    return serialize_identity(ctx, identity)


def write_identity(
    ctx: ActorContext, beneficiary: Beneficiary, data: IdentityPut, *, require_version: bool = False
) -> BeneficiaryIdentity:
    """Crée ou remplace l'identité. Une version fournie doit être à jour (409)."""
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    cipher = get_cipher(ctx.settings)
    identity = find_identity(ctx.session, beneficiary.id)
    if identity is None:
        identity = BeneficiaryIdentity(id=beneficiary.id, beneficiary_id=beneficiary.id)
        ctx.session.add(identity)
    elif require_version or data.version is not None:
        check_version(identity.version, data.version)
    identity.display_name_encrypted = cipher.encrypt(data.display_name.strip())
    identity.phone_encrypted = cipher.encrypt(data.phone)
    identity.village_encrypted = cipher.encrypt(data.village)
    identity.deleted_at = None
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.IDENTITY_WRITE,
        "beneficiary_identity",
        identity.id,
        site_id=beneficiary.site_id,
    )
    return identity


def delete_identity(
    ctx: ActorContext, beneficiary: Beneficiary, identity: BeneficiaryIdentity
) -> None:
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    identity.soft_delete()
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.IDENTITY_DELETE,
        "beneficiary_identity",
        identity.id,
        site_id=beneficiary.site_id,
    )


# --- Consentements ------------------------------------------------------------


def _field_time(value: datetime | None) -> datetime:
    now = utcnow()
    if value is None:
        return now
    if value > now + CLOCK_SKEW:
        raise InvalidDataError("Horodatage dans le futur.")
    return value


def get_consent(ctx: ActorContext, consent_id: uuid.UUID) -> tuple[Consent, Beneficiary]:
    consent = ctx.session.get(Consent, consent_id)
    if consent is None or consent.deleted_at is not None:
        raise NotFoundError
    return consent, get_beneficiary(ctx, consent.beneficiary_id)


def _plan_reminders_if_possible(ctx: ActorContext, beneficiary: Beneficiary) -> None:
    try:
        schedule = get_schedule(ctx.settings)
    except ScheduleUnavailableError:
        logger.warning("anc_schedule_unavailable_reminders_not_planned")
        return
    plan_reminders_for_beneficiary(ctx.session, beneficiary, schedule)


def create_consent(ctx: ActorContext, beneficiary: Beneficiary, data: ConsentCreate) -> Consent:
    ctx.ensure_role(CARE_ROLES)
    if data.id is not None and ctx.session.get(Consent, data.id) is not None:
        raise StateConflictError("Un consentement existe déjà avec cet identifiant.")
    consent = Consent(
        beneficiary_id=beneficiary.id,
        scope=data.scope,
        method=data.method,
        information_version=data.information_version,
        collected_by_user_id=ctx.actor.id,
        collected_at=_field_time(data.collected_at),
    )
    if data.id is not None:
        consent.id = data.id
    ctx.session.add(consent)
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.CONSENT_CREATE,
        "consent",
        consent.id,
        site_id=beneficiary.site_id,
    )
    if data.scope is ConsentScope.REMINDERS:
        _plan_reminders_if_possible(ctx, beneficiary)
    return consent


def _stop_linked_processing(ctx: ActorContext, consent: Consent) -> None:
    """Arrête les traitements liés : les rappels (qui portent sur le suivi RENY)
    sont annulés au retrait de ``reminders`` ou de ``reny``, sauf si un autre
    consentement actif de même portée subsiste."""
    if consent.scope in (ConsentScope.REMINDERS, ConsentScope.RENY) and not has_active_consent(
        ctx.session, consent.beneficiary_id, consent.scope
    ):
        cancel_scheduled_reminders(ctx.session, beneficiary_id=consent.beneficiary_id)


def withdraw_consent(
    ctx: ActorContext,
    consent: Consent,
    beneficiary: Beneficiary,
    *,
    withdrawn_at: datetime | None = None,
) -> Consent:
    ctx.ensure_role(CARE_ROLES)
    if consent.withdrawn_at is not None:
        raise StateConflictError("Ce consentement est déjà retiré.")
    at = _field_time(withdrawn_at)
    if at < consent.collected_at:
        raise InvalidDataError("Le retrait ne peut pas précéder le recueil.")
    consent.withdrawn_at = at
    consent.withdrawn_by_user_id = ctx.actor.id
    ctx.session.flush()
    _stop_linked_processing(ctx, consent)
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.CONSENT_WITHDRAW,
        "consent",
        consent.id,
        site_id=beneficiary.site_id,
    )
    return consent


def delete_consent(ctx: ActorContext, consent: Consent, beneficiary: Beneficiary) -> None:
    """Suppression logique (erreur de saisie) : mêmes effets qu'un retrait."""
    ctx.ensure_role(CARE_ROLES)
    consent.soft_delete()
    ctx.session.flush()
    _stop_linked_processing(ctx, consent)
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.CONSENT_DELETE,
        "consent",
        consent.id,
        site_id=beneficiary.site_id,
    )
