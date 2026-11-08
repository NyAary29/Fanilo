"""Émission et vérification des jetons.

- Jeton d'accès : JWT HS256 signé avec ``settings.secret_key``, courte durée.
- Jeton de rafraîchissement : chaîne aléatoire opaque (256 bits). Son entropie
  rend un SHA-256 simple suffisant pour le stockage (pas besoin d'argon2).
"""

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

import jwt

from app.core.config import Settings
from app.db.types import utcnow
from app.modules.users.models import User

JWT_ALGORITHM = "HS256"
JWT_ISSUER = "fanilo-api"
ACCESS_TOKEN_TYPE = "access"  # noqa: S105 (type de jeton, pas un secret)


class InvalidTokenError(Exception):
    """Jeton absent, mal formé, expiré ou de mauvais type."""


@dataclass(frozen=True)
class AccessTokenClaims:
    user_id: uuid.UUID
    role: str
    expires_at: datetime


def create_access_token(
    user: User, settings: Settings, *, now: datetime | None = None
) -> tuple[str, int]:
    """Retourne le JWT et sa durée de validité en secondes."""
    issued_at = now or utcnow()
    ttl = timedelta(minutes=settings.access_token_ttl_minutes)
    payload = {
        "sub": str(user.id),
        "role": user.role.value,
        "type": ACCESS_TOKEN_TYPE,
        "iss": JWT_ISSUER,
        "iat": issued_at,
        "exp": issued_at + ttl,
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=JWT_ALGORITHM)
    return token, int(ttl.total_seconds())


def decode_access_token(token: str, settings: Settings) -> AccessTokenClaims:
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[JWT_ALGORITHM],
            issuer=JWT_ISSUER,
            options={"require": ["sub", "exp", "iat", "iss", "type"]},
        )
        if payload.get("type") != ACCESS_TOKEN_TYPE:
            raise InvalidTokenError
        return AccessTokenClaims(
            user_id=uuid.UUID(payload["sub"]),
            role=str(payload.get("role", "")),
            expires_at=datetime.fromtimestamp(payload["exp"], tz=utcnow().tzinfo),
        )
    except (jwt.PyJWTError, ValueError, KeyError) as exc:
        raise InvalidTokenError from exc


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
