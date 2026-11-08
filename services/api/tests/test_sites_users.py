"""Sites, comptes et helper de périmètre (lot P0.4). Données fictives."""

import uuid

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.modules.audit.models import AuditEvent
from app.modules.sites.models import Site
from app.modules.sites.scope import compute_site_scope, descendant_site_ids
from app.modules.users.models import User
from app.modules.users.roles import Role
from tests.conftest import TEST_PASSWORD

SITE_BODY = {
    "name": "CSB fictif de test",
    "kind": "csb",
    "code": "csb-test-01",
    "district": "District fictif",
    "region": "Région fictive",
}


# --- Sites --------------------------------------------------------------------


def test_sites_require_authentication(client):
    assert client.get("/sites").status_code == 401


def test_any_authenticated_user_can_list_sites(client, world):
    resp = client.get("/sites", headers=world.headers("ac_b"))
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 3
    assert set(body["items"][0]) == {
        "id",
        "name",
        "kind",
        "code",
        "district",
        "region",
        "parent_site_id",
        "is_active",
    }


def test_admin_creates_site_and_it_is_audited(client, world, db):
    resp = client.post(
        "/sites",
        json=SITE_BODY | {"parent_site_id": str(world.site_a.id)},
        headers=world.headers("admin"),
    )
    assert resp.status_code == 201
    assert resp.json()["code"] == "CSB-TEST-01"
    assert resp.json()["parent_site_id"] == str(world.site_a.id)
    event = db.scalar(select(AuditEvent).where(AuditEvent.action == "site.create"))
    assert event is not None and event.entity_id == resp.json()["id"]


@pytest.mark.parametrize("who", ["ac_a", "head_a", "lead", "data", "tech"])
def test_only_admin_writes_sites(client, world, who):
    assert client.post("/sites", json=SITE_BODY, headers=world.headers(who)).status_code == 403
    resp = client.patch(
        f"/sites/{world.site_a.id}", json={"is_active": False}, headers=world.headers(who)
    )
    assert resp.status_code == 403


def test_site_code_unique_and_parent_must_exist(client, world):
    admin = world.headers("admin")
    dup = client.post("/sites", json=SITE_BODY | {"code": "CSB-A"}, headers=admin)
    assert dup.status_code == 409
    orphan = client.post(
        "/sites", json=SITE_BODY | {"parent_site_id": str(uuid.uuid4())}, headers=admin
    )
    assert orphan.status_code == 422


def test_site_cannot_become_its_own_descendant(client, world):
    resp = client.patch(
        f"/sites/{world.site_a.id}",
        json={"parent_site_id": str(world.zone_a1.id)},
        headers=world.headers("admin"),
    )
    assert resp.status_code == 422


def test_admin_deactivates_site(client, world):
    resp = client.patch(
        f"/sites/{world.site_b.id}", json={"is_active": False}, headers=world.headers("admin")
    )
    assert resp.status_code == 200
    assert resp.json()["is_active"] is False
    active = client.get("/sites?is_active=true", headers=world.headers("admin")).json()
    assert str(world.site_b.id) not in {s["id"] for s in active["items"]}


def test_unknown_site_is_404(client, world):
    assert client.get(f"/sites/{uuid.uuid4()}", headers=world.headers("ac_a")).status_code == 404


# --- Comptes ------------------------------------------------------------------


@pytest.mark.parametrize("who", ["admin", "data"])
def test_users_listed_by_admin_and_data_officer(client, world, who):
    resp = client.get("/users", headers=world.headers(who))
    assert resp.status_code == 200
    item = resp.json()["items"][0]
    assert set(item) == {"id", "login", "role", "site_id", "is_active", "last_login_at"}
    assert "password_hash" not in resp.text


@pytest.mark.parametrize("who", ["ac_a", "head_a", "lead", "tech"])
def test_users_list_forbidden_for_other_roles(client, world, who):
    assert client.get("/users", headers=world.headers(who)).status_code == 403


def test_admin_creates_user(client, world):
    body = {
        "login": "nouvel.ac",
        "password": "mot-de-passe-fictif-long",
        "role": "community_agent",
        "site_id": str(world.site_b.id),
    }
    resp = client.post("/users", json=body, headers=world.headers("admin"))
    assert resp.status_code == 201
    assert resp.json()["site_id"] == str(world.site_b.id)
    assert resp.json()["last_login_at"] is None
    login = client.post(
        "/auth/login", json={"login": "nouvel.ac", "password": "mot-de-passe-fictif-long"}
    )
    assert login.status_code == 200


