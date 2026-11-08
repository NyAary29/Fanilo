"""Consultation du journal d'audit : ``data_officer`` uniquement."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from pydantic import AwareDatetime, BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.pagination import Page, PageParams, page_params, paginate
from app.db.session import get_db
from app.modules.audit.models import AuditEvent
from app.modules.auth.dependencies import require_roles
from app.modules.users.roles import Role

router = APIRouter(tags=["audit"])


class AuditEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    at: datetime
    actor_user_id: uuid.UUID | None
    actor_role: str | None
    action: str
    entity_type: str | None
    entity_id: str | None
    request_id: str | None
    site_id: uuid.UUID | None


@router.get(
    "/audit",
    response_model=Page[AuditEventOut],
    summary="Journal d'audit",
    dependencies=[Depends(require_roles(Role.DATA_OFFICER))],
)
def list_audit_events(
    entity_type: str | None = Query(None, max_length=64),
    actor_user_id: uuid.UUID | None = None,
    from_: AwareDatetime | None = Query(None, alias="from"),  # noqa: B008
    to: AwareDatetime | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> dict:
    """Événements du plus récent au plus ancien. ``from`` et ``to`` sont inclusifs."""
    stmt = select(AuditEvent)
    if entity_type:
        stmt = stmt.where(AuditEvent.entity_type == entity_type)
    if actor_user_id:
        stmt = stmt.where(AuditEvent.actor_user_id == actor_user_id)
    if from_:
        stmt = stmt.where(AuditEvent.at >= from_)
    if to:
        stmt = stmt.where(AuditEvent.at <= to)
    items, total = paginate(db, stmt.order_by(AuditEvent.at.desc(), AuditEvent.id), page)
    return {"items": items, "total": total}
