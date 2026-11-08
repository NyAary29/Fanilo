"""Tests de l'authentification : connexion, jetons, rotation, rôles."""

from datetime import timedelta

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.types import utcnow
from app.modules.auth.dependencies import require_roles
from app.modules.auth.models import RefreshToken
from app.modules.auth.rate_limit import LoginRateLimiter
from app.modules.auth.tokens import create_access_token, hash_refresh_token
from app.modules.users.models import User
from app.modules.users.roles import Role
from tests.conftest import TEST_PASSWORD


def _login(client: TestClient, login: str = "agent.test", password: str = TEST_PASSWORD):
    return client.post("/auth/login", json={"login": login, "password": password})


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# --- Connexion -----------------------------------------------------------------


def test_login_success_returns_tokens(client, make_user, settings):
    make_user()
    resp = _login(client)
    assert resp.status_code == 200
    body = resp.json()
    assert body["token_type"] == "bearer"
    assert body["expires_in"] == settings.access_token_ttl_minutes * 60
    assert body["refresh_token"]

    me = client.get("/auth/me", headers=_bearer(body["access_token"]))
    assert me.status_code == 200
    assert me.json()["login"] == "agent.test"
    assert me.json()["role"] == "community_agent"
    assert "password_hash" not in me.json()


def test_login_is_case_and_space_insensitive(client, make_user):
    make_user(login="0340000000")
    assert _login(client, login=" 034 00 000 00 ").status_code == 200


def test_unknown_user_and_wrong_password_give_identical_errors(client, make_user):
    make_user()
    wrong_pwd = _login(client, password="mauvais-mot-de-passe")
    unknown = _login(client, login="inconnu")
    assert wrong_pwd.status_code == unknown.status_code == 401
    assert wrong_pwd.json() == unknown.json()


def test_refresh_token_stored_hashed(client, make_user, db: Session):
    make_user()
    raw = _login(client).json()["refresh_token"]
    stored = db.scalars(select(RefreshToken)).all()
    assert len(stored) == 1
    assert stored[0].token_hash == hash_refresh_token(raw)
    assert stored[0].token_hash != raw


def test_inactive_user_cannot_login(client, make_user):
    make_user(is_active=False)
    resp = _login(client)
    assert resp.status_code == 401
    assert resp.json() == _login(client, login="inconnu").json()


def test_deactivated_user_loses_access_and_refresh(client, make_user, session_factory):
    user = make_user()
    tokens = _login(client).json()
    with session_factory() as s:
        s.get(User, user.id).is_active = False
        s.commit()
    assert client.get("/auth/me", headers=_bearer(tokens["access_token"])).status_code == 401
    refresh = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refresh.status_code == 401


def test_login_rate_limited_after_repeated_failures(client, make_user, settings):
    make_user()
    for _ in range(settings.login_max_attempts):
        assert _login(client, password="mauvais-mot-de-passe").status_code == 401
    blocked = _login(client)  # même le bon mot de passe est refusé pendant la fenêtre
    assert blocked.status_code == 429
    assert int(blocked.headers["Retry-After"]) > 0


def test_rate_limiter_window_expires_and_resets():
    now = [0.0]
    limiter = LoginRateLimiter(max_attempts=2, window_seconds=10, clock=lambda: now[0])
    limiter.record_failure("k")
    limiter.record_failure("k")
    assert limiter.retry_after("k") > 0
    now[0] = 10.0
    assert limiter.retry_after("k") == 0
    limiter.record_failure("k")
    limiter.reset("k")
    assert limiter.retry_after("k") == 0


# --- Jeton d'accès -------------------------------------------------------------


def test_me_requires_token(client):
    resp = client.get("/auth/me")
    assert resp.status_code == 401
    assert resp.headers["WWW-Authenticate"] == "Bearer"


def test_expired_access_token_rejected(client, make_user, settings):
    user = make_user()
    token, _ = create_access_token(user, settings, now=utcnow() - timedelta(hours=1))
    assert client.get("/auth/me", headers=_bearer(token)).status_code == 401


def test_token_signed_with_other_key_rejected(client, make_user, settings):
    user = make_user()
    other = settings.model_copy(update={"secret_key": "autre-cle-fictive-" + "y" * 32})
    token, _ = create_access_token(user, other)
    assert client.get("/auth/me", headers=_bearer(token)).status_code == 401