def test_create_user_validation(client, world):
    admin = world.headers("admin")
    base = {"login": "x.fictif", "password": "mot-de-passe-fictif-long", "role": "csb_head"}
    assert client.post("/users", json=base, headers=world.headers("data")).status_code == 403
    unknown_site = base | {"site_id": str(uuid.uuid4())}
    assert client.post("/users", json=unknown_site, headers=admin).status_code == 422
    short = base | {"password": "court"}
    assert client.post("/users", json=short, headers=admin).status_code == 422
    dup = base | {"login": "ac.a"}
    assert client.post("/users", json=dup, headers=admin).status_code == 409


def test_role_change_is_audited_and_revokes_sessions(client, world, db):
    target = world.users["ac_a"]
    tokens = client.post("/auth/login", json={"login": "ac.a", "password": TEST_PASSWORD}).json()
    resp = client.patch(
        f"/users/{target.id}", json={"role": "csb_head"}, headers=world.headers("admin")
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "csb_head"
    actions = set(
        db.scalars(select(AuditEvent.action).where(AuditEvent.entity_id == str(target.id)))
    )
    assert {"user.update", "user.role_change"} <= actions
    refresh = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refresh.status_code == 401


def test_admin_deactivates_user(client, world, db):
    target = world.users["ac_b"]
    resp = client.patch(
        f"/users/{target.id}", json={"is_active": False}, headers=world.headers("admin")
    )
    assert resp.status_code == 200
    login = client.post("/auth/login", json={"login": "ac.b", "password": TEST_PASSWORD})
    assert login.status_code == 401
    assert db.scalar(select(AuditEvent).where(AuditEvent.action == "user.deactivate"))


def test_admin_cannot_lock_themselves_out(client, world):
    admin = world.users["admin"]
    headers = world.headers("admin")
    assert (
        client.patch(f"/users/{admin.id}", json={"is_active": False}, headers=headers).status_code
        == 409
    )
    assert (
        client.patch(f"/users/{admin.id}", json={"role": "technical"}, headers=headers).status_code
        == 409
    )


def test_patch_user_unknown_site_and_unknown_user(client, world):
    headers = world.headers("admin")
    target = world.users["ac_a"]
    resp = client.patch(f"/users/{target.id}", json={"site_id": str(uuid.uuid4())}, headers=headers)
    assert resp.status_code == 422
    assert client.patch(f"/users/{uuid.uuid4()}", json={}, headers=headers).status_code == 404


def test_users_site_id_is_a_foreign_key(db):
    db.add(User(login="orphelin", password_hash="x", role=Role.CSB_HEAD, site_id=uuid.uuid4()))
    with pytest.raises(IntegrityError):
        db.commit()


# --- Helper de périmètre ------------------------------------------------------


def test_descendants_include_children_recursively(world, db, make_site):
    grandchild = make_site("ZONE-A1-X", parent_site_id=world.zone_a1.id)
    ids = descendant_site_ids(db, world.site_a.id)
    assert ids == {world.site_a.id, world.zone_a1.id, grandchild.id}
    assert descendant_site_ids(db, world.site_b.id) == {world.site_b.id}


def test_scope_by_role(world, db):
    lead = compute_site_scope(db, world.users["lead"])
    assert lead.is_global and lead.contains(world.site_b.id) and lead.contains(None)

    ac_a = compute_site_scope(db, world.users["ac_a"])
    assert ac_a.contains(world.site_a.id) and ac_a.contains(world.zone_a1.id)
    assert not ac_a.contains(world.site_b.id) and not ac_a.contains(None)

    ac_a1 = compute_site_scope(db, world.users["ac_a1"])
    assert not ac_a1.contains(world.site_a.id)


def test_user_without_site_sees_nothing(db, make_user, world):
    orphan = make_user("ac.sans.site", Role.COMMUNITY_AGENT)
    scope = compute_site_scope(db, orphan)
    assert not scope.is_global and scope.site_ids == frozenset()
    assert db.scalars(select(Site).where(scope.filter(Site.id))).all() == []


# --- Annuaire -----------------------------------------------------------------


def test_directory_is_scoped_and_minimal(client, world):
    resp = client.get("/users/directory", headers=world.headers("ac_a1"))
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert set(items[0]) == {"id", "login", "role", "site_id"}
    assert {i["login"] for i in items} == {"ac.a1"}

    logins_a = {
        i["login"]
        for i in client.get("/users/directory", headers=world.headers("ac_a")).json()["items"]
    }
    assert {"ac.a", "ac.a1", "chef.a", "conseil.a"} <= logins_a
    assert "ac.b" not in logins_a

    lead = client.get("/users/directory", headers=world.headers("lead")).json()
    assert lead["total"] == len(world.users)


def test_directory_forbidden_for_technical(client, world):
    assert client.get("/users/directory", headers=world.headers("tech")).status_code == 403
