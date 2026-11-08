"""Dépendances FastAPI : utilisateur courant et contrôle d'accès par rôle.

Usage dans un futur module ::

    from app.modules.auth.dependencies import require_roles
    from app.modules.users.roles import Role

    @router.get("/alerts", dependencies=[Depends(require_roles(Role.CLINICAL_LEAD))])
    def list_alerts(): ...

    # ou pour récupérer l'utilisateur :
    def handler(user: User = Depends(require_roles(Role.ADMIN, Role.DATA_OFFICER))): ...
"""

from collections.abc import Callable

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.modules.auth.rate_limit import LoginRateLimiter
from app.modules.auth.tokens import InvalidTokenError, decode_access_token
from app.modules.users.models import User
from app.modules.users.roles import Role

_bearer = HTTPBearer(auto_error=False)

NOT_AUTHENTICATED = "Authentification requise."
FORBIDDEN = "Accès refusé."


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=NOT_AUTHENTICATED,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
    settings: Settings = Depends(get_settings),  # noqa: B008
) -> User:
    """Utilisateur authentifié par le jeton d'accès.

    L'utilisateur est relu en base à chaque requête : une désactivation ou un
    changement de rôle prend effet immédiatement, sans attendre l'expiration
    du JWT. Le rôle fait foi depuis la base, pas depuis le jeton.
    """
    if credentials is None:
        raise _unauthorized()
    try:
        claims = decode_access_token(credentials.credentials, settings)
    except InvalidTokenError:
        raise _unauthorized() from None
    user = db.get(User, claims.user_id)
    if user is None or not user.can_authenticate:
        raise _unauthorized()
    return user


def require_roles(*roles: Role) -> Callable[..., User]:
    """Fabrique une dépendance qui exige l'un des rôles donnés (403 sinon)."""
    if not roles:
        raise ValueError("require_roles() exige au moins un rôle.")
    allowed = frozenset(roles)

    def _checker(user: User = Depends(get_current_user)) -> User:  # noqa: B008
        if user.role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=FORBIDDEN)
        return user

    return _checker


def get_login_rate_limiter(
    request: Request,
    settings: Settings = Depends(get_settings),  # noqa: B008
) -> LoginRateLimiter:
    """Limiteur propre à chaque application (stocké dans ``app.state``)."""
    limiter = getattr(request.app.state, "login_rate_limiter", None)
    if limiter is None:
        limiter = LoginRateLimiter(settings.login_max_attempts, settings.login_window_seconds)
        request.app.state.login_rate_limiter = limiter
    return limiter
