"""Références (section 7) : machine à états stricte, motif, création depuis une
alerte, rôles, périmètre ; mêmes règles en synchronisation. Données fictives."""

import uuid

import pytest
from sqlalchemy import select

from app.modules.audit.models import AuditEvent
from app.modules.interactions.ai_client import get_ai_client
from app.modules.sites.models import SiteKind
from app.modules.users.roles import Role
from tests.helpers import FakeAi, create_beneficiary

ALLOWED = {
    "proposed": {"accepted", "not_completed"},
    "accepted": {"arrived", "transferred", "not_completed"},
    "transferred": {"arrived", "not_completed"},
    "arrived": set(),
    "not_completed": set(),
}
STATUSES = sorted(ALLOWED)
# Chemin pour amener une référence à chaque statut depuis "proposed".
PATHS = {
    "proposed": [],
    "accepted": ["accepted"],
    "transferred": ["accepted", "transferred"],
    "arrived": ["accepted", "arrived"],
    "not_completed": ["not_completed"],
}


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


@pytest.fixture
def hospital(make_site, make_user, world):
    site = make_site("CHRD-FICTIF", kind=SiteKind.REFERENCE_FACILITY)
    world.users["head_h"] = make_user("chef.chrd", Role.CSB_HEAD, site_id=site.id)
    return site


def _create(client, world, bid, to_site, who="ac_a", **extra):
    body = {"beneficiary_id": str(bid), "to_site_id": str(to_site.id)} | extra
    return client.post("/referrals", json=body, headers=world.headers(who))


def _transition(client, world, rid, to_status, who="ac_a", **extra):
    return client.post(
        f"/referrals/{rid}/transition",
        json={"to_status": to_status} | extra,
        headers=world.headers(who),
    )


def _referral_at(client, world, bid, hospital, status) -> str:
    rid = _create(client, world, bid, hospital).json()["id"]
    for step in PATHS[status]:
        extra = {"reason": "Motif fictif"} if step == "not_completed" else {}
        assert _transition(client, world, rid, step, **extra).status_code == 200
    return rid


@pytest.mark.parametrize("source", STATUSES)
@pytest.mark.parametrize("target", STATUSES)
def test_every_transition(client, world, hospital, source, target):
    bid = create_beneficiary(client, world)
    rid = _referral_at(client, world, bid, hospital, source)
    resp = _transition(client, world, rid, target, reason="Motif fictif")
    if target in ALLOWED[source]:
        assert resp.status_code == 200, resp.text
        assert resp.json()["status"] == target
    else:
        assert resp.status_code == 409
        detail = client.get(f"/referrals/{rid}", headers=world.headers("ac_a")).json()
        assert detail["status"] == source


def test_not_completed_requires_reason(client, world, hospital, db):
    bid = create_beneficiary(client, world)
    rid = _create(client, world, bid, hospital).json()["id"]
    assert _transition(client, world, rid, "not_completed").status_code == 422
    assert _transition(client, world, rid, "not_completed", reason="   ").status_code == 422
    done = _transition(client, world, rid, "not_completed", reason="Transport indisponible",
                       outcome_note="Note fictive")
    assert done.status_code == 200
    assert done.json()["reason"] == "Transport indisponible"
    assert done.json()["outcome_note"] == "Note fictive"
    actions = set(db.scalars(select(AuditEvent.action).where(AuditEvent.entity_id == rid)))
    assert {"referral.create", "referral.transition"} <= actions


def test_create_defaults_roles_and_validation(client, world, hospital):
    bid = create_beneficiary(client, world)
    created = _create(client, world, bid, hospital, reason="Orientation fictive")
    assert created.status_code == 201
    body = created.json()
    assert body["status"] == "proposed" and body["version"] == 1
    assert body["from_site_id"] == str(world.site_a.id)
    # clinical_lead : lecture seule.
    assert _create(client, world, bid, hospital, who="lead").status_code == 403
    assert _transition(client, world, body["id"], "accepted", who="lead").status_code == 403
    assert client.get(f"/referrals/{body['id']}", headers=world.headers("lead")).status_code == 200
    for who in ("admin", "data", "tech"):
        assert client.get("/referrals", headers=world.headers(who)).status_code == 403
    # Statut initial imposé, site destinataire existant, bénéficiaire visible.
    assert _create(client, world, bid, hospital, status="accepted").status_code == 409
    resp = client.post(
        "/referrals", json={"beneficiary_id": str(bid), "to_site_id": str(uuid.uuid4())},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 422
    assert _create(client, world, bid, hospital, who="ac_b").status_code == 404


def test_scope_includes_destination_site(client, world, hospital):
    bid = create_beneficiary(client, world)
    rid = _create(client, world, bid, hospital).json()["id"]
    assert client.get(f"/referrals/{rid}", headers=world.headers("ac_b")).status_code == 404
    listed = client.get("/referrals", headers=world.headers("ac_b")).json()
    assert listed["total"] == 0
    # La structure destinataire voit la référence et peut l'accepter.
    assert client.get(f"/referrals/{rid}", headers=world.headers("head_h")).status_code == 200
    assert _transition(client, world, rid, "accepted", who="head_h").status_code == 200
    by_status = client.get("/referrals?status=accepted", headers=world.headers("ac_a")).json()
    assert [r["id"] for r in by_status["items"]] == [rid]


def test_create_from_alert(client, world, hospital, app):
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()
    bid = create_beneficiary(client, world)
    ask = client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers("ac_a"),
    ).json()
    alert_id = ask["alert_id"]
    created = _create(client, world, bid, hospital, alert_id=alert_id)
    assert created.status_code == 201 and created.json()["alert_id"] == alert_id
    other = create_beneficiary(client, world)
    assert _create(client, world, other, hospital, alert_id=alert_id).status_code == 422
    assert _create(client, world, bid, hospital, alert_id=str(uuid.uuid4())).status_code == 422


