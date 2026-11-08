"""Bénéficiaires, identité chiffrée et consentements (section 3). Données fictives."""

import re
import uuid

import pytest
from sqlalchemy import select, text

from app.core.crypto import get_cipher
from app.modules.beneficiaries.models import BeneficiaryIdentity
from app.modules.beneficiaries.service import generate_code

FAKE_NAME = "Voahangy Fictive"
FAKE_PHONE = "0341111111"
CODE_RE = re.compile(r"^FAN-[A-HJKMNP-Z2-9]{6}$")
CONSENT = {"scope": "reny", "method": "oral", "information_version": "demo-0.1"}


def _create(client, world, who="ac_a", **body):
    resp = client.post("/beneficiaries", json=body, headers=world.headers(who))
    assert resp.status_code == 201, resp.text
    return resp.json()


# --- Création et lecture ------------------------------------------------------


def test_community_agent_creates_beneficiary_on_own_site(client, world):
    body = _create(client, world, birth_year=2004, preferred_channel="sms")
    assert CODE_RE.match(body["code"])
    assert body["site_id"] == str(world.site_a.id)
    assert body["version"] == 1 and body["deleted_at"] is None
    assert {"id", "created_at", "updated_at"} <= set(body)
    assert not {"display_name", "phone", "name"} & set(body)


def test_client_generated_id_is_kept_and_duplicate_is_409(client, world):
    client_id = str(uuid.uuid4())
    assert _create(client, world, id=client_id)["id"] == client_id
    dup = client.post("/beneficiaries", json={"id": client_id}, headers=world.headers("ac_a"))
    assert dup.status_code == 409


def test_codes_are_random_and_not_sequential(db, world):
    codes = [generate_code(db) for _ in range(300)]
    assert len(set(codes)) == len(codes)
    assert all(CODE_RE.match(c) for c in codes)
    assert codes != sorted(codes)


@pytest.mark.parametrize("who", ["admin", "data", "tech"])
def test_non_care_roles_cannot_create(client, world, who):
    body = {"site_id": str(world.site_a.id)}
    assert client.post("/beneficiaries", json=body, headers=world.headers(who)).status_code == 403


def test_invalid_birth_year_is_422(client, world):
    resp = client.post("/beneficiaries", json={"birth_year": 1800}, headers=world.headers("ac_a"))
    assert resp.status_code == 422


def test_global_user_must_give_site(client, world):
    lead = world.headers("lead")
    assert client.post("/beneficiaries", json={}, headers=lead).status_code == 422
    resp = client.post("/beneficiaries", json={"site_id": str(world.site_b.id)}, headers=lead)
    assert resp.status_code == 201


# --- Isolement entre sites ----------------------------------------------------


def test_agent_of_site_b_cannot_see_site_a(client, world):
    bid = _create(client, world)["id"]
    ac_b = world.headers("ac_b")
    assert client.get(f"/beneficiaries/{bid}", headers=ac_b).status_code == 404
    assert client.get("/beneficiaries", headers=ac_b).json()["total"] == 0
    patch = client.patch(f"/beneficiaries/{bid}", json={"version": 1}, headers=ac_b)
    assert patch.status_code == 404
    assert client.get(f"/beneficiaries/{bid}/consents", headers=ac_b).status_code == 404
    assert client.get(f"/beneficiaries/{bid}/identity", headers=ac_b).status_code == 404


def test_agent_cannot_create_on_other_site(client, world):
    resp = client.post(
        "/beneficiaries", json={"site_id": str(world.site_b.id)}, headers=world.headers("ac_a")
    )
    assert resp.status_code == 403


def test_parent_site_sees_child_site_but_not_reverse(client, world):
    child = _create(client, world, who="ac_a1")["id"]
    parent = _create(client, world, who="ac_a")["id"]
    seen_by_a = {
        b["id"] for b in client.get("/beneficiaries", headers=world.headers("ac_a")).json()["items"]
    }
    assert {child, parent} <= seen_by_a
    seen_by_a1 = client.get("/beneficiaries", headers=world.headers("ac_a1")).json()
    assert [b["id"] for b in seen_by_a1["items"]] == [child]


def test_global_roles_see_everything_and_filter_by_site(client, world):
    _create(client, world, who="ac_a")
    _create(client, world, who="ac_b")
    for who in ("admin", "data", "lead"):
        assert client.get("/beneficiaries", headers=world.headers(who)).json()["total"] == 2
    only_b = client.get(f"/beneficiaries?site_id={world.site_b.id}", headers=world.headers("admin"))
    assert only_b.json()["total"] == 1


# --- Modification et version --------------------------------------------------


def test_patch_requires_current_version(client, world):
    bid = _create(client, world)["id"]
    headers = world.headers("ac_a")
    missing = client.patch(f"/beneficiaries/{bid}", json={"birth_year": 2000}, headers=headers)
    assert missing.status_code == 409
    ok = client.patch(
        f"/beneficiaries/{bid}", json={"version": 1, "birth_year": 2000}, headers=headers
    )
    assert ok.status_code == 200 and ok.json()["version"] == 2
    stale = client.patch(
        f"/beneficiaries/{bid}", json={"version": 1, "birth_year": 2001}, headers=headers
    )
    assert stale.status_code == 409
    assert client.get(f"/beneficiaries/{bid}", headers=headers).json()["birth_year"] == 2000


