"""Tests du service utilisateurs et de la commande de création d'administrateur."""

import io

import pytest
from sqlalchemy.orm import Session

from app.modules.auth.passwords import verify_password
from app.modules.users import cli
from app.modules.users.roles import NOMINATIVE_DATA_ROLES, Role
from app.modules.users.service import UserError, create_user, get_by_login


def test_create_user_hashes_password_with_argon2(db: Session):
    user = create_user(db, login="Agent.Fictif", password="mot-de-passe-long", role=Role.CSB_HEAD)
    assert user.login == "agent.fictif"
    assert user.password_hash.startswith("$argon2id$")
    assert verify_password("mot-de-passe-long", user.password_hash)
    assert not verify_password("autre-mot-de-passe", user.password_hash)


def test_create_user_rejects_short_password(db: Session):
    with pytest.raises(UserError):
        create_user(db, login="ac", password="court", role=Role.COMMUNITY_AGENT)


def test_create_user_rejects_duplicate_login(db: Session):
    create_user(db, login="ac.un", password="mot-de-passe-long", role=Role.COMMUNITY_AGENT)
    with pytest.raises(UserError):
        create_user(db, login="AC.UN", password="mot-de-passe-long", role=Role.COMMUNITY_AGENT)


def test_technical_role_has_no_nominative_access():
    assert Role.TECHNICAL not in NOMINATIVE_DATA_ROLES
    assert len(Role) == 7


def test_cli_create_admin(monkeypatch, settings, engine, session_factory):
    monkeypatch.setattr(cli, "get_settings", lambda: settings)
    monkeypatch.setattr(cli, "get_session_factory", lambda _s: session_factory)
    monkeypatch.setattr("sys.stdin", io.StringIO("mot-de-passe-admin-fictif\n"))
    assert cli.main(["create-admin", "--login", "admin.fictif", "--password-stdin"]) == 0
    with session_factory() as s:
        admin = get_by_login(s, "admin.fictif")
        assert admin is not None and admin.role is Role.ADMIN

    # Un second appel avec le même identifiant échoue proprement.
    monkeypatch.setattr("sys.stdin", io.StringIO("mot-de-passe-admin-fictif\n"))
    assert cli.main(["create-admin", "--login", "admin.fictif", "--password-stdin"]) == 1


def test_cli_rejects_weak_password(monkeypatch, settings, session_factory):
    monkeypatch.setattr(cli, "get_settings", lambda: settings)
    monkeypatch.setattr(cli, "get_session_factory", lambda _s: session_factory)
    monkeypatch.setattr("sys.stdin", io.StringIO("court\n"))
    assert cli.main(["create-admin", "--login", "admin.fictif", "--password-stdin"]) == 1
