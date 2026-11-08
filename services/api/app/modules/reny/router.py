"""Endpoints RENY (section 4 du contrat)."""

import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, Query
from fastapi import status as http_status
from sqlalchemy import select

from app.core.pagination import Page, PageParams, page_params, paginate
from app.db.types import utcnow
from app.modules.beneficiaries.models import Beneficiary
from app.modules.beneficiaries.service import get_beneficiary
from app.modules.reny import service
from app.modules.reny.models import AncVisit, AncVisitStatus, Pregnancy, PregnancyStatus
from app.modules.reny.schemas import (
    AncVisitOut,
    AncVisitPatch,
    PregnancyCreate,
    PregnancyOut,
    PregnancyPatch,
)
from app.modules.sites.scope import ActorContext, get_actor_context

router = APIRouter(tags=["RENY"])


@router.get(
    "/beneficiaries/{beneficiary_id}/pregnancies",
    response_model=Page[PregnancyOut],
    summary="Grossesses d'une bénéficiaire",
)
def list_pregnancies(
    beneficiary_id: uuid.UUID,
    status: PregnancyStatus | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    beneficiary = get_beneficiary(ctx, beneficiary_id)
    stmt = (
        select(Pregnancy)
        .where(Pregnancy.beneficiary_id == beneficiary.id, Pregnancy.deleted_at.is_(None))
        .order_by(Pregnancy.created_at.desc(), Pregnancy.id)
    )
    if status is not None:
        stmt = stmt.where(Pregnancy.status == status)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "/beneficiaries/{beneficiary_id}/pregnancies",
    response_model=PregnancyOut,
    status_code=http_status.HTTP_201_CREATED,
    summary="Enregistrer une grossesse (consentement RENY requis, calendrier CPN généré)",
)
def create_pregnancy(
    beneficiary_id: uuid.UUID,
    body: PregnancyCreate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Pregnancy:
    beneficiary = get_beneficiary(ctx, beneficiary_id)
    pregnancy = service.create_pregnancy(ctx, beneficiary, body)
    ctx.session.commit()
    return pregnancy


@router.get("/pregnancies/{pregnancy_id}", response_model=PregnancyOut, summary="Détail")
def get_pregnancy(
    pregnancy_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Pregnancy:
    pregnancy, _ = service.get_pregnancy(ctx, pregnancy_id)
    return pregnancy


@router.patch("/pregnancies/{pregnancy_id}", response_model=PregnancyOut, summary="Modifier")
def update_pregnancy(
    pregnancy_id: uuid.UUID,
    body: PregnancyPatch,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Pregnancy:
    pregnancy, beneficiary = service.get_pregnancy(ctx, pregnancy_id)
    service.update_pregnancy(ctx, pregnancy, beneficiary, body)
    ctx.session.commit()
    return pregnancy


@router.get(
    "/pregnancies/{pregnancy_id}/anc-visits",
    response_model=Page[AncVisitOut],
    summary="Visites CPN d'une grossesse",
)
def list_anc_visits(
    pregnancy_id: uuid.UUID,
    status: AncVisitStatus | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    pregnancy, _ = service.get_pregnancy(ctx, pregnancy_id)
    stmt = (
        select(AncVisit)
        .where(AncVisit.pregnancy_id == pregnancy.id, AncVisit.deleted_at.is_(None))
        .order_by(AncVisit.sequence, AncVisit.scheduled_date)
    )
    if status is not None:
        stmt = stmt.where(AncVisit.status == status)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.get(
    "/anc-visits/upcoming",
    response_model=Page[AncVisitOut],
    summary="Visites CPN planifiées des prochains jours (périmètre du site)",
)
def upcoming_anc_visits(
    days: int = Query(7, ge=1, le=90),
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    today = utcnow().date()
    stmt = (
        select(AncVisit)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            AncVisit.status == AncVisitStatus.PLANNED,
            AncVisit.deleted_at.is_(None),
            AncVisit.scheduled_date >= today,
            AncVisit.scheduled_date <= today + timedelta(days=days),
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
            Beneficiary.deleted_at.is_(None),
            ctx.scope.filter(Beneficiary.site_id),
        )
        .order_by(AncVisit.scheduled_date, AncVisit.id)
    )
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.patch(
    "/anc-visits/{visit_id}",
    response_model=AncVisitOut,
    summary="Marquer done / missed, ou replanifier",
)
def update_anc_visit(
    visit_id: uuid.UUID,
    body: AncVisitPatch,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> AncVisit:
    visit, _, beneficiary = service.get_anc_visit(ctx, visit_id)
    service.update_anc_visit(ctx, visit, beneficiary, body)
    ctx.session.commit()
    return visit
