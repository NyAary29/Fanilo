"""Entités synchronisables : site (lecture seule), bénéficiaire, identité,
consentement, grossesse, visite CPN, alerte (lecture seule) et référence. Les
écritures réutilisent les services métier (mêmes contrôles de rôle, de
périmètre et d'audit qu'en REST)."""

import uuid
from typing import Any

from pydantic import AwareDatetime, TypeAdapter
from sqlalchemy import select

from app.core.errors import InvalidDataError, StateConflictError
from app.modules.alerts import service as aservice
from app.modules.alerts.models import Alert
from app.modules.alerts.schemas import AlertOut
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries import service as bservice
from app.modules.beneficiaries.models import Beneficiary, BeneficiaryIdentity, Consent
from app.modules.beneficiaries.schemas import (
    BeneficiaryCreate,
    BeneficiaryOut,
    BeneficiaryPatch,
    ConsentCreate,
    ConsentOut,
    IdentityPut,
)
from app.modules.referrals import service as refservice
from app.modules.referrals.models import Referral
from app.modules.referrals.schemas import ReferralCreate, ReferralOut, ReferralSyncUpdate
from app.modules.reny import service as rservice
from app.modules.reny.models import AncVisit, Pregnancy
from app.modules.reny.schemas import (
    AncVisitOut,
    AncVisitPatch,
    PregnancyCreate,
    PregnancyOut,
    PregnancyPatch,
)
from app.modules.sites.models import Site
from app.modules.sites.router import SiteOut
from app.modules.sites.scope import ActorContext, SiteScope
from app.modules.sync.registry import SyncEntity, register_sync_entity
from app.modules.users.roles import NOMINATIVE_DATA_ROLES

_datetime = TypeAdapter(AwareDatetime | None)


def _parent_id(data: dict[str, Any]) -> uuid.UUID:
    try:
        return uuid.UUID(str(data["beneficiary_id"]))
    except (KeyError, ValueError):
        raise InvalidDataError("beneficiary_id manquant ou invalide.") from None


# --- beneficiary --------------------------------------------------------------


class BeneficiaryOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        return bservice.create_beneficiary(
            ctx, BeneficiaryCreate.model_validate({**data, "id": entity_id})
        )

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        patch = BeneficiaryPatch.model_validate({**data, "version": base_version})
        return bservice.update_beneficiary(ctx, obj, patch)

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        bservice.delete_beneficiary(ctx, obj)


# --- beneficiary_identity -----------------------------------------------------


class IdentityOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        if "beneficiary_id" in data and _parent_id(data) != entity_id:
            raise InvalidDataError("L'id d'une identité est celui de la bénéficiaire.")
        beneficiary = bservice.get_beneficiary(ctx, entity_id)
        return bservice.write_identity(
            ctx, beneficiary, IdentityPut.model_validate({**data, "version": None})
        )

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        put = IdentityPut.model_validate({**data, "version": base_version})
        return bservice.write_identity(ctx, beneficiary, put, require_version=True)

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        bservice.delete_identity(ctx, beneficiary, obj)


def _audit_identity_pull(ctx: ActorContext, obj: BeneficiaryIdentity) -> None:
    beneficiary = ctx.session.get(Beneficiary, obj.beneficiary_id)
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.IDENTITY_READ,
        "beneficiary_identity",
        obj.id,
        site_id=beneficiary.site_id if beneficiary else None,
    )


# --- consent ------------------------------------------------------------------


class ConsentOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        beneficiary = bservice.get_beneficiary(ctx, _parent_id(data))
        consent = bservice.create_consent(
            ctx, beneficiary, ConsentCreate.model_validate({**data, "id": entity_id})
        )
        if data.get("withdrawn_at"):
            # Consentement recueilli puis retiré hors ligne.
            bservice.withdraw_consent(
                ctx,
                consent,
                beneficiary,
                withdrawn_at=_datetime.validate_python(data["withdrawn_at"]),
            )
        return consent

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        """Un consentement est immuable, sauf son retrait.

        - ``withdrawn_at`` renseigné sur un consentement actif : retrait (comme
          ``POST /consents/{id}/withdraw``, rappels annulés) ;
        - ``withdrawn_at`` vidé sur un consentement retiré : refusé (il faut
          recueillir un nouveau consentement) ;
        - modification de ``scope``, ``method``, ``information_version`` ou
          ``beneficiary_id`` : refusée ; sinon, aucun changement.
        """
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        for field in ("scope", "method", "information_version", "beneficiary_id"):
            if field in data and str(data[field]) != str(getattr(obj, field)):
                raise InvalidDataError(f"Un consentement n'est pas modifiable ({field}).")
        withdrawn_at = _datetime.validate_python(data.get("withdrawn_at"))
        if obj.withdrawn_at is not None and withdrawn_at is None:
            raise StateConflictError(
                "Un retrait ne s'annule pas : recueillir un nouveau consentement."
            )
        if obj.withdrawn_at is None and withdrawn_at is not None:
            return bservice.withdraw_consent(ctx, obj, beneficiary, withdrawn_at=withdrawn_at)
        return obj

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        bservice.delete_consent(ctx, obj, beneficiary)


# --- pregnancy ----------------------------------------------------------------


class PregnancyOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        beneficiary = bservice.get_beneficiary(ctx, _parent_id(data))
        return rservice.create_pregnancy(
            ctx, beneficiary, PregnancyCreate.model_validate({**data, "id": entity_id})
        )

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        patch = PregnancyPatch.model_validate({**data, "version": base_version})
        return rservice.update_pregnancy(ctx, obj, beneficiary, patch)

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        beneficiary = bservice.get_beneficiary(ctx, obj.beneficiary_id)
        rservice.delete_pregnancy(ctx, obj, beneficiary)


# --- anc_visit ----------------------------------------------------------------


class AncVisitOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        raise InvalidDataError("Les visites CPN sont générées par le serveur.")

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        _, _, beneficiary = rservice.get_anc_visit(ctx, obj.id)
        patch = AncVisitPatch.model_validate({**data, "version": base_version})
        return rservice.update_anc_visit(ctx, obj, beneficiary, patch)

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        _, _, beneficiary = rservice.get_anc_visit(ctx, obj.id)
        rservice.delete_anc_visit(ctx, obj, beneficiary)


# --- referral -----------------------------------------------------------------


class ReferralOps:
    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any:
        return refservice.create_referral(
            ctx, ReferralCreate.model_validate({**data, "id": entity_id})
        )

    def update(self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int) -> Any:
        return refservice.update_from_sync(ctx, obj, ReferralSyncUpdate.model_validate(data))

    def delete(self, ctx: ActorContext, obj: Any) -> None:
        refservice.delete_referral(ctx, obj)


# --- requêtes de périmètre ----------------------------------------------------


def _beneficiaries(scope: SiteScope):
    return select(Beneficiary).where(scope.filter(Beneficiary.site_id))


def _identities(scope: SiteScope):
    return (
        select(BeneficiaryIdentity)
        .join(Beneficiary, BeneficiaryIdentity.beneficiary_id == Beneficiary.id)
        .where(scope.filter(Beneficiary.site_id))
    )


def _consents(scope: SiteScope):
    return (
        select(Consent)
        .join(Beneficiary, Consent.beneficiary_id == Beneficiary.id)
        .where(scope.filter(Beneficiary.site_id))
    )


def _pregnancies(scope: SiteScope):
    return (
        select(Pregnancy)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(scope.filter(Beneficiary.site_id))
    )


def _anc_visits(scope: SiteScope):
    return (
        select(AncVisit)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(scope.filter(Beneficiary.site_id))
    )


def _alerts(scope: SiteScope):
    return select(Alert).where(scope.filter(Alert.site_id))


def _dump(schema):
    return lambda _ctx, obj: schema.model_validate(obj).model_dump(mode="json")


def register_builtin_entities() -> None:
    """Enregistre les entités de ce lot (idempotent)."""
    from app.modules.sync.registry import REGISTRY

    if "beneficiary" in REGISTRY:
        return
    care = bservice.CARE_ROLES
    # Sites : lecture seule, tous visibles (choix de to_site_id hors ligne).
    register_sync_entity(
        SyncEntity(
            name="site",
            model=Site,
            rank=5,
            scoped_select=lambda _scope: select(Site),
            serialize=_dump(SiteOut),
            pull_roles=None,
            push=None,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="beneficiary",
            model=Beneficiary,
            rank=10,
            scoped_select=_beneficiaries,
            serialize=_dump(BeneficiaryOut),
            pull_roles=None,
            push=BeneficiaryOps(),
            push_roles=care,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="beneficiary_identity",
            model=BeneficiaryIdentity,
            rank=20,
            scoped_select=_identities,
            serialize=lambda ctx, obj: bservice.serialize_identity(ctx, obj).model_dump(
                mode="json"
            ),
            pull_roles=NOMINATIVE_DATA_ROLES,
            push=IdentityOps(),
            push_roles=NOMINATIVE_DATA_ROLES,
            nominative=True,
            on_pull=_audit_identity_pull,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="consent",
            model=Consent,
            rank=30,
            scoped_select=_consents,
            serialize=_dump(ConsentOut),
            pull_roles=None,
            push=ConsentOps(),
            push_roles=care,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="pregnancy",
            model=Pregnancy,
            rank=40,
            scoped_select=_pregnancies,
            serialize=_dump(PregnancyOut),
            pull_roles=None,
            push=PregnancyOps(),
            push_roles=care,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="anc_visit",
            model=AncVisit,
            rank=50,
            scoped_select=_anc_visits,
            serialize=_dump(AncVisitOut),
            pull_roles=None,
            push=AncVisitOps(),
            push_roles=care,
        )
    )
    # Alertes : lecture seule (créées par le serveur à partir des règles).
    register_sync_entity(
        SyncEntity(
            name="alert",
            model=Alert,
            rank=60,
            scoped_select=_alerts,
            serialize=_dump(AlertOut),
            pull_roles=aservice.READ_ROLES,
            push=None,
        )
    )
    register_sync_entity(
        SyncEntity(
            name="referral",
            model=Referral,
            rank=70,
            scoped_select=refservice.scoped_select,
            serialize=_dump(ReferralOut),
            pull_roles=refservice.READ_ROLES,
            push=ReferralOps(),
            push_roles=refservice.WRITE_ROLES,
        )
    )
