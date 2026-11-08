"""Tableau de bord (section 9) : agrégats uniquement, périmètre, rôles.
Données fictives."""

import uuid
from datetime import timedelta

import pytest

from app.db.types import utcnow
from app.modules.interactions.ai_client import get_ai_client
from app.modules.reny.models import AncVisit
from app.modules.users.models import User
from tests.helpers import FakeAi, create_beneficiary, import_demo_contents

CONTRACT_KEYS = {
    "open_alerts", "overdue_alerts", "pending_referrals", "upcoming_anc_7d", "missed_anc_30d",
    "active_agents_30d", "total_agents", "active_pregnancies", "interactions_30d",
    "fallback_rate_30d", "generated_at",
}


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


@pytest.fixture(autouse=True)
def _setup(app, session_factory):
    import_demo_contents(session_factory)
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()


def _summary(client, world, who, **params):
    return client.get("/dashboard/summary", params=params, headers=world.headers(who))


def _activity(client, world, db):
    bid = create_beneficiary(client, world)
    lmp = (utcnow() - timedelta(days=12 * 7 + 2)).date().isoformat()
    preg = client.post(
        f"/beneficiaries/{bid}/pregnancies",
        json={"lmp_date": lmp, "dates_confirmed_by": "ac_declared"},
        headers=world.headers("ac_a"),
    )
    assert preg.status_code == 201, preg.text
    visits = client.get(
        f"/pregnancies/{preg.json()['id']}/anc-visits", headers=world.headers("ac_a")
    ).json()["items"]
    # Une visite dans 5 jours, une autre manquée il y a 10 jours.
    soon, missed = (db.get(AncVisit, uuid.UUID(v["id"])) for v in visits[:2])
    soon.scheduled_date = utcnow().date() + timedelta(days=5)
    missed.scheduled_date = utcnow().date() - timedelta(days=10)
    db.commit()
    ask = lambda codes: client.post(  # noqa: E731
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": codes},
        headers=world.headers("ac_a"),
    ).json()
    alert_id = ask(["SIGN_DEMO_01"])["alert_id"]
    ask(["SIGN_INCONNU"])  # fallback
    ask(["SIGN_DEMO_05"])  # réponse
    client.post(
        "/referrals", json={"beneficiary_id": str(bid), "to_site_id": str(world.site_b.id)},
        headers=world.headers("ac_a"),
    )
    agent = db.get(User, world.users["ac_a"].id)
    agent.last_login_at = utcnow()
    db.commit()
    return alert_id


def test_summary_aggregates_without_nominative_data(client, world, db):
    alert_id = _activity(client, world, db)
    _activity_b = create_beneficiary(client, world, who="ac_b")
    resp = _summary(client, world, "head_a")
    assert resp.status_code == 200
    data = resp.json()
    assert set(data) == CONTRACT_KEYS
    assert data["open_alerts"] == 1 and data["overdue_alerts"] == 0
    assert data["pending_referrals"] == 1
    assert data["active_pregnancies"] == 1
    assert data["upcoming_anc_7d"] == 1
    assert data["missed_anc_30d"] == 1
    assert data["interactions_30d"] == 3
    assert data["fallback_rate_30d"] == pytest.approx(1 / 3, abs=1e-4)
    assert (data["active_agents_30d"], data["total_agents"]) == (1, 2)  # ac.a et ac.a1
    # Aucun identifiant ni texte : uniquement des nombres (et l'horodatage).
    for key, value in data.items():
        if key != "generated_at":
            assert isinstance(value, int | float) and not isinstance(value, bool)
    assert alert_id not in resp.text and str(_activity_b) not in resp.text
    # Échéance dépassée.
    from app.modules.alerts.models import Alert

    db.get(Alert, uuid.UUID(alert_id)).due_at = utcnow() - timedelta(minutes=5)
    db.commit()
    assert _summary(client, world, "head_a").json()["overdue_alerts"] == 1


def test_summary_scope_and_roles(client, world, db):
    _activity(client, world, db)
    for who in ("ac_a", "advisor_a", "tech"):
        assert _summary(client, world, who).status_code == 403
    lead = _summary(client, world, "lead").json()
    admin = _summary(client, world, "admin").json()
    data = _summary(client, world, "data").json()
    assert lead["interactions_30d"] == admin["interactions_30d"] == data["interactions_30d"] == 3
    assert lead["total_agents"] == 3  # vue globale
    only_b = _summary(client, world, "lead", site_id=str(world.site_b.id)).json()
    assert only_b["interactions_30d"] == 0 and only_b["total_agents"] == 1
    # La référence vers le site B y est comptée (site destinataire).
    assert only_b["pending_referrals"] == 1
    zone = _summary(client, world, "head_a", site_id=str(world.zone_a1.id)).json()
    assert zone["total_agents"] == 1
    assert _summary(client, world, "head_a", site_id=str(world.site_b.id)).status_code == 404
    assert _summary(client, world, "lead", site_id=str(uuid.uuid4())).status_code == 404
