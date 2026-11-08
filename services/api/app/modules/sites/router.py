"""Endpoints des sites : lecture pour tous, écriture par ``admin``."""

import uuid

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import InvalidDataError, NotFoundError, StateConflictError
from app.core.pagination import Page, PageParams, page_params, paginate
from app.db.session import get_db
from app.modules.audit.service import AuditAction, record_audit
from app.modules.auth.dependencies import get_current_user, require_roles
from app.modules.sites.models import Site, SiteKind
from app.modules.sites.scope import descendant_site_ids
from app.modules.users.models import User
from app.modules.users.roles import Role

router = APIRouter(prefix="/sites", tags=["sites"])


class SiteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    kind: SiteKind
    code: str
    district: str
    region: str
    parent_site_id: uuid.UUID | None
    is_active: bool


class SiteCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)
    kind: SiteKind
    code: str = Field(min_length=1, max_length=32)
    district: str = Field(min_length=1, max_length=100)
    region: str = Field(min_length=1, max_length=100)
    parent_site_id: uuid.UUID | None = None
    is_active: bool = True


class SitePatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(None, min_length=1, max_length=200)
    kind: SiteKind | None = None
    code: str | None = Field(None, min_length=1, max_length=32)
    district: str | None = Field(None, min_length=1, max_length=100)
    region: str | None = Field(None, min_length=1, max_length=100)
    parent_site_id: uuid.UUID | None = None
    is_active: bool | None = None


def _normalize_code(code: str) -> str:
    return code.strip().upper()


def _ensure_code_free(db: Session, code: str, exclude: uuid.UUID | None = None) -> None:
    existing = db.scalar(select(Site).where(Site.code == code))
    if existing is not None and existing.id != exclude:
        raise StateConflictError("Ce code de site est déjà utilisé.")


def _ensure_parent(db: Session, parent_id: uuid.UUID | None) -> None:
    if parent_id is not None and db.get(Site, parent_id) is None:
        raise InvalidDataError("Site parent introuvable.")


@router.get("", response_model=Page[SiteOut], summary="Lister les sites")
def list_sites(
    kind: SiteKind | None = None,
    is_active: bool | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    _user: User = Depends(get_current_user),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> dict:
    stmt = select(Site)
    if kind is not None:
        stmt = stmt.where(Site.kind == kind)
    if is_active is not None:
        stmt = stmt.where(Site.is_active == is_active)
    items, total = paginate(db, stmt.order_by(Site.code), page)
    return {"items": items, "total": total}


@router.get("/{site_id}", response_model=SiteOut, summary="Détail d'un site")
def get_site(
    site_id: uuid.UUID,
    _user: User = Depends(get_current_user),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> Site:
    site = db.get(Site, site_id)
    if site is None:
        raise NotFoundError
    return site


@router.post(
    "", response_model=SiteOut, status_code=status.HTTP_201_CREATED, summary="Créer un site"
)
def create_site(
    body: SiteCreate,
    admin: User = Depends(require_roles(Role.ADMIN)),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> Site:
    code = _normalize_code(body.code)
    _ensure_code_free(db, code)
    _ensure_parent(db, body.parent_site_id)
    site = Site(**(body.model_dump() | {"code": code}))
    db.add(site)
    db.flush()
    record_audit(db, admin, AuditAction.SITE_CREATE, "site", site.id, site_id=site.id)
    db.commit()
    return site


@router.patch("/{site_id}", response_model=SiteOut, summary="Modifier ou désactiver un site")
def update_site(
    site_id: uuid.UUID,
    body: SitePatch,
    admin: User = Depends(require_roles(Role.ADMIN)),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> Site:
    site = db.get(Site, site_id)
    if site is None:
        raise NotFoundError
    changes = body.model_dump(exclude_unset=True)
    for field in ("name", "kind", "code", "district", "region", "is_active"):
        if field in changes and changes[field] is None:
            raise InvalidDataError(f"Le champ {field} ne peut pas être nul.")
    if "code" in changes:
        changes["code"] = _normalize_code(changes["code"])
        _ensure_code_free(db, changes["code"], exclude=site.id)
    if "parent_site_id" in changes and changes["parent_site_id"] is not None:
        parent_id = changes["parent_site_id"]
        _ensure_parent(db, parent_id)
        if parent_id in descendant_site_ids(db, site.id):
            raise InvalidDataError(
                "Un site ne peut pas être rattaché à lui-même ou à un descendant."
            )
    for field, value in changes.items():
        setattr(site, field, value)
    db.flush()
    record_audit(db, admin, AuditAction.SITE_UPDATE, "site", site.id, site_id=site.id)
    db.commit()
    return site
