"""Opérations sur les comptes utilisateurs."""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.auth.passwords import hash_password
from app.modules.users.models import LOGIN_MAX_LENGTH, User, normalize_login
from app.modules.users.roles import Role

MIN_PASSWORD_LENGTH = 12


class UserError(ValueError):
    """Erreur de validation lors de la création ou modification d'un compte."""


def get_by_login(session: Session, login: str) -> User | None:
    return session.scalar(select(User).where(User.login == normalize_login(login)))


def validate_password(password: str) -> None:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise UserError(f"Le mot de passe doit contenir au moins {MIN_PASSWORD_LENGTH} caractères.")


def create_user(
    session: Session,
    *,
    login: str,
    password: str,
    role: Role,
    site_id: uuid.UUID | None = None,
) -> User:
    """Crée un compte (sans commit : l'appelant valide la transaction)."""
    normalized = normalize_login(login)
    if not normalized or len(normalized) > LOGIN_MAX_LENGTH:
        raise UserError(f"L'identifiant doit contenir entre 1 et {LOGIN_MAX_LENGTH} caractères.")
    validate_password(password)
    if get_by_login(session, normalized) is not None:
        raise UserError("Cet identifiant est déjà utilisé.")
    user = User(
        login=normalized,
        password_hash=hash_password(password),
        role=role,
        site_id=site_id,
        is_active=True,
    )
    session.add(user)
    session.flush()
    return user
