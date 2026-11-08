"""Gestion des comptes : lecture par ``admin`` et ``data_officer``, écriture par ``admin``."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.errors import InvalidDataError, NotFoundError, StateConflictError
from app.core.pagination import Page, PageParams, page_params, paginate
from app.db.session import get_db
from app.db.types import utcnow
from app.modules.audit.service import AuditAction, record_audit
from app.modules.auth.dependencies import require_roles
from app.modules.auth.models import RefreshToken
from app.modules.sites.models import Site
from app.modules.sites.scope import SiteScope, get_site_scope
from app.modules.users.models import LOGIN_MAX_LENGTH, User
from app.modules.users.roles import Role
from app.modules.users.service import UserError, create_user

router = APIRouter(prefix="/users", tags=["utilisateurs"])


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    login: str
    role: Role
    site_id: uuid.UUID | None
    is_active: bool
    last_login_at: datetime | None


class DirectoryEntry(BaseModel):
    """Annuaire minimal : ni état du compte ni date de connexion."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    login: str
    role: Role
    site_id: uuid.UUID | None


DIRECTORY_ROLES = tuple(r for r in Role if r is not Role.TECHNICAL)


class UserCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    login: str = Field(min_length=1, max_length=LOGIN_MAX_LENGTH)
    password: str = Field(min_length=1, max_length=1024)
    role: Role
    site_id: uuid.UUID | None = None


class UserPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: Role | None = None
    site_id: uuid.UUID | None = None
    is_active: bool | None = None


def _ensure_site(db: Session, site_id: uuid.UUID | None) -> None:
    if site_id is not None and db.get(Site, site_id) is None:
        raise InvalidDataError("Site introuvable.")


@router.get(
    "",
    response_model=Page[UserOut],
    summary="Lister les comptes",
    dependencies=[Depends(require_roles(Role.ADMIN, Role.DATA_OFFICER))],
)
def list_users(
    role: Role | None = None,
    site_id: uuid.UUID | None = None,
    is_active: bool | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> dict:
    stmt = select(User).where(User.deleted_at.is_(None))
    if role is not None:
        stmt = stmt.where(User.role == role)
    if site_id is not None:
        stmt = stmt.where(User.site_id == site_id)
    if is_active is not None:
        stmt = stmt.where(User.is_active == is_active)
    items, total = paginate(db, stmt.order_by(User.login), page)
    return {"items": items, "total": total}


@router.get(
    "/directory",
    response_model=Page[DirectoryEntry],
    summary="Annuaire des comptes du périmètre (tout rôle sauf technical)",
    dependencies=[Depends(require_roles(*DIRECTORY_ROLES))],
)
def user_directory(
    role: Role | None = None,
    site_id: uuid.UUID | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    scope: SiteScope = Depends(get_site_scope),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> dict:
    """Comptes actifs rattachés à un site du périmètre (tous en vue globale)."""
    stmt = select(User).where(
        User.deleted_at.is_(None), User.is_active.is_(True), scope.filter(User.site_id)
    )
    if role is not None:
        stmt = stmt.where(User.role == role)
    if site_id is not None:
        stmt = stmt.where(User.site_id == site_id)
    items, total = paginate(db, stmt.order_by(User.login), page)
    return {"items": items, "total": total}


@router.post(
    "", response_model=UserOut, status_code=status.HTTP_201_CREATED, summary="Créer un compte"
)
def create_account(
    body: UserCreate,
    admin: User = Depends(require_roles(Role.ADMIN)),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> User:
    _ensure_site(db, body.site_id)
    try:
        user = create_user(
            db, login=body.login, password=body.password, role=body.role, site_id=body.site_id
        )
    except UserError as exc:
        if "déjà utilisé" in str(exc):
            raise StateConflictError(str(exc)) from None
        raise InvalidDataError(str(exc)) from None
    record_audit(db, admin, AuditAction.USER_CREATE, "user", user.id, site_id=user.site_id)
    db.commit()
    return user


@router.patch("/{user_id}", response_model=UserOut, summary="Modifier ou désactiver un compte")
def update_account(
    user_id: uuid.UUID,
    body: UserPatch,
    admin: User = Depends(require_roles(Role.ADMIN)),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> User:
    user = db.get(User, user_id)
    if user is None or user.deleted_at is not None:
        raise NotFoundError
    changes = body.model_dump(exclude_unset=True)
    if changes.get("role", ...) is None or changes.get("is_active", ...) is None:
        raise InvalidDataError("role et is_active ne peuvent pas être nuls.")
    if user.id == admin.id and (
        changes.get("is_active") is False or changes.get("role", Role.ADMIN) is not Role.ADMIN
    ):
        raise StateConflictError(
            "Un administrateur ne peut ni se désactiver ni retirer son propre rôle."
        )
    if "site_id" in changes:
        _ensure_site(db, changes["site_id"])

    role_changed = "role" in changes and changes["role"] is not user.role
    deactivated = changes.get("is_active") is False and user.is_active
    for field, value in changes.items():
        setattr(user, field, value)
    if deactivated or role_changed:
        # Les sessions ouvertes sont révoquées : le compte doit se reconnecter.
        db.execute(
            update(RefreshToken)
            .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
            .values(revoked_at=utcnow())
        )
    db.flush()
    record_audit(db, admin, AuditAction.USER_UPDATE, "user", user.id, site_id=user.site_id)
    if role_changed:
        record_audit(db, admin, AuditAction.USER_ROLE_CHANGE, "user", user.id, site_id=user.site_id)
    if deactivated:
        record_audit(db, admin, AuditAction.USER_DEACTIVATE, "user", user.id, site_id=user.site_id)
    db.commit()
    return user
