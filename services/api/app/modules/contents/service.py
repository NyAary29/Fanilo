"""Cycle de vie des contenus et résolution des contenus publiés.

Transitions (contrat, section 5) :

- création : ``draft`` (version 1) ;
- ``draft`` → ``in_review`` (soumission) ;
- ``in_review`` → ``draft`` (rejet, ``clinical_lead``, avec note) ;
- ``in_review`` → ``validated`` (``clinical_lead`` uniquement, jamais l'auteur) :
  la version ``validated`` précédente du même (``code``, ``language``) passe à
  ``retired`` ;
- ``validated`` ou ``demo`` → ``retired`` (``clinical_lead``) ;
- ``validated`` → nouvelle version ``draft`` (copie, version + 1) ; la version
  validée reste servie jusqu'à la validation de la nouvelle.

Toute autre opération renvoie 409. Les fonctions appliquent rôle et audit puis
``flush`` sans valider.
"""

import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ForbiddenError, InvalidDataError, NotFoundError, StateConflictError
from app.db.types import utcnow
from app.modules.audit.service import AuditAction, record_audit
from app.modules.contents.models import ContentItem, ContentLanguage, ContentModule, ContentStatus
from app.modules.contents.schemas import ContentCreate, ContentPatch
from app.modules.sites.scope import ActorContext
from app.modules.users.roles import Role

MANAGE_ROLES: frozenset[Role] = frozenset({Role.CLINICAL_LEAD, Role.ADMIN})
VALIDATOR_ROLES: frozenset[Role] = frozenset({Role.CLINICAL_LEAD})
# Ordre de repli des langues pour la réponse servie à l'usager.
FALLBACK_LANGUAGE = ContentLanguage.FR


def published_statuses(settings: Settings) -> tuple[ContentStatus, ...]:
    """Statuts servis aux applications : ``validated``, plus ``demo`` en mode démo."""
    if settings.allow_demo_content:
        return (ContentStatus.VALIDATED, ContentStatus.DEMO)
    return (ContentStatus.VALIDATED,)


def get_content(ctx: ActorContext, content_id: uuid.UUID) -> ContentItem:
    ctx.ensure_role(MANAGE_ROLES)
    item = ctx.session.get(ContentItem, content_id)
    if item is None:
        raise NotFoundError
    return item


def _require_status(item: ContentItem, *allowed: ContentStatus) -> None:
    if item.status not in allowed:
        expected = ", ".join(str(s) for s in allowed)
        raise StateConflictError(
            f"Opération impossible au statut « {item.status} » (attendu : {expected})."
        )


def _same_code(session: Session, code: str, language: ContentLanguage):
    return select(ContentItem).where(ContentItem.code == code, ContentItem.language == language)


def create_content(ctx: ActorContext, data: ContentCreate) -> ContentItem:
    ctx.ensure_role(MANAGE_ROLES)
    session = ctx.session
    if session.scalar(_same_code(session, data.code, data.language).limit(1)) is not None:
        raise StateConflictError(
            "Un contenu existe déjà pour ce code et cette langue : créer une nouvelle version."
        )
    other_module = session.scalar(
        select(ContentItem.module).where(ContentItem.code == data.code).limit(1)
    )
    if other_module is not None and other_module != data.module:
        raise InvalidDataError("Un même code doit garder le même module dans toutes les langues.")
    item = ContentItem(
        code=data.code,
        module=data.module,
        language=data.language,
        title=data.title.strip(),
        body=data.body.strip(),
        audio_url=data.audio_url,
        source_ref=data.source_ref,
        version=1,
        status=ContentStatus.DRAFT,
        author_id=ctx.actor.id,
    )
    session.add(item)
    session.flush()
    return item


def update_content(ctx: ActorContext, item: ContentItem, data: ContentPatch) -> ContentItem:
    ctx.ensure_role(MANAGE_ROLES)
    _require_status(item, ContentStatus.DRAFT)
    changes = data.model_dump(exclude_unset=True)
    for field in ("title", "body"):
        if field in changes and changes[field] is None:
            raise InvalidDataError(f"{field} ne peut pas être nul.")
    for field, value in changes.items():
        setattr(item, field, value.strip() if field in ("title", "body") else value)
    ctx.session.flush()
    return item


