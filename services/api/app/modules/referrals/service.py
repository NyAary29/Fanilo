"""Références : création, machine à états stricte, mêmes règles en REST et en sync.

Transitions autorisées (toute autre renvoie 409, code ``invalid_transition``) :

- ``proposed`` → ``accepted`` ou ``not_completed`` ;
- ``accepted`` → ``arrived``, ``transferred`` ou ``not_completed`` ;
- ``transferred`` → ``arrived`` ou ``not_completed``.

``not_completed`` exige un motif (``reason``) dans la demande (422 sinon).

Périmètre : une référence est visible si le site de la bénéficiaire **ou** le
site destinataire (``to_site_id``) est dans le périmètre de l'utilisateur
(la structure qui reçoit doit pouvoir accepter et confirmer l'arrivée).
"""

import uuid

from sqlalchemy import Select, or_, select

from app.core.errors import InvalidDataError, NotFoundError, StateConflictError
from app.modules.alerts.models import Alert
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import Beneficiary
from app.modules.beneficiaries.service import get_beneficiary
from app.modules.referrals.models import Referral, ReferralStatus
from app.modules.referrals.schemas import ReferralCreate, ReferralSyncUpdate
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext, SiteScope
from app.modules.users.roles import Role

READ_ROLES: frozenset[Role] = frozenset(
    {Role.COMMUNITY_AGENT, Role.CSB_HEAD, Role.CLINICAL_ADVISOR, Role.CLINICAL_LEAD}
)
# clinical_lead : lecture seule.
WRITE_ROLES: frozenset[Role] = frozenset(
    {Role.COMMUNITY_AGENT, Role.CSB_HEAD, Role.CLINICAL_ADVISOR}
)
TRANSITIONS: dict[ReferralStatus, frozenset[ReferralStatus]] = {
    ReferralStatus.PROPOSED: frozenset({ReferralStatus.ACCEPTED, ReferralStatus.NOT_COMPLETED}),
    ReferralStatus.ACCEPTED: frozenset(
        {ReferralStatus.ARRIVED, ReferralStatus.TRANSFERRED, ReferralStatus.NOT_COMPLETED}
    ),
    ReferralStatus.TRANSFERRED: frozenset({ReferralStatus.ARRIVED, ReferralStatus.NOT_COMPLETED}),
}
IMMUTABLE_FIELDS = ("beneficiary_id", "alert_id", "from_site_id", "to_site_id")


def scoped_select(scope: SiteScope) -> Select:
    """Références visibles (lignes supprimées comprises)."""
    return (
        select(Referral)
        .join(Beneficiary, Referral.beneficiary_id == Beneficiary.id)
        .where(or_(scope.filter(Beneficiary.site_id), scope.filter(Referral.to_site_id)))
    )


def get_referral(ctx: ActorContext, referral_id: uuid.UUID) -> Referral:
    ctx.ensure_role(READ_ROLES)
    referral = ctx.session.scalar(scoped_select(ctx.scope).where(Referral.id == referral_id))
    if referral is None or referral.deleted_at is not None:
        raise NotFoundError
    return referral


def _clean(text: str | None) -> str | None:
    if text is None:
        return None
    return text.strip() or None


def _ensure_site(ctx: ActorContext, site_id: uuid.UUID | None, label: str) -> None:
    if site_id is not None and ctx.session.get(Site, site_id) is None:
        raise InvalidDataError(f"{label} introuvable.")


