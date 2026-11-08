"""Endpoints d'authentification."""

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.modules.audit.service import AuditAction, login_fingerprint, record_audit
from app.modules.auth import service
from app.modules.auth.dependencies import get_current_user, get_login_rate_limiter
from app.modules.auth.rate_limit import LoginRateLimiter
from app.modules.auth.schemas import LoginRequest, MeResponse, RefreshRequest, TokenResponse
from app.modules.users.models import User, normalize_login

router = APIRouter(prefix="/auth", tags=["authentification"])

INVALID_CREDENTIALS = "Identifiant ou mot de passe incorrect."
INVALID_REFRESH = "Session expirée ou invalide. Veuillez vous reconnecter."
TOO_MANY_ATTEMPTS = "Trop de tentatives de connexion. Réessayez plus tard."


def _to_response(tokens: service.IssuedTokens) -> TokenResponse:
    return TokenResponse(
        access_token=tokens.access_token,
        expires_in=tokens.expires_in,
        refresh_token=tokens.refresh_token,
        refresh_expires_in=tokens.refresh_expires_in,
    )


@router.post("/login", response_model=TokenResponse, summary="Connexion")
def login(
    body: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),  # noqa: B008
    settings: Settings = Depends(get_settings),  # noqa: B008
    limiter: LoginRateLimiter = Depends(get_login_rate_limiter),  # noqa: B008
) -> TokenResponse:
    """Échange identifiant + mot de passe contre un jeton d'accès et un jeton de
    rafraîchissement. Message d'erreur identique quelle que soit la cause."""
    # NB : derrière un reverse proxy, request.client.host est l'IP du proxy ;
    # configurer uvicorn --proxy-headers / forwarded-allow-ips en conséquence.
    client_ip = request.client.host if request.client else "unknown"
    key = f"{client_ip}|{normalize_login(body.login)}"
    retry_after = limiter.retry_after(key)
    if retry_after:
        _audit_login_failure(db, body.login, settings, AuditAction.LOGIN_RATE_LIMITED)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=TOO_MANY_ATTEMPTS,
            headers={"Retry-After": str(retry_after)},
        )
    try:
        user = service.authenticate(db, body.login, body.password)
    except service.AuthenticationError:
        limiter.record_failure(key)
        _audit_login_failure(db, body.login, settings, AuditAction.LOGIN_FAILED)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=INVALID_CREDENTIALS
        ) from None
    limiter.reset(key)
    # Écrit dans la même transaction que l'émission des jetons.
    record_audit(db, user, AuditAction.LOGIN_SUCCEEDED, "user", user.id, site_id=user.site_id)
    return _to_response(service.issue_tokens(db, user, settings))


def _audit_login_failure(db: Session, login: str, settings: Settings, action: str) -> None:
    """Trace un échec sans le mot de passe ni l'identifiant en clair (empreinte HMAC)."""
    record_audit(
        db,
        None,
        action,
        None,
        None,
        login_fingerprint=login_fingerprint(login, settings.secret_key),
    )
    db.commit()


@router.post("/refresh", response_model=TokenResponse, summary="Rafraîchir la session")
def refresh(
    body: RefreshRequest,
    db: Session = Depends(get_db),  # noqa: B008
    settings: Settings = Depends(get_settings),  # noqa: B008
) -> TokenResponse:
    """Rotation : le jeton présenté est consommé et remplacé. Réutiliser un jeton
    déjà consommé révoque toute la session (détection de vol)."""
    try:
        tokens = service.rotate_refresh_token(db, body.refresh_token, settings)
    except service.AuthenticationError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=INVALID_REFRESH
        ) from None
    return _to_response(tokens)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, summary="Déconnexion")
def logout(
    body: RefreshRequest,
    db: Session = Depends(get_db),  # noqa: B008
) -> Response:
    """Révoque la session associée au jeton de rafraîchissement. Le jeton d'accès
    en cours reste valide jusqu'à son expiration (courte)."""
    service.logout(db, body.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=MeResponse, summary="Utilisateur connecté")
def me(user: User = Depends(get_current_user)) -> User:  # noqa: B008
    return user
