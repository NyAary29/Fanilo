"""Logique d'authentification : connexion, rotation et révocation des jetons."""

import logging
import uuid
from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.db.types import utcnow
from app.modules.auth.models import RefreshToken
from app.modules.auth.passwords import verify_password
from app.modules.auth.tokens import (
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from app.modules.users.models import User
from app.modules.users.service import get_by_login

logger = logging.getLogger("fanilo.auth")


class AuthenticationError(Exception):
    """Échec d'authentification ; le message exposé est volontairement générique."""


@dataclass(frozen=True)
class IssuedTokens:
    access_token: str
    expires_in: int
    refresh_token: str
    refresh_expires_in: int


def authenticate(session: Session, login: str, password: str) -> User:
    """Vérifie les identifiants. Même erreur pour un compte inconnu, inactif ou un
    mauvais mot de passe, et vérification argon2 systématique (temps constant)."""
    user = get_by_login(session, login)
    password_ok = verify_password(password, user.password_hash if user else None)
    if user is None or not password_ok or not user.can_authenticate:
        raise AuthenticationError
    return user


def _new_refresh_token(
    session: Session, user: User, family_id: uuid.UUID, settings: Settings
) -> tuple[RefreshToken, str, int]:
    raw = generate_refresh_token()
    ttl = timedelta(days=settings.refresh_token_ttl_days)
    record = RefreshToken(
        user_id=user.id,
        family_id=family_id,
        token_hash=hash_refresh_token(raw),
        expires_at=utcnow() + ttl,
    )
    session.add(record)
    session.flush()
    return record, raw, int(ttl.total_seconds())


def issue_tokens(session: Session, user: User, settings: Settings) -> IssuedTokens:
    """Ouvre une nouvelle famille de jetons (nouvelle connexion) et valide."""
    _, raw_refresh, refresh_ttl = _new_refresh_token(session, user, uuid.uuid4(), settings)
    user.last_login_at = utcnow()
    session.commit()
    access, access_ttl = create_access_token(user, settings)
    return IssuedTokens(access, access_ttl, raw_refresh, refresh_ttl)


def revoke_family(session: Session, family_id: uuid.UUID) -> None:
    session.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )


def rotate_refresh_token(session: Session, raw_token: str, settings: Settings) -> IssuedTokens:
    """Consomme un jeton de rafraîchissement et en émet un nouveau.

    Réutilisation d'un jeton déjà consommé ou révoqué : toute la famille est
    révoquée (le jeton a probablement été volé) et la requête est refusée.
    """
    record = session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw_token))
    )
    if record is None:
        raise AuthenticationError

    if record.used_at is not None or record.revoked_at is not None:
        revoke_family(session, record.family_id)
        session.commit()
        logger.warning(
            "refresh_token_reuse_detected",
            extra={"user_id": str(record.user_id), "family_id": str(record.family_id)},
        )
        raise AuthenticationError

    now = utcnow()
    if record.expires_at <= now:
        raise AuthenticationError

    user = session.get(User, record.user_id)
    if user is None or not user.can_authenticate:
        revoke_family(session, record.family_id)
        session.commit()
        raise AuthenticationError

    # Consommation atomique : protège contre deux rafraîchissements concurrents
    # du même jeton (un seul UPDATE peut réussir).
    consumed = session.execute(
        update(RefreshToken)
        .where(
            RefreshToken.id == record.id,
            RefreshToken.used_at.is_(None),
            RefreshToken.revoked_at.is_(None),
        )
        .values(used_at=now)
        .execution_options(synchronize_session=False)
    )
    if consumed.rowcount != 1:
        session.rollback()
        revoke_family(session, record.family_id)
        session.commit()
        raise AuthenticationError

    new_record, raw_refresh, refresh_ttl = _new_refresh_token(
        session, user, record.family_id, settings
    )
    session.execute(
        update(RefreshToken)
        .where(RefreshToken.id == record.id)
        .values(replaced_by_id=new_record.id)
        .execution_options(synchronize_session=False)
    )
    session.commit()
    access, access_ttl = create_access_token(user, settings)
    return IssuedTokens(access, access_ttl, raw_refresh, refresh_ttl)


def logout(session: Session, raw_token: str) -> None:
    """Révoque la famille du jeton présenté (déconnexion de cette session/appareil).
    Idempotent : un jeton inconnu est ignoré."""
    record = session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw_token))
    )
    if record is not None:
        revoke_family(session, record.family_id)
        session.commit()
