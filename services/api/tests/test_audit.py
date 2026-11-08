"""Journal d'audit (F-12) : accès, contenu, absence de données sensibles."""

from datetime import timedelta

import pytest
from sqlalchemy import select

from app.db.types import utcnow
from app.modules.audit.models import AuditEvent
from app.modules.audit.service import login_fingerprint, record_audit
from tests.conftest import TEST_PASSWORD

FAKE_NAME = "Rasoa Fictive"
FAKE_PHONE = "0349999999"


def _events(db) -> list[AuditEvent]:
    db.expire_all()
    return list(db.scalars(select(AuditEvent).order_by(AuditEvent.at)))


def _all_audit_text(db) -> str:
    return " ".join(
        " ".join(str(getattr(e, c.name)) for c in AuditEvent.__table__.columns) for e in _events(db)
    )


@pytest.mark.parametrize("who", ["admin", "ac_a", "head_a", "lead", "tech"])
def test_audit_reserved_to_data_officer(client, world, who):
    assert client.get("/audit", headers=world.headers(who)).status_code == 403


def test_audit_requires_authentication(client):
    assert client.get("/audit").status_code == 401


def test_successful_login_is_audited(client, world, db):
    resp = client.post("/auth/login", json={"login": "ac.a", "password": TEST_PASSWORD})
    assert resp.status_code == 200
    event = db.scalar(select(AuditEvent).where(AuditEvent.action == "auth.login_succeeded"))
    assert event.actor_user_id == world.users["ac_a"].id
    assert event.actor_role == "community_agent"
    assert event.entity_type == "user"
    assert event.site_id == world.site_a.id
    assert event.request_id == resp.headers["x-request-id"]


def test_failed_login_audited_without_password_nor_login(client, world, db, settings):
    client.post("/auth/login", json={"login": "ac.a", "password": "mauvais-secret-fictif"})
    client.post("/auth/login", json={"login": "inconnu.fictif", "password": "autre-secret"})
    failures = [e for e in _events(db) if e.action == "auth.login_failed"]
    assert len(failures) == 2
    for event in failures:
        assert event.actor_user_id is None and event.actor_role is None
        assert event.entity_type is None and event.entity_id is None
    assert failures[0].login_fingerprint == login_fingerprint("ac.a", settings.secret_key)
    text = _all_audit_text(db)
    for secret in ("mauvais-secret-fictif", "autre-secret", "inconnu.fictif", "ac.a "):
        assert secret not in text


def test_rate_limited_login_is_audited(client, world, db, settings):
    for _ in range(settings.login_max_attempts + 1):
        client.post("/auth/login", json={"login": "ac.a", "password": "mauvais-secret-fictif"})
    assert any(e.action == "auth.login_rate_limited" for e in _events(db))


def test_audit_listing_and_filters(client, world, db):
    with db.begin():
        record_audit(db, world.users["admin"], "site.update", "site", world.site_a.id)
        record_audit(db, world.users["ac_a"], "beneficiary.create", "beneficiary", "x")
    headers = world.headers("data")

    all_events = client.get("/audit", headers=headers).json()
    assert all_events["total"] == 2
    assert set(all_events["items"][0]) == {
        "id",
        "at",
        "actor_user_id",
        "actor_role",
        "action",
        "entity_type",
        "entity_id",
        "request_id",
        "site_id",
    }
    assert "login_fingerprint" not in all_events["items"][0]

    by_type = client.get("/audit?entity_type=site", headers=headers).json()
    assert [e["action"] for e in by_type["items"]] == ["site.update"]

    actor = world.users["ac_a"].id
    by_actor = client.get(f"/audit?actor_user_id={actor}", headers=headers).json()
    assert [e["action"] for e in by_actor["items"]] == ["beneficiary.create"]

    future = (utcnow() + timedelta(hours=1)).isoformat()
    empty = client.get("/audit", params={"from": future}, headers=headers).json()
    assert empty["total"] == 0
    past = (utcnow() - timedelta(hours=1)).isoformat()
    window = client.get("/audit", params={"from": past, "to": future}, headers=headers).json()
    assert window["total"] == 2


def test_audit_rejects_naive_datetimes(client, world):
    resp = client.get(
        "/audit", params={"from": "2026-01-01T00:00:00"}, headers=world.headers("data")
    )
    assert resp.status_code == 422


def test_identity_operations_audited_without_sensitive_data(client, world, db):
    headers = world.headers("ac_a")
    bid = client.post("/beneficiaries", json={}, headers=headers).json()["id"]
    body = {"display_name": FAKE_NAME, "phone": FAKE_PHONE, "village": "Village fictif"}
    assert (
        client.put(f"/beneficiaries/{bid}/identity", json=body, headers=headers).status_code == 200
    )
    assert client.get(f"/beneficiaries/{bid}/identity", headers=headers).status_code == 200
    actions = [e.action for e in _events(db)]
    assert {"beneficiary.create", "identity.write", "identity.read"} <= set(actions)
    text = _all_audit_text(db)
    assert FAKE_NAME not in text and FAKE_PHONE not in text and "Village fictif" not in text
