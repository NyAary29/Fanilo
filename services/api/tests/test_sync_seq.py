"""Curseur de synchronisation fondé sur ``sync_seq`` (contrat §8) : valeur
strictement croissante à chaque écriture, ordre du pull, aucune ligne manquée
(transaction longue), suppression → ``data: null``, alertes en lecture seule.
Données fictives."""

import uuid
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.db.base import SyncCounter, current_sync_seq
from app.db.models import Base
from app.db.session import make_engine
from app.modules.alerts.models import Alert
from app.modules.beneficiaries.models import Beneficiary
from app.modules.interactions.ai_client import get_ai_client
from app.modules.sites.models import Site, SiteKind
from app.modules.sync.registry import SyncEntity, register_sync_entity
from app.modules.sync.service import decode_cursor
from app.modules.users.models import User
from tests.helpers import FakeAi, create_beneficiary


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


def _change(entity, entity_id=None, op="upsert", base_version=None, **data):
    return {
        "change_id": str(uuid.uuid4()), "entity": entity, "op": op,
        "id": str(entity_id or uuid.uuid4()), "base_version": base_version, "data": data,
    }


def _push(client, world, who, *changes):
    resp = client.post(
        "/sync/push", json={"device_id": "tablette-fictive", "changes": list(changes)},
        headers=world.headers(who),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["results"]


def _pull(client, world, who, since=None, limit=500):
    params = {"limit": limit} | ({"since": since} if since else {})
    resp = client.get("/sync/pull", params=params, headers=world.headers(who))
    assert resp.status_code == 200, resp.text
    return resp.json()


def _seq(db, model, entity_id):
    db.expire_all()
    return db.scalar(select(model.sync_seq).where(model.id == entity_id))


def test_every_write_gets_a_strictly_greater_seq(client, world, db):
    bid = uuid.uuid4()
    _push(client, world, "ac_a", _change("beneficiary", bid, birth_year=2001))
    first = _seq(db, Beneficiary, bid)
    _push(client, world, "ac_a", _change("beneficiary", bid, base_version=1, birth_year=2002))
    second = _seq(db, Beneficiary, bid)
    _push(client, world, "ac_a", _change("beneficiary", bid, op="delete", base_version=2))
    third = _seq(db, Beneficiary, bid)
    assert first < second < third
    assert current_sync_seq(db) >= third
    # Toutes les valeurs sont distinctes, toutes tables confondues.
    seqs = list(db.scalars(select(Site.sync_seq))) + list(db.scalars(select(Beneficiary.sync_seq)))
    assert len(seqs) == len(set(seqs))


def test_parents_get_lower_seq_within_a_flush(db, world):
    site = Site(name="Site fictif", kind=SiteKind.CSB, code="CSB-SEQ", district="D", region="R")
    db.add(site)
    db.flush()
    beneficiary = Beneficiary(code="FAN-SEQ001", site_id=site.id)
    other_site = Site(name="Autre", kind=SiteKind.CSB, code="CSB-SEQ2", district="D", region="R")
    db.add_all([beneficiary, other_site])
    db.commit()
    assert site.sync_seq < other_site.sync_seq < beneficiary.sync_seq


def test_non_synchronised_tables_do_not_take_a_seq(db, world):
    before = current_sync_seq(db)
    user = db.get(User, world.users["ac_a"].id)
    user.is_active = False
    db.commit()
    assert current_sync_seq(db) == before


def test_pull_is_ordered_by_seq_and_complete(client, world):
    created = {str(create_beneficiary(client, world, consents=())) for _ in range(4)}
    seen: list[str] = []
    cursors: list[int] = []
    cursor = None
    while True:
        page = _pull(client, world, "ac_a", since=cursor, limit=1)
        seen += [c["id"] for c in page["changes"]]
        cursor = page["next_cursor"]
        cursors.append(decode_cursor(cursor))
        if not page["has_more"]:
            break
    assert cursors == sorted(cursors) and len(set(cursors)) == len(cursors)
    assert created <= set(seen)
    assert len(seen) == len(set(seen))
    # Une modification ultérieure revient, une seule fois, après le curseur.
    bid = sorted(created)[0]
    _push(client, world, "ac_a", _change("beneficiary", bid, base_version=1, birth_year=2004))
    page = _pull(client, world, "ac_a", since=cursor)
    assert [(c["id"], c["version"]) for c in page["changes"]] == [(bid, 2)]
    assert _pull(client, world, "ac_a", since=page["next_cursor"])["changes"] == []


def test_deleted_rows_are_pulled_with_null_data(client, world):
    bid = create_beneficiary(client, world, consents=("reny",))
    cursor = _pull(client, world, "ac_a")["next_cursor"]
    _push(client, world, "ac_a", _change("beneficiary", bid, op="delete", base_version=1))
    changes = _pull(client, world, "ac_a", since=cursor)["changes"]
    assert {c["entity"] for c in changes} == {"beneficiary", "consent"}
    for change in changes:
        assert change["deleted_at"] is not None and change["data"] is None


def test_alert_is_pulled_and_read_only(client, world, app):
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()
    bid = create_beneficiary(client, world)
    cursor = _pull(client, world, "ac_a")["next_cursor"]
    alert_id = client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers("ac_a"),
    ).json()["alert_id"]
    changes = _pull(client, world, "ac_a", since=cursor)["changes"]
    (alert,) = [c for c in changes if c["entity"] == "alert"]
    assert alert["id"] == alert_id and alert["version"] == 1
    assert alert["data"]["status"] == "open" and alert["data"]["severity"] == "critical"
    # Hors périmètre ou rôle sans accès : absente.
    assert all(c["entity"] != "alert" for c in _pull(client, world, "ac_b")["changes"])
    assert all(c["entity"] != "alert" for c in _pull(client, world, "admin")["changes"])
    # Écriture refusée.
    (result,) = _push(
        client, world, "head_a", _change("alert", alert_id, base_version=1, status="resolved")
    )
    assert result["status"] == "rejected" and result["error"]["code"] == "read_only"
    # Un acquittement REST produit une nouvelle version distribuée.
    after = _pull(client, world, "head_a")["next_cursor"]
    client.post(f"/alerts/{alert_id}/acknowledge", headers=world.headers("head_a"))
    (acked,) = _pull(client, world, "head_a", since=after)["changes"]
    assert (acked["entity"], acked["version"], acked["data"]["status"]) == (
        "alert", 2, "acknowledged"
    )