def create_referral(ctx: ActorContext, data: ReferralCreate) -> Referral:
    ctx.ensure_role(WRITE_ROLES)
    session = ctx.session
    if data.id is not None and session.get(Referral, data.id) is not None:
        raise StateConflictError("Une référence existe déjà avec cet identifiant.")
    if data.status is not ReferralStatus.PROPOSED:
        raise StateConflictError("Une référence est créée au statut « proposed ».")
    beneficiary = get_beneficiary(ctx, data.beneficiary_id)
    _ensure_site(ctx, data.to_site_id, "Site destinataire")
    _ensure_site(ctx, data.from_site_id, "Site d'origine")
    if data.alert_id is not None:
        alert = session.get(Alert, data.alert_id)
        if alert is None or alert.deleted_at is not None or not ctx.scope.contains(alert.site_id):
            raise InvalidDataError("Alerte introuvable.")
        if alert.beneficiary_id is not None and alert.beneficiary_id != beneficiary.id:
            raise InvalidDataError("L'alerte concerne une autre bénéficiaire.")
    referral = Referral(
        beneficiary_id=beneficiary.id,
        alert_id=data.alert_id,
        from_site_id=data.from_site_id or beneficiary.site_id,
        to_site_id=data.to_site_id,
        status=ReferralStatus.PROPOSED,
        reason=_clean(data.reason),
        outcome_note=_clean(data.outcome_note),
    )
    if data.id is not None:
        referral.id = data.id
    session.add(referral)
    session.flush()
    record_audit(
        session,
        ctx.actor,
        AuditAction.REFERRAL_CREATE,
        "referral",
        referral.id,
        site_id=beneficiary.site_id,
    )
    return referral


def _site_of(ctx: ActorContext, referral: Referral) -> uuid.UUID | None:
    beneficiary = ctx.session.get(Beneficiary, referral.beneficiary_id)
    return beneficiary.site_id if beneficiary is not None else None


def transition(
    ctx: ActorContext,
    referral: Referral,
    to_status: ReferralStatus,
    *,
    reason: str | None = None,
    outcome_note: str | None = None,
) -> Referral:
    ctx.ensure_role(WRITE_ROLES)
    if to_status not in TRANSITIONS.get(referral.status, frozenset()):
        raise StateConflictError(
            f"Transition interdite : « {referral.status} » → « {to_status} ».",
            code="invalid_transition",
        )
    reason = _clean(reason)
    if to_status is ReferralStatus.NOT_COMPLETED and reason is None:
        raise InvalidDataError("Un motif (reason) est obligatoire pour « not_completed ».")
    referral.status = to_status
    if reason is not None:
        referral.reason = reason
    if outcome_note is not None:
        referral.outcome_note = _clean(outcome_note)
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.REFERRAL_TRANSITION,
        "referral",
        referral.id,
        site_id=_site_of(ctx, referral),
    )
    return referral


def update_from_sync(ctx: ActorContext, referral: Referral, data: ReferralSyncUpdate) -> Referral:
    """Mise à jour par la synchronisation : mêmes règles que ``/transition``.

    Les champs d'identité de la référence sont immuables ; un changement de
    ``status`` passe par la machine à états ; sinon seuls ``reason`` et
    ``outcome_note`` sont modifiables.
    """
    ctx.ensure_role(WRITE_ROLES)
    sent = data.model_dump(exclude_unset=True)
    for field in IMMUTABLE_FIELDS:
        if field in sent and sent[field] != getattr(referral, field):
            raise InvalidDataError(f"Champ non modifiable d'une référence : {field}.")
    if data.status is not None and data.status != referral.status:
        return transition(
            ctx, referral, data.status, reason=data.reason, outcome_note=data.outcome_note
        )
    changed = False
    for field in ("reason", "outcome_note"):
        if field in sent and _clean(sent[field]) != getattr(referral, field):
            setattr(referral, field, _clean(sent[field]))
            changed = True
    if changed:
        ctx.session.flush()
        record_audit(
            ctx.session,
            ctx.actor,
            AuditAction.REFERRAL_UPDATE,
            "referral",
            referral.id,
            site_id=_site_of(ctx, referral),
        )
    return referral


def delete_referral(ctx: ActorContext, referral: Referral) -> None:
    """Suppression logique (erreur de saisie), seulement au statut ``proposed``."""
    ctx.ensure_role(WRITE_ROLES)
    if referral.status is not ReferralStatus.PROPOSED:
        raise StateConflictError(
            "Seule une référence « proposed » peut être supprimée.", code="invalid_transition"
        )
    referral.soft_delete()
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.REFERRAL_DELETE,
        "referral",
        referral.id,
        site_id=_site_of(ctx, referral),
    )
