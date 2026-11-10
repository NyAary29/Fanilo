"""Espace agent (GET /followup/patients), activité du tableau de bord
(GET /dashboard/activity), tri des alertes et historique de démonstration.
Données fictives."""

from datetime import date, timedelta

import pytest
from sqlalchemy import func, select

from app.modules.audit.models import AuditEvent
from app.modules.devseed import DEMO_NAMES, seed, seed_history
from app.modules.interactions.ai_client import get_ai_client
from tests.helpers import FakeAi, create_beneficiary, import_demo_contents


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


def _patient(client, world, name="Personne fictive", lmp_weeks=10, who="ac_a"):
    bid = create_beneficiary(client, world, who=who)
    resp = client.put(
        f"/beneficiaries/{bid}/identity",
        json={"display_name": name, "village": "Village fictif"},
        headers=world.headers(who),
    )
    assert resp.status_code == 200, resp.text
    lmp = (date.today() - timedelta(weeks=lmp_weeks)).isoformat()
    resp = client.post(
        f"/beneficiaries/{bid}/pregnancies", json={"lmp_date": lmp}, headers=world.headers(who)
    )
    assert resp.status_code == 201, resp.text
    return bid


def test_patients_list_status_next_anc_and_audit(app, client, world, session_factory, db):
    import_demo_contents(session_factory)
    calm = _patient(client, world, "Fictive Calme")
    urgent = _patient(client, world, "Fictive Alerte")
    fake = FakeAi()
    app.dependency_overrides[get_ai_client] = lambda: fake
    resp = client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(urgent), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers("ac_a"),
    )
    assert resp.json()["alert_id"]

    before = db.scalar(
        select(func.count()).select_from(AuditEvent).where(AuditEvent.action == "identity.read")
    )
    resp = client.get("/followup/patients", headers=world.headers("ac_a"))
    assert resp.status_code == 200, resp.text
    items = resp.json()["items"]
    assert [i["display_name"] for i in items] == [
        "Fictive Alerte",
        "Fictive Calme",
    ]  # à suivre d'abord
    first, second = items
    assert first["status"] == "a_suivre" and first["reasons"] == ["alerte_ouverte"]
    assert first["latest_alert_id"] == resp.json()["items"][0]["latest_alert_id"] is not None
    assert second["status"] == "a_jour" and second["beneficiary_id"] == str(calm)
    assert second["pregnancy"]["month"] == 3
    assert second["next_anc"]["days"] >= 0 and second["anc_total"] > 0
    after = db.scalar(
        select(func.count()).select_from(AuditEvent).where(AuditEvent.action == "identity.read")
    )
    assert after - before == 2  # une lecture d'identité tracée par patiente renvoyée

    only = client.get("/followup/patients?q=calme", headers=world.headers("ac_a")).json()["items"]
    assert [i["display_name"] for i in only] == ["Fictive Calme"]
    todo = client.get("/followup/patients?status=a_suivre", headers=world.headers("ac_a")).json()
    assert todo["total"] == 1


def test_patients_scope_and_roles(client, world):
    _patient(client, world, "Fictive A")
    assert client.get("/followup/patients", headers=world.headers("ac_b")).json()["total"] == 0
    for who in ("admin", "data", "tech"):
        assert client.get("/followup/patients", headers=world.headers(who)).status_code == 403
    assert client.get("/followup/patients", headers=world.headers("head_a")).json()["total"] == 1


def test_activity_months_and_sites(app, client, world, session_factory):
    import_demo_contents(session_factory)
    bid = _patient(client, world)
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()
    client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers("ac_a"),
    )
    resp = client.get("/dashboard/activity?months=3", headers=world.headers("head_a"))
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert len(data["months"]) == 3
    current = data["months"][-1]
    assert current["month"] == date.today().strftime("%Y-%m")
    assert current["pregnancies"] == 1 and current["alerts"] == 1 and current["questions"] == 1
    sites = {s["code"]: s for s in data["sites"]}
    assert sites["CSB-A"]["active_pregnancies"] == 1 and sites["CSB-A"]["open_alerts"] == 1
    assert "CSB-B" not in sites  # hors périmètre du chef du CSB A
    glob = client.get("/dashboard/activity", headers=world.headers("admin")).json()
    assert {"CSB-A", "CSB-B"} <= {s["code"] for s in glob["sites"]}
    assert client.get("/dashboard/activity", headers=world.headers("ac_a")).status_code == 403


def test_alerts_recent_sort(app, client, world, session_factory):
    import_demo_contents(session_factory)
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()
    ids = []
    for _ in range(2):
        r = client.post(
            "/interactions/ask",
            json={"module": "reny", "sign_codes": ["SIGN_DEMO_01"]},
            headers=world.headers("ac_a"),
        )
        ids.append(r.json()["alert_id"])
    recent = client.get("/alerts?sort=recent", headers=world.headers("head_a")).json()["items"]
    assert [a["id"] for a in recent] == list(reversed(ids))


def test_history_seed_is_idempotent(db, settings):
    seed(db, settings)
    db.commit()
    assert seed_history(db, settings) == len(DEMO_NAMES)
    db.commit()
    assert seed_history(db, settings) == 0


def test_purge_keeps_accounts_sites_and_contents(client, world, db, settings, session_factory):
    from app.modules.beneficiaries.models import Beneficiary
    from app.modules.contents.models import ContentItem
    from app.modules.devseed import purge
    from app.modules.sites.models import Site
    from app.modules.users.models import User

    import_demo_contents(session_factory)
    _patient(client, world)
    users_before = len(db.scalars(select(User)).all())
    purge(db, settings)
    db.commit()
    assert db.scalars(select(Beneficiary)).all() == []
    assert len(db.scalars(select(User)).all()) == users_before
    assert db.scalars(select(Site)).all() and db.scalars(select(ContentItem)).all()
    actions = [a.action for a in db.scalars(select(AuditEvent))]
    assert actions == ["data.purge"]
