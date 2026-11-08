"""Référentiels (section 8 bis) : codes de signes et information de consentement,
selon le mode démo. Données fictives."""

import pytest
import yaml

from app.core.config import DEFAULT_CONSENT_INFORMATION_PATH


@pytest.fixture
def demo(settings):
    return settings.model_copy(update={"allow_demo_content": True})


def _client_for(settings, session_factory):
    from fastapi.testclient import TestClient

    from app.db.session import get_db
    from app.main import create_app

    app = create_app(settings)

    def _get_db():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


def test_sign_codes_in_demo_mode(demo, session_factory, world):
    with _client_for(demo, session_factory) as client:
        resp = client.get("/reference/sign-codes", headers=world.headers("ac_a"))
        assert resp.status_code == 200
        body = resp.json()
        assert body["catalog_id"] == "fanilo-demo-signs"
        assert (body["status"], body["is_demo"]) == ("demo", True)
        assert len(body["items"]) == 6
        first = body["items"][0]
        assert set(first) == {"code", "label_fr", "label_mg", "modules"}
        assert first["label_mg"] is None and first["label_fr"].startswith("[DÉMO]")
        tanora = client.get(
            "/reference/sign-codes?module=tanora", headers=world.headers("ac_a")
        ).json()
        assert {i["code"] for i in tanora["items"]} == {"SIGN_DEMO_05", "SIGN_DEMO_06"}
        assert client.get("/reference/sign-codes").status_code == 401


def test_sign_codes_refused_without_demo_mode(settings, session_factory, world):
    with _client_for(settings, session_factory) as client:
        resp = client.get("/reference/sign-codes", headers=world.headers("ac_a"))
        assert resp.status_code == 503


def test_consent_information_follows_demo_mode(demo, settings, session_factory, world):
    with _client_for(demo, session_factory) as client:
        items = client.get(
            "/reference/consent-information", headers=world.headers("ac_a")
        ).json()["items"]
        assert {i["scope"] for i in items} == {"reny", "tanora", "reminders", "voice_processing"}
        assert all(i["status"] == "demo" and i["summary_fr"].startswith("[DÉMO]") for i in items)
    with _client_for(settings, session_factory) as client:
        resp = client.get("/reference/consent-information", headers=world.headers("ac_a"))
        assert resp.status_code == 200 and resp.json() == {"items": []}


def test_consent_information_validated_items_and_errors(settings, session_factory, world,
                                                        tmp_path):
    raw = yaml.safe_load(DEFAULT_CONSENT_INFORMATION_PATH.read_text(encoding="utf-8"))
    raw["items"][0]["status"] = "validated"
    raw["items"][1]["status"] = "retired"
    path = tmp_path / "consent.yaml"
    path.write_text(yaml.safe_dump(raw, allow_unicode=True), encoding="utf-8")
    local = settings.model_copy(update={"consent_information_path": path})
    with _client_for(local, session_factory) as client:
        items = client.get(
            "/reference/consent-information", headers=world.headers("ac_a")
        ).json()["items"]
        assert [(i["scope"], i["status"]) for i in items] == [("reny", "validated")]
    demo_retired = local.model_copy(update={"allow_demo_content": True})
    with _client_for(demo_retired, session_factory) as client:
        scopes = [i["scope"] for i in client.get(
            "/reference/consent-information", headers=world.headers("ac_a")
        ).json()["items"]]
        assert "tanora" not in scopes and len(scopes) == 3
    missing = settings.model_copy(update={"consent_information_path": tmp_path / "absent.yaml"})
    with _client_for(missing, session_factory) as client:
        resp = client.get("/reference/consent-information", headers=world.headers("ac_a"))
        assert resp.status_code == 503


def test_consent_information_file_is_marked_demo():
    text = DEFAULT_CONSENT_INFORMATION_PATH.read_text(encoding="utf-8")
    assert "DÉMONSTRATION" in text
    assert yaml.safe_load(text)["status"] == "demo"
