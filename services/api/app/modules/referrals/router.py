"""Endpoints des références (section 7 du contrat)."""

import uuid

from fastapi import APIRouter, Depends
from fastapi import status as http_status

from app.core.pagination import Page, PageParams, page_params, paginate
from app.modules.referrals import service
from app.modules.referrals.models import Referral, ReferralStatus
from app.modules.referrals.schemas import ReferralCreate, ReferralOut, ReferralTransition
from app.modules.sites.scope import ActorContext, get_actor_context

router = APIRouter(prefix="/referrals", tags=["références"])


@router.get("", response_model=Page[ReferralOut], summary="Lister (périmètre du site)")
def list_referrals(
    status: ReferralStatus | None = None,
    beneficiary_id: uuid.UUID | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    ctx.ensure_role(service.READ_ROLES)
    stmt = service.scoped_select(ctx.scope).where(Referral.deleted_at.is_(None))
    if status is not None:
        stmt = stmt.where(Referral.status == status)
    if beneficiary_id is not None:
        stmt = stmt.where(Referral.beneficiary_id == beneficiary_id)
    stmt = stmt.order_by(Referral.created_at, Referral.id)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "",
    response_model=ReferralOut,
    status_code=http_status.HTTP_201_CREATED,
    summary="Créer une référence (éventuellement depuis une alerte)",
)
def create_referral(
    body: ReferralCreate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Referral:
    referral = service.create_referral(ctx, body)
    ctx.session.commit()
    return referral


@router.get("/{referral_id}", response_model=ReferralOut, summary="Détail")
def get_referral(
    referral_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Referral:
    return service.get_referral(ctx, referral_id)


@router.post(
    "/{referral_id}/transition", response_model=ReferralOut, summary="Changer de statut"
)
def transition(
    referral_id: uuid.UUID,
    body: ReferralTransition,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Referral:
    ctx.ensure_role(service.WRITE_ROLES)
    referral = service.get_referral(ctx, referral_id)
    service.transition(
        ctx, referral, body.to_status, reason=body.reason, outcome_note=body.outcome_note
    )
    ctx.session.commit()
    return referral