def test_refresh_token_not_accepted_as_access_token(client, make_user):
    make_user()
    raw_refresh = _login(client).json()["refresh_token"]
    assert client.get("/auth/me", headers=_bearer(raw_refresh)).status_code == 401


# --- Rafraîchissement et rotation ---------------------------------------------


def test_refresh_rotates_token(client, make_user):
    make_user()
    first = _login(client).json()
    resp = client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert resp.status_code == 200
    second = resp.json()
    assert second["refresh_token"] != first["refresh_token"]
    assert client.get("/auth/me", headers=_bearer(second["access_token"])).status_code == 200

    third = client.post("/auth/refresh", json={"refresh_token": second["refresh_token"]})
    assert third.status_code == 200


def test_refresh_token_reuse_revokes_whole_family(client, make_user, db: Session):
    make_user()
    first = _login(client).json()
    second = client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()

    # Un attaquant rejoue l'ancien jeton déjà consommé.
    replay = client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert replay.status_code == 401

    # Le jeton légitime le plus récent est désormais révoqué lui aussi.
    legit = client.post("/auth/refresh", json={"refresh_token": second["refresh_token"]})
    assert legit.status_code == 401
    assert all(t.revoked_at is not None for t in db.scalars(select(RefreshToken)))


def test_reuse_does_not_affect_other_sessions(client, make_user):
    make_user()
    phone = _login(client).json()
    tablet = _login(client).json()
    client.post("/auth/refresh", json={"refresh_token": phone["refresh_token"]})
    client.post("/auth/refresh", json={"refresh_token": phone["refresh_token"]})  # rejeu
    resp = client.post("/auth/refresh", json={"refresh_token": tablet["refresh_token"]})
    assert resp.status_code == 200


def test_expired_refresh_token_rejected(client, make_user, session_factory):
    make_user()
    raw = _login(client).json()["refresh_token"]
    with session_factory() as s:
        record = s.scalar(select(RefreshToken))
        record.expires_at = utcnow() - timedelta(seconds=1)
        s.commit()
    assert client.post("/auth/refresh", json={"refresh_token": raw}).status_code == 401


def test_unknown_refresh_token_rejected(client):
    resp = client.post("/auth/refresh", json={"refresh_token": "jeton-inexistant"})
    assert resp.status_code == 401


# --- Déconnexion ---------------------------------------------------------------


def test_logout_revokes_refresh_token(client, make_user):
    make_user()
    tokens = _login(client).json()
    resp = client.post("/auth/logout", json={"refresh_token": tokens["refresh_token"]})
    assert resp.status_code == 204
    refresh = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refresh.status_code == 401


def test_logout_is_idempotent(client):
    resp = client.post("/auth/logout", json={"refresh_token": "jeton-inexistant"})
    assert resp.status_code == 204


# --- Contrôle d'accès par rôle -------------------------------------------------


def _add_protected_route(app: FastAPI) -> None:
    @app.get("/test/clinique")
    def _clinical(user: User = Depends(require_roles(Role.CLINICAL_LEAD, Role.ADMIN))):  # noqa: B008
        return {"role": user.role}


def test_require_roles_allows_listed_role(app, client, make_user):
    _add_protected_route(app)
    make_user(login="resp.clinique", role=Role.CLINICAL_LEAD)
    token = _login(client, login="resp.clinique").json()["access_token"]
    resp = client.get("/test/clinique", headers=_bearer(token))
    assert resp.status_code == 200
    assert resp.json() == {"role": "clinical_lead"}


def test_require_roles_forbids_other_roles(app, client, make_user):
    _add_protected_route(app)
    make_user(login="tech.fictif", role=Role.TECHNICAL)
    token = _login(client, login="tech.fictif").json()["access_token"]
    resp = client.get("/test/clinique", headers=_bearer(token))
    assert resp.status_code == 403
    assert resp.json()["detail"] == "Accès refusé."


def test_require_roles_uses_current_role_from_database(app, client, make_user, session_factory):
    _add_protected_route(app)
    user = make_user(login="ex.admin", role=Role.ADMIN)
    token = _login(client, login="ex.admin").json()["access_token"]
    with session_factory() as s:
        s.get(User, user.id).role = Role.COMMUNITY_AGENT
        s.commit()
    assert client.get("/test/clinique", headers=_bearer(token)).status_code == 403


def test_require_roles_without_token_is_401(app, client):
    _add_protected_route(app)
    assert client.get("/test/clinique").status_code == 401