# --- Synchronisation : mêmes règles qu'en REST ------------------------------------


def _change(entity, entity_id, op="upsert", base_version=None, data=None):
    return {
        "change_id": str(uuid.uuid4()), "entity": entity, "op": op, "id": str(entity_id),
        "base_version": base_version, "data": data,
    }


def _push(client, world, who, *changes):
    resp = client.post(
        "/sync/push", json={"device_id": "tablette-fictive", "changes": list(changes)},
        headers=world.headers(who),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["results"]


def test_referral_sync_create_transition_and_rules(client, world, hospital):
    bid = create_beneficiary(client, world)
    rid = uuid.uuid4()
    data = {"beneficiary_id": str(bid), "to_site_id": str(hospital.id), "status": "proposed"}
    (created,) = _push(client, world, "ac_a", _change("referral", rid, data=data))
    assert created["status"] == "applied" and created["server_version"] == 1
    full = created["server_data"]
    # Transition interdite : rejetée pour ce changement seulement.
    bad, ok = _push(
        client, world, "ac_a",
        _change("referral", rid, base_version=1, data=full | {"status": "arrived"}),
        _change("referral", uuid.uuid4(), data=data),
    )
    assert bad["status"] == "rejected" and bad["error"]["code"] == "invalid_transition"
    assert ok["status"] == "applied"
    # not_completed sans motif : rejeté (validation_error).
    (no_reason,) = _push(
        client, world, "ac_a",
        _change("referral", rid, base_version=1, data=full | {"status": "not_completed"}),
    )
    assert no_reason["status"] == "rejected"
    assert no_reason["error"]["code"] == "validation_error"
    (accepted,) = _push(
        client, world, "ac_a",
        _change("referral", rid, base_version=1, data=full | {"status": "accepted"}),
    )
    assert accepted["status"] == "applied"
    assert accepted["server_data"]["status"] == "accepted" and accepted["server_version"] == 2
    # Version périmée : conflit, état serveur renvoyé.
    (conflict,) = _push(
        client, world, "ac_a",
        _change("referral", rid, base_version=1, data=full | {"status": "accepted"}),
    )
    assert conflict["status"] == "conflict" and conflict["server_version"] == 2
    # Champ immuable.
    (immutable,) = _push(
        client, world, "ac_a",
        _change("referral", rid, base_version=2,
                data=accepted["server_data"] | {"to_site_id": str(world.site_b.id)}),
    )
    assert immutable["status"] == "rejected"
    # Création à un autre statut que proposed.
    (wrong,) = _push(client, world, "ac_a",
                     _change("referral", uuid.uuid4(), data=data | {"status": "accepted"}))
    assert wrong["status"] == "rejected" and wrong["error"]["code"] == "invalid_transition"


def test_referral_sync_roles_scope_and_delete(client, world, hospital):
    bid = create_beneficiary(client, world)
    data = {"beneficiary_id": str(bid), "to_site_id": str(hospital.id)}
    (lead,) = _push(client, world, "lead", _change("referral", uuid.uuid4(), data=data))
    assert lead["status"] == "rejected" and lead["error"]["code"] == "forbidden"
    (other_site,) = _push(client, world, "ac_b", _change("referral", uuid.uuid4(), data=data))
    assert other_site["status"] == "rejected" and other_site["error"]["code"] == "not_found"
    rid = uuid.uuid4()
    _push(client, world, "ac_a", _change("referral", rid, data=data))
    (deleted,) = _push(client, world, "ac_a", _change("referral", rid, "delete", 1))
    assert deleted["status"] == "applied" and deleted["server_data"] is None
    pulled = client.get("/sync/pull", headers=world.headers("ac_a")).json()["changes"]
    entry = next(c for c in pulled if c["id"] == str(rid))
    assert entry["deleted_at"] is not None and entry["data"] is None
    # Suppression interdite après le statut proposed.
    rid2 = uuid.uuid4()
    (created,) = _push(client, world, "ac_a", _change("referral", rid2, data=data))
    _push(client, world, "ac_a", _change("referral", rid2, base_version=1,
                                         data=created["server_data"] | {"status": "accepted"}))
    (refused,) = _push(client, world, "ac_a", _change("referral", rid2, "delete", 2))
    assert refused["status"] == "rejected" and refused["error"]["code"] == "invalid_transition"
