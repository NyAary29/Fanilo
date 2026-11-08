"""Endpoints des alertes (section 7 du contrat)."""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select

from app.core.pagination import Page, PageParams, page_params, paginate
from app.modules.alerts import service
from app.modules.alerts.models import Alert, AlertStatus
from app.modules.alerts.schemas import AlertDetail, AlertEventOut, AlertNote, AlertOut
from app.modules.sites.scope import ActorContext, get_actor_context

router = APIRouter(prefix="/alerts", tags=["alertes"])


def _detail(ctx: ActorContext, alert: Alert) -> AlertDetail:
    events = [AlertEventOut.model_validate(e) for e in service.list_events(ctx.session, alert)]
    return AlertDetail.model_validate(
        {**AlertOut.model_validate(alert).model_dump(), "events": events}
    )


@router.get("", response_model=Page[AlertOut], summary="Lister (périmètre du site)")
def list_alerts(
    status: AlertStatus | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    ctx.ensure_role(service.READ_ROLES)
    stmt = select(Alert).where(Alert.deleted_at.is_(None), ctx.scope.filter(Alert.site_id))
    if status is not None:
        stmt = stmt.where(Alert.status == status)
    stmt = stmt.order_by(Alert.due_at, Alert.id)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.get("/{alert_id}", response_model=AlertDetail, summary="Détail et journal")
def get_alert(
    alert_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> AlertDetail:
    return _detail(ctx, service.get_alert(ctx, alert_id))


@router.post("/{alert_id}/acknowledge", response_model=AlertDetail, summary="Acquitter")
def acknowledge(
    alert_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> AlertDetail:
    alert = service.acknowledge(ctx, service.get_alert(ctx, alert_id))
    ctx.session.commit()
    return _detail(ctx, alert)


@router.post("/{alert_id}/resolve", response_model=AlertDetail, summary="Résoudre (note)")
def resolve(
    alert_id: uuid.UUID,
    body: AlertNote,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> AlertDetail:
    alert = service.resolve(ctx, service.get_alert(ctx, alert_id), body.note)
    ctx.session.commit()
    return _detail(ctx, alert)


@router.post("/{alert_id}/notes", response_model=AlertDetail, summary="Ajouter une note")
def add_note(
    alert_id: uuid.UUID,
    body: AlertNote,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> AlertDetail:
    alert = service.get_alert(ctx, alert_id)
    service.add_note(ctx, alert, body.note)
    ctx.session.commit()
    return _detail(ctx, alert)