def test_cursor_validation(client, world):
    for bad in ("pas-un-curseur", "eyJzIjotMX0", "eyJzIjoiYSJ9"):  # {"s":-1}, {"s":"a"}
        resp = client.get(f"/sync/pull?since={bad}", headers=world.headers("ac_a"))
        assert resp.status_code == 422


def test_registry_requires_sync_sequenced_model():
    with pytest.raises(TypeError):
        register_sync_entity(
            SyncEntity(
                name="user_test", model=User, rank=999, scoped_select=lambda _s: select(User),
                serialize=lambda _c, _o: {}, pull_roles=None, push=None,
            )
        )


# --- Transaction longue : aucune ligne manquée ---------------------------------------


def test_long_transaction_cannot_be_skipped(tmp_path: Path):
    """Deux connexions réelles (fichier SQLite) : une transaction longue qui a
    obtenu une valeur bloque toute autre attribution jusqu'à sa validation, et
    un lecteur ne voit jamais une borne haute qui la dépasserait.

    Sur PostgreSQL, le même mécanisme repose sur le verrou de ligne de
    ``sync_counter`` (non testé ici : pas de serveur PostgreSQL disponible).
    """
    url = f"sqlite:///{tmp_path / 'seq.db'}"
    engine = make_engine(url, connect_args={"check_same_thread": False, "timeout": 0.2})
    Base.metadata.create_all(engine)
    try:
        with Session(engine) as setup:
            site = Site(name="S", kind=SiteKind.CSB, code="CSB-L", district="D", region="R")
            setup.add(site)
            setup.commit()
            site_id, base = site.id, site.sync_seq

        long_tx = Session(engine)
        other_writer = Session(engine)
        reader = Session(engine)
        try:
            slow = Beneficiary(code="FAN-LONG01", site_id=site_id)
            long_tx.add(slow)
            long_tx.flush()  # valeur attribuée, transaction NON validée
            assert slow.sync_seq == base + 1

            # Un autre écrivain ne peut pas obtenir de valeur entre-temps.
            other_writer.add(Beneficiary(code="FAN-FAST01", site_id=site_id))
            with pytest.raises(OperationalError):
                other_writer.flush()
            other_writer.rollback()

            # Le lecteur (pull) voit la borne validée, sans la ligne en cours.
            horizon = current_sync_seq(reader)
            assert horizon == base
            visible = reader.scalars(
                select(Beneficiary).where(Beneficiary.sync_seq <= horizon)
            ).all()
            assert visible == []
            reader.rollback()

            long_tx.commit()
            # Après validation : la ligne apparaît au-delà de l'ancien curseur.
            later = reader.scalars(select(Beneficiary).where(Beneficiary.sync_seq > horizon)).all()
            assert [b.code for b in later] == ["FAN-LONG01"]
            reader.rollback()

            other_writer.add(Beneficiary(code="FAN-FAST01", site_id=site_id))
            other_writer.commit()
            assert reader.scalar(select(SyncCounter.value)) == base + 2
        finally:
            for session in (long_tx, other_writer, reader):
                session.close()
    finally:
        engine.dispose()


def test_alert_seq_with_db(db, client, world, app):
    app.dependency_overrides[get_ai_client] = lambda: FakeAi()
    bid = create_beneficiary(client, world)
    data = client.post(
        "/interactions/ask",
        json={"module": "reny", "beneficiary_id": str(bid), "sign_codes": ["SIGN_DEMO_01"]},
        headers=world.headers("ac_a"),
    ).json()
    seq = _seq(db, Alert, uuid.UUID(data["alert_id"]))
    assert seq is not None and seq > _seq(db, Beneficiary, bid)
