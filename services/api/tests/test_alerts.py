"""Alertes (section 7) : destinataire et suppléant, absence de destinataire,
acquittement, résolution, notes, escalade planifiée, périmètre. Données fictives."""

import logging
import uuid
from datetime import timedelta

import pytest
from sqlalchemy import select

from app.db.types import utcnow
from app.modules.alerts import cli as alerts_cli
from app.modules.alerts.models import Alert, AlertEvent
from app.modules.alerts.service import escalate_overdue
from app.modules.interactions.ai_client import get_ai_client
from app.modules.sites.models import SiteKind
from app.modules.users.roles import Role
from tests.helpers import FakeAi, create_beneficiary, import_demo_contents


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


@pytest.fixture(autouse=True)
def _setup(app, session_factory):
    import_demo_contents(session_factory)
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()


def _critical_alert(client, world, who="ac_a", site=None) -> str:
    bid = create_beneficiary(client, world, who=who, site=site)
    resp = client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers(who),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["alert_id"]


def _post(client, world, who, path, json=None):
    return client.post(path, json=json, headers=world.headers(who))


def test_no_recipient_alert_is_escalated_and_logged(client, world, db, caplog):
    # Site B : aucun csb_head ni clinical_advisor.
    with caplog.at_level(logging.ERROR, logger="fanilo.alerts"):
        alert_id = _critical_alert(client, world, who="ac_b")
    alert = db.get(Alert, uuid.UUID(alert_id))
    assert alert.status == "escalated"
    assert alert.recipient_user_id is None and alert.backup_user_id is None
    assert alert.escalated_at is not None
    events = db.scalars(
        select(AlertEvent.type).where(AlertEvent.alert_id == alert.id).order_by(AlertEvent.at)
    ).all()
    assert list(events) == ["created", "escalated"]
    assert any(r.message == "alert_without_recipient" for r in caplog.records)
    # Toujours visible dans le périmètre.
    listed = client.get("/alerts?status=escalated", headers=world.headers("ac_b")).json()
    assert [a["id"] for a in listed["items"]] == [alert_id]


def test_zone_beneficiary_goes_to_parent_csb_head(client, world, db):
    alert_id = _critical_alert(client, world, who="ac_a1")
    alert = db.get(Alert, uuid.UUID(alert_id))
    assert alert.site_id == world.zone_a1.id
    assert alert.recipient_user_id == world.users["head_a"].id


def test_advisor_when_no_csb_head(client, world, db, make_site, make_user):
    site_c = make_site("CSB-C")
    world.users["ac_c"] = make_user("ac.c", Role.COMMUNITY_AGENT, site_id=site_c.id)
    advisor = make_user("conseil.c", Role.CLINICAL_ADVISOR, site_id=site_c.id)
    make_user("chef.c.inactif", Role.CSB_HEAD, site_id=site_c.id, is_active=False)
    alert = db.get(Alert, uuid.UUID(_critical_alert(client, world, who="ac_c")))
    assert alert.status == "open"
    assert alert.recipient_user_id == advisor.id and alert.backup_user_id is None


def test_acknowledge_permissions_and_flow(client, world, make_user, db):
    world.users["head_b"] = make_user("chef.b", Role.CSB_HEAD, site_id=world.site_b.id)
    alert_id = _critical_alert(client, world)
    path = f"/alerts/{alert_id}/acknowledge"
    # Agent communautaire du site : lit, mais n'acquitte pas.
    assert client.get(f"/alerts/{alert_id}", headers=world.headers("ac_a")).status_code == 200
    assert _post(client, world, "ac_a", path).status_code == 403
    # Autre site : introuvable (on ne révèle pas l'existence).
    assert _post(client, world, "head_b", path).status_code == 404
    assert client.get(f"/alerts/{alert_id}", headers=world.headers("ac_b")).status_code == 404
    # Rôles sans accès aux alertes.
    for who in ("admin", "data", "tech"):
        assert client.get(f"/alerts/{alert_id}", headers=world.headers(who)).status_code == 403
    # Résolution avant acquittement : refusée.
    assert _post(client, world, "head_a", f"/alerts/{alert_id}/resolve",
                 {"note": "x"}).status_code == 409
    # Le suppléant (conseiller du site) peut acquitter.
    acked = _post(client, world, "advisor_a", path)
    assert acked.status_code == 200
    body = acked.json()
    assert body["status"] == "acknowledged"
    assert body["acknowledged_by_user_id"] == str(world.users["advisor_a"].id)
    assert [e["type"] for e in body["events"]] == ["created", "acknowledged"]
    assert _post(client, world, "head_a", path).status_code == 409
    assert db.get(Alert, uuid.UUID(alert_id)).version == 2


