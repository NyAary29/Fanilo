"""Endpoints des bénéficiaires, identités et consentements (section 3 du contrat)."""

import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from app.core.pagination import Page, PageParams, page_params, paginate
from app.modules.beneficiaries import service
from app.modules.beneficiaries.models import Beneficiary, Consent
from app.modules.beneficiaries.schemas import (
    BeneficiaryCreate,
    BeneficiaryOut,
    BeneficiaryPatch,
    ConsentCreate,
    ConsentOut,
    IdentityOut,
    IdentityPut,
)
from app.modules.sites.scope import ActorContext, get_actor_context
from app.modules.users.roles import NOMINATIVE_DATA_ROLES

router = APIRouter(tags=["bénéficiaires"])


@router.get("/beneficiaries", response_model=Page[BeneficiaryOut], summary="Lister")
def list_beneficiaries(
    site_id: uuid.UUID | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    stmt = select(Beneficiary).where(
        Beneficiary.deleted_at.is_(None), ctx.scope.filter(Beneficiary.site_id)
    )
    if site_id is not None:
        stmt = stmt.where(Beneficiary.site_id == site_id)
    stmt = stmt.order_by(Beneficiary.created_at, Beneficiary.id)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "/beneficiaries",
    response_model=BeneficiaryOut,
    status_code=status.HTTP_201_CREATED,
    summary="Créer une bénéficiaire (sans nom)",
)
def create_beneficiary(
    body: BeneficiaryCreate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Beneficiary:
    beneficiary = service.create_beneficiary(ctx, body)
    ctx.session.commit()
    return beneficiary


@router.get("/beneficiaries/{beneficiary_id}", response_model=BeneficiaryOut, summary="Détail")
def get_beneficiary(
    beneficiary_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Beneficiary:
    return service.get_beneficiary(ctx, beneficiary_id)


@router.patch(
    "/beneficiaries/{beneficiary_id}",
    response_model=BeneficiaryOut,
    summary="Modifier (version obligatoire, 409 sinon)",
)
def update_beneficiary(
    beneficiary_id: uuid.UUID,
    body: BeneficiaryPatch,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Beneficiary:
    beneficiary = service.get_beneficiary(ctx, beneficiary_id)
    service.update_beneficiary(ctx, beneficiary, body)
    ctx.session.commit()
    return beneficiary


@router.get(
    "/beneficiaries/{beneficiary_id}/identity",
    response_model=IdentityOut,
    summary="Identité nominative (rôles nominatifs, auditée)",
)
def get_identity(
    beneficiary_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> IdentityOut:
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    beneficiary = service.get_beneficiary(ctx, beneficiary_id)
    identity = service.read_identity(ctx, beneficiary)
    ctx.session.commit()
    return identity


@router.put(
    "/beneficiaries/{beneficiary_id}/identity",
    response_model=IdentityOut,
    summary="Créer ou remplacer l'identité (chiffrée au repos)",
)
def put_identity(
    beneficiary_id: uuid.UUID,
    body: IdentityPut,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> IdentityOut:
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    beneficiary = service.get_beneficiary(ctx, beneficiary_id)
    identity = service.write_identity(ctx, beneficiary, body)
    ctx.session.commit()
    return service.serialize_identity(ctx, identity)


@router.get(
    "/beneficiaries/{beneficiary_id}/consents",
    response_model=Page[ConsentOut],
    summary="Consentements",
)
def list_consents(
    beneficiary_id: uuid.UUID,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    beneficiary = service.get_beneficiary(ctx, beneficiary_id)
    stmt = (
        select(Consent)
        .where(Consent.beneficiary_id == beneficiary.id, Consent.deleted_at.is_(None))
        .order_by(Consent.collected_at, Consent.id)
    )
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "/beneficiaries/{beneficiary_id}/consents",
    response_model=ConsentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un consentement",
)
def create_consent(
    beneficiary_id: uuid.UUID,
    body: ConsentCreate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Consent:
    beneficiary = service.get_beneficiary(ctx, beneficiary_id)
    consent = service.create_consent(ctx, beneficiary, body)
    ctx.session.commit()
    return consent


@router.post(
    "/consents/{consent_id}/withdraw",
    response_model=ConsentOut,
    summary="Retirer un consentement (arrête les traitements liés)",
)
def withdraw_consent(
    consent_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Consent:
    consent, beneficiary = service.get_consent(ctx, consent_id)
    service.withdraw_consent(ctx, consent, beneficiary)
    ctx.session.commit()
    return consent
