"""Synchronisation hors ligne (section 8) : idempotence, conflits, curseur,
périmètre, rôles, suppression logique. Données fictives."""

import uuid
from datetime import timedelta

import pytest
from sqlalchemy import func, select, text

from app.db.types import utcnow
from app.modules.audit.models import AuditEvent
from app.modules.beneficiaries.models import Beneficiary
from app.modules.reny.models import Reminder, ReminderStatus
from app.modules.sync.models import SyncChange

FAKE_NAME = "Hanitra Fictive"


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


def _change(entity, entity_id=None, op="upsert", base_version=None, **data):
    return {
        "change_id": str(uuid.uuid4()),
        "entity": entity,
        "op": op,
        "id": str(entity_id or uuid.uuid4()),
        "base_version": base_version,
        "data": data,
    }


def _push(client, world, who, *changes):
    resp = client.post(
        "/sync/push",
        json={"device_id": "tablette-fictive-01", "changes": list(changes)},
        headers=world.headers(who),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["results"]


def _pull(client, world, who, since=None, limit=500):
    params = {"limit": limit} | ({"since": since} if since else {})
    resp = client.get("/sync/pull", params=params, headers=world.headers(who))
    assert resp.status_code == 200, resp.text
    return resp.json()


def _new_beneficiary(client, world, who="ac_a"):
    bid = uuid.uuid4()
    (result,) = _push(client, world, who, _change("beneficiary", bid, preferred_channel="sms"))
    assert result["status"] == "applied", result
    return bid


# --- Push : création, idempotence, conflit ------------------------------------


def test_push_creates_beneficiary(client, world):
    bid = uuid.uuid4()
    (result,) = _push(client, world, "ac_a", _change("beneficiary", bid, birth_year=2003))
    assert result["status"] == "applied"
    assert result["server_version"] == 1
    assert result["server_data"]["id"] == str(bid)
    assert result["server_data"]["code"].startswith("FAN-")
    assert result["server_data"]["site_id"] == str(world.site_a.id)


def test_push_is_idempotent_by_change_id(client, world, db):
    change = _change("beneficiary", birth_year=2001)
    first = _push(client, world, "ac_a", change)
    second = _push(client, world, "ac_a", change)
    assert first == second
    assert db.scalar(select(func.count()).select_from(Beneficiary)) == 1
    creates = db.scalar(
        select(func.count())
        .select_from(AuditEvent)
        .where(AuditEvent.action == "beneficiary.create")
    )
    assert creates == 1
    assert db.get(SyncChange, uuid.UUID(change["change_id"])).status == "applied"


def test_change_id_reused_by_other_user_is_rejected(client, world):
    change = _change("beneficiary")
    _push(client, world, "ac_a", change)
    (result,) = _push(client, world, "head_a", change)
    assert result["status"] == "rejected"


def test_conflict_on_stale_base_version(client, world, db):
    bid = _new_beneficiary(client, world)
    (ok,) = _push(
        client, world, "ac_a", _change("beneficiary", bid, base_version=1, birth_year=1999)
    )
    assert ok["status"] == "applied" and ok["server_version"] == 2
    stale = _change("beneficiary", bid, base_version=1, birth_year=1980)
    (conflict,) = _push(client, world, "ac_a", stale)
    assert conflict["status"] == "conflict"
    assert conflict["server_version"] == 2
    assert conflict["server_data"]["birth_year"] == 1999
    db.expire_all()
    assert db.get(Beneficiary, bid).birth_year == 1999
    # Rejouer le même change_id renvoie le même conflit.
    assert _push(client, world, "ac_a", stale) == [conflict]


def test_upsert_on_existing_without_base_version_is_conflict(client, world):
    bid = _new_beneficiary(client, world)
    (result,) = _push(client, world, "ac_a", _change("beneficiary", bid, birth_year=1990))
    assert result["status"] == "conflict"


def test_push_out_of_scope_is_rejected_as_not_found(client, world):
    bid = _new_beneficiary(client, world, who="ac_a")
    (result,) = _push(client, world, "ac_b", _change("beneficiary", bid, base_version=1))
    assert result["status"] == "rejected"
    assert result["error"]["code"] == "not_found"
    assert "introuvable" in result["error"]["message"]
    (create,) = _push(client, world, "ac_b", _change("beneficiary", site_id=str(world.site_a.id)))
    assert create["status"] == "rejected"


@pytest.mark.parametrize(
    ("entity", "code"),
    # Contrat §8 : alert en lecture seule, referral synchronisable (données vides
    # => invalides), entité inconnue refusée.
    [("alert", "read_only"), ("referral", "validation_error"), ("inconnue", "unsupported_entity")],
)
def test_unsupported_entities_rejected(client, world, entity, code):
    (result,) = _push(client, world, "ac_a", _change(entity))
    assert result["status"] == "rejected"
    assert result["error"]["code"] == code


@pytest.mark.parametrize("who", ["admin", "data", "tech"])
def test_non_care_roles_cannot_push(client, world, who):
    (result,) = _push(client, world, who, _change("beneficiary", site_id=str(world.site_a.id)))
    assert result["status"] == "rejected"
    assert result["error"] == {"code": "forbidden", "message": "Accès refusé."}


def test_invalid_data_rejected_without_failing_batch(client, world):
    bad = _change("beneficiary", birth_year="pas-un-nombre")
    good = _change("beneficiary")
    results = _push(client, world, "ac_a", bad, good)
    assert [r["status"] for r in results] == ["rejected", "applied"]
    assert results[0]["error"]["code"] == "validation_error"


# --- Consentement, grossesse, visite via sync ---------------------------------


def test_pregnancy_push_requires_reny_consent(client, world):
    bid = _new_beneficiary(client, world)
    lmp = (utcnow().date() - timedelta(days=30)).isoformat()
    (refused,) = _push(
        client, world, "ac_a", _change("pregnancy", beneficiary_id=str(bid), lmp_date=lmp)
    )
    assert refused["status"] == "rejected"
    assert refused["error"]["code"] == "consent_required"
    consent = _change(
        "consent",
        beneficiary_id=str(bid),
        scope="reny",
        method="oral",
        information_version="demo-0.1",
    )
    pregnancy = _change("pregnancy", beneficiary_id=str(bid), lmp_date=lmp)
    results = _push(client, world, "ac_a", consent, pregnancy)
    assert [r["status"] for r in results] == ["applied", "applied"]


def test_consent_withdrawal_via_sync_cancels_reminders(client, world, db):
    bid = _new_beneficiary(client, world)
    common = {"beneficiary_id": str(bid), "method": "oral", "information_version": "demo-0.1"}
    reminders_id = uuid.uuid4()
    lmp = (utcnow().date() - timedelta(days=30)).isoformat()
    _push(
        client,
        world,
        "ac_a",
        _change("consent", **common, scope="reny"),
        _change("consent", reminders_id, **common, scope="reminders"),
        _change("pregnancy", beneficiary_id=str(bid), lmp_date=lmp),
    )
    assert db.scalars(select(Reminder).where(Reminder.status == ReminderStatus.SCHEDULED)).all()
    withdraw = _change("consent", reminders_id, base_version=1, withdrawn_at=utcnow().isoformat())
    (result,) = _push(client, world, "ac_a", withdraw)
    assert result["status"] == "applied"
    assert result["server_data"]["withdrawn_at"] is not None
    db.expire_all()
    assert not db.scalars(select(Reminder).where(Reminder.status == ReminderStatus.SCHEDULED)).all()


def test_anc_visit_update_and_server_only_creation(client, world):
    bid = _new_beneficiary(client, world)
    lmp = (utcnow().date() - timedelta(days=30)).isoformat()
    _push(
        client,
        world,
        "ac_a",
        _change(
            "consent",
            beneficiary_id=str(bid),
            scope="reny",
            method="oral",
            information_version="demo-0.1",
        ),
        _change("pregnancy", beneficiary_id=str(bid), lmp_date=lmp),
    )
    visit = next(c for c in _pull(client, world, "ac_a")["changes"] if c["entity"] == "anc_visit")
    (done,) = _push(
        client,
        world,
        "ac_a",
        _change(
            "anc_visit",
            visit["id"],
            base_version=visit["version"],
            **(visit["data"] | {"status": "done"}),
        ),
    )
    assert done["status"] == "applied" and done["server_data"]["status"] == "done"
    (created,) = _push(client, world, "ac_a", _change("anc_visit", sequence=1))
    assert created["status"] == "rejected"


# --- Identité via sync --------------------------------------------------------


def test_identity_sync_roles_encryption_and_audit(client, world, db):
    bid = _new_beneficiary(client, world)
    ident = _change("beneficiary_identity", bid, display_name=FAKE_NAME, phone="0343333333")
    (applied,) = _push(client, world, "ac_a", ident)
    assert applied["status"] == "applied"
    assert applied["server_data"]["display_name"] == FAKE_NAME

    # Ni la table d'identité ni le journal de sync ne contiennent le nom en clair.
    for table in ("beneficiary_identities", "sync_changes"):
        raw = " ".join(str(v) for row in db.execute(text(f"SELECT * FROM {table}")) for v in row)  # noqa: S608
        assert FAKE_NAME not in raw and "0343333333" not in raw
    # Le rejeu renvoie pourtant le même résultat (stocké chiffré).
    assert _push(client, world, "ac_a", ident) == [applied]

    pulled = _pull(client, world, "ac_a")["changes"]
    identity = next(c for c in pulled if c["entity"] == "beneficiary_identity")
    assert identity["data"]["display_name"] == FAKE_NAME
    reads = db.scalars(select(AuditEvent).where(AuditEvent.action == "identity.read")).all()
    assert len(reads) == 1

    for who in ("admin", "data"):
        entities = {c["entity"] for c in _pull(client, world, who)["changes"]}
        assert "beneficiary" in entities and "beneficiary_identity" not in entities
    (refused,) = _push(
        client, world, "admin", _change("beneficiary_identity", bid, display_name="X")
    )
    assert refused["status"] == "rejected"


# --- Pull : périmètre, curseur, suppression -----------------------------------


def test_pull_respects_site_scope(client, world):
    a = _new_beneficiary(client, world, who="ac_a")
    b = _new_beneficiary(client, world, who="ac_b")
    ids_a = {c["id"] for c in _pull(client, world, "ac_a")["changes"]}
    ids_b = {c["id"] for c in _pull(client, world, "ac_b")["changes"]}
    assert str(a) in ids_a and str(b) not in ids_a
    assert str(b) in ids_b and str(a) not in ids_b
    ids_lead = {c["id"] for c in _pull(client, world, "lead")["changes"]}
    assert {str(a), str(b)} <= ids_lead


def test_pull_cursor_pagination_is_complete_and_ordered(client, world):
    created = {str(_new_beneficiary(client, world)) for _ in range(5)}
    seen: list[str] = []
    cursor = None
    for _ in range(10):
        page = _pull(client, world, "ac_a", since=cursor, limit=2)
        seen += [c["id"] for c in page["changes"] if c["entity"] == "beneficiary"]
        cursor = page["next_cursor"]
        if not page["has_more"]:
            break
    assert len(seen) == len(set(seen)) == 5
    assert set(seen) == created
    # Rien de nouveau après le dernier curseur.
    tail = _pull(client, world, "ac_a", since=cursor)
    assert tail["changes"] == [] and tail["next_cursor"] == cursor


def test_pull_returns_later_updates_after_cursor(client, world):
    bid = _new_beneficiary(client, world)
    cursor = _pull(client, world, "ac_a")["next_cursor"]
    _push(client, world, "ac_a", _change("beneficiary", bid, base_version=1, birth_year=2002))
    changes = _pull(client, world, "ac_a", since=cursor)["changes"]
    assert [(c["id"], c["version"]) for c in changes] == [(str(bid), 2)]


def test_soft_delete_propagates(client, world):
    bid = _new_beneficiary(client, world)
    _push(client, world, "ac_a", _change("beneficiary_identity", bid, display_name=FAKE_NAME))
    cursor = _pull(client, world, "ac_a")["next_cursor"]
    delete = _change("beneficiary", bid, op="delete", base_version=1) | {"data": None}
    (deleted,) = _push(client, world, "ac_a", delete)
    assert deleted["status"] == "applied" and deleted["server_data"] is None
    changes = _pull(client, world, "ac_a", since=cursor)["changes"]
    by_entity = {c["entity"]: c for c in changes}
    for entity in ("beneficiary", "beneficiary_identity"):
        assert by_entity[entity]["deleted_at"] is not None
        assert by_entity[entity]["data"] is None
    assert client.get(f"/beneficiaries/{bid}", headers=world.headers("ac_a")).status_code == 404
    (again,) = _push(
        client, world, "ac_a", _change("beneficiary", bid, base_version=2, birth_year=1)
    )
    assert again["status"] == "conflict"


def test_invalid_cursor_is_422(client, world):
    resp = client.get("/sync/pull?since=pas-un-curseur", headers=world.headers("ac_a"))
    assert resp.status_code == 422


def test_sync_requires_authentication(client):
    assert client.get("/sync/pull").status_code == 401
    assert client.post("/sync/push", json={"device_id": "x", "changes": []}).status_code == 401


def test_unsupported_and_read_only_error_codes(client, world):
    site_change = _change("site", world.site_a.id, base_version=1, name="X")
    results = _push(client, world, "ac_a", _change("inconnue"), site_change)
    assert [r["error"]["code"] for r in results] == ["unsupported_entity", "read_only"]


def test_pull_includes_sites_read_only(client, world):
    changes = _pull(client, world, "ac_b")["changes"]
    sites = {c["id"]: c for c in changes if c["entity"] == "site"}
    # Tous les sites sont distribués (choix de to_site_id hors ligne).
    assert set(sites) == {str(world.site_a.id), str(world.zone_a1.id), str(world.site_b.id)}
    assert sites[str(world.site_a.id)]["data"]["code"] == "CSB-A"


def test_batch_over_100_changes_is_422(client, world):
    changes = [_change("beneficiary") for _ in range(101)]
    resp = client.post(
        "/sync/push",
        json={"device_id": "tablette-fictive-01", "changes": changes},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 422


def test_upsert_without_data_is_rejected(client, world):
    (result,) = _push(client, world, "ac_a", _change("beneficiary") | {"data": None})
    assert result["status"] == "rejected"
    assert result["error"]["code"] == "validation_error"


def test_consent_withdrawal_cannot_be_undone_and_is_immutable(client, world, db):
    bid = _new_beneficiary(client, world)
    cid = uuid.uuid4()
    consent = {
        "beneficiary_id": str(bid),
        "scope": "reminders",
        "method": "written",
        "information_version": "demo-0.1",
    }
    (created,) = _push(client, world, "ac_a", _change("consent", cid, **consent))
    data = created["server_data"]
    # Renvoyer l'objet complet inchangé : aucun effet.
    (noop,) = _push(client, world, "ac_a", _change("consent", cid, base_version=1, **data))
    assert noop["status"] == "applied" and noop["server_version"] == 1
    (changed,) = _push(
        client, world, "ac_a", _change("consent", cid, base_version=1, **(data | {"scope": "reny"}))
    )
    assert changed["status"] == "rejected"
    withdrawn_at = utcnow().isoformat()
    (withdrawn,) = _push(
        client,
        world,
        "ac_a",
        _change("consent", cid, base_version=1, **(data | {"withdrawn_at": withdrawn_at})),
    )
    assert withdrawn["status"] == "applied"
    assert withdrawn["server_data"]["withdrawn_by_user_id"] == str(world.users["ac_a"].id)
    (undo,) = _push(
        client,
        world,
        "ac_a",
        _change("consent", cid, base_version=2, **(data | {"withdrawn_at": None})),
    )
    assert undo["status"] == "rejected"
    assert undo["error"]["code"] == "invalid_transition"
