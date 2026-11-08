"""Endpoints de synchronisation hors ligne (section 8 du contrat)."""

from fastapi import APIRouter, Depends, Query

from app.modules.sites.scope import ActorContext, get_actor_context
from app.modules.sync import service
from app.modules.sync.entities import register_builtin_entities

router = APIRouter(prefix="/sync", tags=["synchronisation"])

register_builtin_entities()


@router.get("/pull", response_model=service.PullResponse, summary="Récupérer les modifications")
def pull(
    since: str | None = Query(None, max_length=512),
    limit: int = Query(500, ge=1, le=service.MAX_PULL_LIMIT),
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> service.PullResponse:
    return service.pull(ctx, since, limit)


@router.post("/push", response_model=service.PushResponse, summary="Envoyer des modifications")
def push(
    body: service.PushRequest,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> service.PushResponse:
    return service.push(ctx, body)