def new_version(ctx: ActorContext, source: ContentItem) -> ContentItem:
    ctx.ensure_role(MANAGE_ROLES)
    _require_status(source, ContentStatus.VALIDATED)
    session = ctx.session
    open_draft = session.scalar(
        _same_code(session, source.code, source.language)
        .where(ContentItem.status.in_((ContentStatus.DRAFT, ContentStatus.IN_REVIEW)))
        .limit(1)
    )
    if open_draft is not None:
        raise StateConflictError("Une version en cours de rédaction ou de revue existe déjà.")
    last = session.scalar(
        select(func.max(ContentItem.version)).where(
            ContentItem.code == source.code, ContentItem.language == source.language
        )
    )
    item = ContentItem(
        code=source.code,
        module=source.module,
        language=source.language,
        title=source.title,
        body=source.body,
        audio_url=source.audio_url,
        source_ref=source.source_ref,
        version=(last or source.version) + 1,
        status=ContentStatus.DRAFT,
        author_id=ctx.actor.id,
    )
    session.add(item)
    session.flush()
    return item


def submit_content(ctx: ActorContext, item: ContentItem) -> ContentItem:
    ctx.ensure_role(MANAGE_ROLES)
    _require_status(item, ContentStatus.DRAFT)
    item.status = ContentStatus.IN_REVIEW
    ctx.session.flush()
    record_audit(ctx.session, ctx.actor, AuditAction.CONTENT_SUBMIT, "content", item.id)
    return item


def reject_content(ctx: ActorContext, item: ContentItem, note: str) -> ContentItem:
    ctx.ensure_role(VALIDATOR_ROLES)
    _require_status(item, ContentStatus.IN_REVIEW)
    item.status = ContentStatus.DRAFT
    item.review_note = note.strip()
    ctx.session.flush()
    record_audit(ctx.session, ctx.actor, AuditAction.CONTENT_REJECT, "content", item.id)
    return item


def validate_content(ctx: ActorContext, item: ContentItem) -> ContentItem:
    ctx.ensure_role(VALIDATOR_ROLES)
    _require_status(item, ContentStatus.IN_REVIEW)
    if item.author_id == ctx.actor.id:
        raise ForbiddenError("Un auteur ne valide pas son propre contenu.")
    session = ctx.session
    previous = session.scalars(
        _same_code(session, item.code, item.language).where(
            ContentItem.status == ContentStatus.VALIDATED, ContentItem.id != item.id
        )
    ).all()
    for old in previous:
        old.status = ContentStatus.RETIRED
        record_audit(session, ctx.actor, AuditAction.CONTENT_RETIRE, "content", old.id)
    item.status = ContentStatus.VALIDATED
    item.validator_id = ctx.actor.id
    item.validated_at = utcnow()
    session.flush()
    record_audit(session, ctx.actor, AuditAction.CONTENT_VALIDATE, "content", item.id)
    return item


def retire_content(ctx: ActorContext, item: ContentItem) -> ContentItem:
    ctx.ensure_role(VALIDATOR_ROLES)
    _require_status(item, ContentStatus.VALIDATED, ContentStatus.DEMO)
    item.status = ContentStatus.RETIRED
    ctx.session.flush()
    record_audit(ctx.session, ctx.actor, AuditAction.CONTENT_RETIRE, "content", item.id)
    return item


# --- Contenus publiés ---------------------------------------------------------


def _preference(item: ContentItem) -> tuple[int, int]:
    # Un contenu validé l'emporte toujours sur un contenu de démonstration.
    return (1 if item.status is ContentStatus.VALIDATED else 0, item.version)


def list_published(
    session: Session,
    settings: Settings,
    *,
    module: ContentModule | None = None,
    language: ContentLanguage | None = None,
) -> list[ContentItem]:
    """Contenus servis : un seul par (``code``, ``language``), le validé d'abord.

    Le filtre ``module`` (``reny`` ou ``tanora``) inclut aussi les contenus
    ``common``.
    """
    stmt = select(ContentItem).where(ContentItem.status.in_(published_statuses(settings)))
    if module is not None:
        modules = {module, ContentModule.COMMON}
        stmt = stmt.where(ContentItem.module.in_(modules))
    if language is not None:
        stmt = stmt.where(ContentItem.language == language)
    best: dict[tuple[str, str], ContentItem] = {}
    for item in session.scalars(stmt):
        key = (item.code, str(item.language))
        if key not in best or _preference(item) > _preference(best[key]):
            best[key] = item
    return sorted(best.values(), key=lambda i: (i.code, str(i.language)))


def resolve_published(
    session: Session, settings: Settings, code: str, language: ContentLanguage
) -> ContentItem | None:
    """Contenu publié pour ``code`` dans ``language``, sinon en français, sinon ``None``."""
    languages = [language] if language is FALLBACK_LANGUAGE else [language, FALLBACK_LANGUAGE]
    for lang in languages:
        items = session.scalars(
            _same_code(session, code, lang).where(
                ContentItem.status.in_(published_statuses(settings))
            )
        ).all()
        if items:
            return max(items, key=_preference)
    return None