def test_resolve_and_notes(client, world, db):
    alert_id = _critical_alert(client, world)
    note = _post(client, world, "ac_a", f"/alerts/{alert_id}/notes", {"note": "Note fictive."})
    assert note.status_code == 200
    assert note.json()["events"][-1] | {"id": None, "at": None} == {
        "id": None, "at": None, "alert_id": alert_id,
        "actor_user_id": str(world.users["ac_a"].id), "type": "note", "note": "Note fictive.",
    }
    empty = _post(client, world, "ac_a", f"/alerts/{alert_id}/notes", {"note": ""})
    assert empty.status_code == 422
    _post(client, world, "head_a", f"/alerts/{alert_id}/acknowledge")
    assert _post(client, world, "ac_a", f"/alerts/{alert_id}/resolve",
                 {"note": "x"}).status_code == 403
    assert _post(client, world, "head_a", f"/alerts/{alert_id}/resolve", {}).status_code == 422
    resolved = _post(client, world, "head_a", f"/alerts/{alert_id}/resolve",
                     {"note": "Orientation fictive confirmée."})
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    assert resolved.json()["resolved_at"] is not None
    types = [e["type"] for e in resolved.json()["events"]]
    assert types == ["created", "note", "acknowledged", "resolved"]


def test_list_scope_and_status_filter(client, world, make_user):
    world.users["head_b"] = make_user("chef.b", Role.CSB_HEAD, site_id=world.site_b.id)
    a = _critical_alert(client, world)
    b = _critical_alert(client, world, who="ac_b")
    ids = lambda who, q="": {  # noqa: E731
        i["id"] for i in client.get(f"/alerts{q}", headers=world.headers(who)).json()["items"]
    }
    assert ids("head_a") == {a} and ids("head_b") == {b}
    assert ids("lead") == {a, b}
    assert ids("head_a", "?status=open") == {a}
    assert ids("head_a", "?status=resolved") == set()
    assert client.get("/alerts", headers=world.headers("admin")).status_code == 403


def test_escalation_reassigns_to_backup(client, world, session_factory, db):
    alert_id = uuid.UUID(_critical_alert(client, world))
    alert = db.get(Alert, alert_id)
    alert.due_at = utcnow() - timedelta(minutes=1)
    db.commit()
    with session_factory() as session:
        report = escalate_overdue(session)
    assert (report.escalated, report.reassigned) == (1, 1)
    db.expire_all()
    alert = db.get(Alert, alert_id)
    assert alert.status == "escalated" and alert.escalated_at is not None
    assert alert.recipient_user_id == world.users["advisor_a"].id
    assert alert.backup_user_id == world.users["head_a"].id
    assert alert.version == 3  # due_at modifié par le test, puis escalade
    events = db.scalars(
        select(AlertEvent).where(AlertEvent.alert_id == alert_id).order_by(AlertEvent.at)
    ).all()
    assert [e.type for e in events] == ["created", "escalated"]
    assert events[-1].actor_user_id is None
    # L'ancien destinataire (désormais suppléant) peut encore acquitter.
    assert _post(client, world, "head_a", f"/alerts/{alert_id}/acknowledge").status_code == 200
    # Plus rien à escalader.
    with session_factory() as session:
        assert escalate_overdue(session).escalated == 0


def test_escalation_ignores_not_due_and_acknowledged(client, world, session_factory, db):
    _critical_alert(client, world)  # échéance future
    acked = uuid.UUID(_critical_alert(client, world))
    _post(client, world, "head_a", f"/alerts/{acked}/acknowledge")
    db.get(Alert, acked).due_at = utcnow() - timedelta(hours=1)
    db.commit()
    with session_factory() as session:
        assert escalate_overdue(session).escalated == 0


def test_escalate_cli_assigns_orphan_when_user_appears(
    client, world, session_factory, monkeypatch, make_user, capsys, db
):
    orphan = uuid.UUID(_critical_alert(client, world, who="ac_b"))
    monkeypatch.setattr(alerts_cli, "get_session_factory", lambda _settings: session_factory)
    assert alerts_cli.main(["escalate"]) == 1  # toujours sans destinataire
    assert "toujours sans destinataire : 1" in capsys.readouterr().out
    head_b = make_user("chef.b", Role.CSB_HEAD, site_id=world.site_b.id)
    assert alerts_cli.main(["escalate"]) == 0
    db.expire_all()
    assert db.get(Alert, orphan).recipient_user_id == head_b.id


def test_reference_facility_site_without_parent(client, world, make_site, make_user, db):
    hospital = make_site("CHRD-FICTIF", kind=SiteKind.REFERENCE_FACILITY)
    world.users["ac_h"] = make_user("ac.h", Role.COMMUNITY_AGENT, site_id=hospital.id)
    alert = db.get(Alert, uuid.UUID(_critical_alert(client, world, who="ac_h")))
    assert alert.status == "escalated"  # aucun destinataire : jamais perdue
