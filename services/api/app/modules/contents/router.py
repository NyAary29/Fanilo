"""Endpoints des contenus de santé (section 5 du contrat)."""

import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from app.core.pagination import Page, PageParams, page_params, paginate
from app.modules.contents import service
from app.modules.contents.models import ContentItem, ContentLanguage, ContentModule, ContentStatus
from app.modules.contents.schemas import ContentCreate, ContentOut, ContentPatch, NoteBody
from app.modules.sites.scope import ActorContext, get_actor_context

router = APIRouter(prefix="/contents", tags=["contenus"])


@router.get(
    "/published",
    response_model=Page[ContentOut],
    summary="Contenus publiés (validated, plus demo en mode démo)",
)
def list_published(
    module: ContentModule | None = None,
    language: ContentLanguage | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    items = service.list_published(ctx.session, ctx.settings, module=module, language=language)
    return {"items": items[page.offset : page.offset + page.limit], "total": len(items)}


@router.get("", response_model=Page[ContentOut], summary="Lister (gestion, tous statuts)")
def list_contents(
    status: ContentStatus | None = None,
    module: ContentModule | None = None,
    language: ContentLanguage | None = None,
    code: str | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    ctx.ensure_role(service.MANAGE_ROLES)
    stmt = select(ContentItem)
    if status is not None:
        stmt = stmt.where(ContentItem.status == status)
    if module is not None:
        stmt = stmt.where(ContentItem.module == module)
    if language is not None:
        stmt = stmt.where(ContentItem.language == language)
    if code is not None:
        stmt = stmt.where(ContentItem.code == code)
    stmt = stmt.order_by(ContentItem.code, ContentItem.language, ContentItem.version)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "",
    response_model=ContentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un brouillon (version 1)",
)
def create_content(
    body: ContentCreate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.create_content(ctx, body)
    ctx.session.commit()
    return item


@router.get("/{content_id}", response_model=ContentOut, summary="Détail (gestion)")
def get_content(
    content_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    return service.get_content(ctx, content_id)


@router.patch("/{content_id}", response_model=ContentOut, summary="Modifier un brouillon")
def update_content(
    content_id: uuid.UUID,
    body: ContentPatch,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.update_content(ctx, service.get_content(ctx, content_id), body)
    ctx.session.commit()
    return item


@router.post(
    "/{content_id}/new-version",
    response_model=ContentOut,
    status_code=status.HTTP_201_CREATED,
    summary="Nouvelle version (brouillon) d'un contenu validé",
)
def new_version(
    content_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.new_version(ctx, service.get_content(ctx, content_id))
    ctx.session.commit()
    return item


@router.post("/{content_id}/submit", response_model=ContentOut, summary="Soumettre à la revue")
def submit_content(
    content_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.submit_content(ctx, service.get_content(ctx, content_id))
    ctx.session.commit()
    return item


@router.post("/{content_id}/reject", response_model=ContentOut, summary="Rejeter (note)")
def reject_content(
    content_id: uuid.UUID,
    body: NoteBody,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.reject_content(ctx, service.get_content(ctx, content_id), body.note)
    ctx.session.commit()
    return item


@router.post(
    "/{content_id}/validate",
    response_model=ContentOut,
    summary="Valider (responsable clinique, jamais l'auteur)",
)
def validate_content(
    content_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.validate_content(ctx, service.get_content(ctx, content_id))
    ctx.session.commit()
    return item


@router.post("/{content_id}/retire", response_model=ContentOut, summary="Retirer")
def retire_content(
    content_id: uuid.UUID,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> ContentItem:
    item = service.retire_content(ctx, service.get_content(ctx, content_id))
    ctx.session.commit()
    return item