def test_patch_cannot_move_beneficiary_out_of_scope(client, world):
    bid = _create(client, world)["id"]
    resp = client.patch(
        f"/beneficiaries/{bid}",
        json={"version": 1, "site_id": str(world.site_b.id)},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 403


# --- Identité chiffrée --------------------------------------------------------


def test_identity_is_encrypted_at_rest(client, world, db, settings):
    bid = _create(client, world)["id"]
    body = {"display_name": FAKE_NAME, "phone": FAKE_PHONE, "village": "Ambohi-Fictif"}
    resp = client.put(f"/beneficiaries/{bid}/identity", json=body, headers=world.headers("ac_a"))
    assert resp.status_code == 200
    assert resp.json()["display_name"] == FAKE_NAME

    raw_rows = db.execute(text("SELECT * FROM beneficiary_identities")).all()
    raw = " ".join(str(v) for row in raw_rows for v in row)
    assert FAKE_NAME not in raw and FAKE_PHONE not in raw and "Ambohi" not in raw
    stored = db.scalar(select(BeneficiaryIdentity))
    assert get_cipher(settings).decrypt(stored.display_name_encrypted) == FAKE_NAME


def test_identity_readable_by_nominative_roles_in_scope(client, world):
    bid = _create(client, world)["id"]
    client.put(
        f"/beneficiaries/{bid}/identity",
        json={"display_name": FAKE_NAME},
        headers=world.headers("ac_a"),
    )
    for who in ("ac_a", "head_a", "advisor_a", "lead"):
        resp = client.get(f"/beneficiaries/{bid}/identity", headers=world.headers(who))
        assert resp.status_code == 200, who
        assert resp.json()["display_name"] == FAKE_NAME
        assert resp.json()["beneficiary_id"] == bid


@pytest.mark.parametrize("who", ["admin", "data", "tech"])
def test_identity_forbidden_for_non_nominative_roles(client, world, who):
    bid = _create(client, world)["id"]
    headers = world.headers(who)
    assert client.get(f"/beneficiaries/{bid}/identity", headers=headers).status_code == 403
    put = client.put(
        f"/beneficiaries/{bid}/identity", json={"display_name": FAKE_NAME}, headers=headers
    )
    assert put.status_code == 403


def test_identity_missing_is_404_and_stale_version_is_409(client, world):
    bid = _create(client, world)["id"]
    headers = world.headers("ac_a")
    assert client.get(f"/beneficiaries/{bid}/identity", headers=headers).status_code == 404
    client.put(f"/beneficiaries/{bid}/identity", json={"display_name": "A"}, headers=headers)
    upd = client.put(
        f"/beneficiaries/{bid}/identity", json={"display_name": "B", "version": 1}, headers=headers
    )
    assert upd.status_code == 200 and upd.json()["version"] == 2
    stale = client.put(
        f"/beneficiaries/{bid}/identity", json={"display_name": "C", "version": 1}, headers=headers
    )
    assert stale.status_code == 409


def test_wrong_key_cannot_decrypt(client, world, db):
    from cryptography.fernet import Fernet

    from app.core.crypto import DecryptionError, FieldCipher

    bid = _create(client, world)["id"]
    client.put(
        f"/beneficiaries/{bid}/identity",
        json={"display_name": FAKE_NAME},
        headers=world.headers("ac_a"),
    )
    stored = db.scalar(select(BeneficiaryIdentity))
    with pytest.raises(DecryptionError):
        FieldCipher([Fernet.generate_key().decode()]).decrypt(stored.display_name_encrypted)


# --- Consentements ------------------------------------------------------------


def test_consent_lifecycle(client, world):
    bid = _create(client, world)["id"]
    headers = world.headers("ac_a")
    created = client.post(f"/beneficiaries/{bid}/consents", json=CONSENT, headers=headers)
    assert created.status_code == 201
    consent = created.json()
    assert consent["collected_by_user_id"] == str(world.users["ac_a"].id)
    assert consent["withdrawn_at"] is None

    listed = client.get(f"/beneficiaries/{bid}/consents", headers=headers).json()
    assert listed["total"] == 1

    withdrawn = client.post(f"/consents/{consent['id']}/withdraw", headers=headers)
    assert withdrawn.status_code == 200
    assert withdrawn.json()["withdrawn_at"] is not None
    assert withdrawn.json()["withdrawn_by_user_id"] == str(world.users["ac_a"].id)
    again = client.post(f"/consents/{consent['id']}/withdraw", headers=headers)
    assert again.status_code == 409


def test_consent_roles_and_scope(client, world):
    bid = _create(client, world)["id"]
    admin = world.headers("admin")
    assert (
        client.post(f"/beneficiaries/{bid}/consents", json=CONSENT, headers=admin).status_code
        == 403
    )
    cid = client.post(
        f"/beneficiaries/{bid}/consents", json=CONSENT, headers=world.headers("ac_a")
    ).json()["id"]
    assert client.post(f"/consents/{cid}/withdraw", headers=admin).status_code == 403
    assert (
        client.post(f"/consents/{cid}/withdraw", headers=world.headers("ac_b")).status_code == 404
    )


def test_consent_in_future_rejected(client, world):
    bid = _create(client, world)["id"]
    body = CONSENT | {"collected_at": "2999-01-01T00:00:00+00:00"}
    resp = client.post(f"/beneficiaries/{bid}/consents", json=body, headers=world.headers("ac_a"))
    assert resp.status_code == 422
