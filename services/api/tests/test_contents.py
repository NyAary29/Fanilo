"""Contenus de santé (section 5) : transitions, auteur, publication, démo, CLI.
Données fictives."""

import re
from pathlib import Path

import pytest
import yaml
from sqlalchemy import func, select

from app.core.config import DEFAULT_CONTENTS_DEMO_PATH, DEFAULT_RULESET_PATH, Environment
from app.db.models import Base
from app.db.session import make_engine
from app.modules.audit.models import AuditEvent
from app.modules.contents import cli as contents_cli
from app.modules.contents.catalog import load_catalog
from app.modules.contents.models import ContentItem, ContentStatus
from app.modules.users.roles import Role
from tests.helpers import import_demo_contents

DRAFT = {
    "code": "MSG_TEST_ORIENTATION",
    "module": "reny",
    "language": "fr",
    "title": "Titre fictif",
    "body": "Texte fictif d'orientation.",
}


@pytest.fixture
def lead2(world, make_user):
    world.users["lead2"] = make_user("resp.clinique.2", Role.CLINICAL_LEAD)
    return "lead2"


def _post(client, world, who, path, json=None):
    return client.post(path, json=json, headers=world.headers(who))


def _create(client, world, who="lead", **overrides):
    resp = _post(client, world, who, "/contents", DRAFT | overrides)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _validated(client, world, author, validator, **overrides):
    item = _create(client, world, author, **overrides)
    assert _post(client, world, author, f"/contents/{item['id']}/submit").status_code == 200
    resp = _post(client, world, validator, f"/contents/{item['id']}/validate")
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_full_lifecycle_and_transitions(client, world, lead2, db):
    item = _create(client, world, "lead")
    assert (item["status"], item["version"]) == ("draft", 1)
    cid = item["id"]
    patched = client.patch(
        f"/contents/{cid}", json={"title": "Titre corrigé"}, headers=world.headers("admin")
    )
    assert patched.status_code == 200 and patched.json()["title"] == "Titre corrigé"
    # Validation directe d'un brouillon : 409.
    assert _post(client, world, lead2, f"/contents/{cid}/validate").status_code == 409
    assert _post(client, world, "lead", f"/contents/{cid}/submit").json()["status"] == "in_review"
    # Plus modifiable hors brouillon.
    assert (
        client.patch(f"/contents/{cid}", json={"title": "X"}, headers=world.headers("lead"))
    ).status_code == 409
    # Rejet : clinical_lead uniquement, note obligatoire.
    forbidden = _post(client, world, "admin", f"/contents/{cid}/reject", {"note": "n"})
    assert forbidden.status_code == 403
    assert _post(client, world, lead2, f"/contents/{cid}/reject", {}).status_code == 422
    rejected = _post(client, world, lead2, f"/contents/{cid}/reject", {"note": "À reformuler."})
    assert rejected.json()["status"] == "draft"
    assert rejected.json()["review_note"] == "À reformuler."
    _post(client, world, "lead", f"/contents/{cid}/submit")
    # L'auteur ne valide pas son propre contenu ; admin ne valide pas.
    assert _post(client, world, "lead", f"/contents/{cid}/validate").status_code == 403
    assert _post(client, world, "admin", f"/contents/{cid}/validate").status_code == 403
    validated = _post(client, world, lead2, f"/contents/{cid}/validate").json()
    assert validated["status"] == "validated"
    assert validated["validator_id"] == str(world.users["lead2"].id)
    assert validated["validated_at"] is not None
    assert _post(client, world, lead2, f"/contents/{cid}/validate").status_code == 409
    assert _post(client, world, "lead", f"/contents/{cid}/submit").status_code == 409
    actions = set(db.scalars(select(AuditEvent.action).where(AuditEvent.entity_id == cid)))
    assert {"content.submit", "content.reject", "content.validate"} <= actions


def test_new_version_retires_previous_on_validation(client, world, lead2, db):
    v1 = _validated(client, world, "lead", lead2)
    v2 = _post(client, world, lead2, f"/contents/{v1['id']}/new-version").json()
    assert (v2["status"], v2["version"], v2["code"]) == ("draft", 2, v1["code"])
    assert v2["author_id"] == str(world.users["lead2"].id)
    # Une seule version en cours à la fois ; nouvelle version depuis un brouillon : 409.
    assert _post(client, world, "lead", f"/contents/{v1['id']}/new-version").status_code == 409
    assert _post(client, world, "lead", f"/contents/{v2['id']}/new-version").status_code == 409
    # La version validée reste servie tant que la nouvelle n'est pas validée.
    published = client.get("/contents/published", headers=world.headers("ac_a")).json()
    assert [(i["id"], i["version"]) for i in published["items"]] == [(v1["id"], 1)]
    client.patch(
        f"/contents/{v2['id']}",
        json={"body": "Nouveau texte fictif."},
        headers=world.headers("lead2"),
    )
    _post(client, world, lead2, f"/contents/{v2['id']}/submit")
    assert _post(client, world, lead2, f"/contents/{v2['id']}/validate").status_code == 403
    assert _post(client, world, "lead", f"/contents/{v2['id']}/validate").status_code == 200
    old = client.get(f"/contents/{v1['id']}", headers=world.headers("lead")).json()
    assert old["status"] == "retired"
    published = client.get("/contents/published", headers=world.headers("ac_a")).json()
    assert [(i["id"], i["body"]) for i in published["items"]] == [
        (v2["id"], "Nouveau texte fictif.")
    ]
    retire_events = db.scalar(
        select(func.count())
        .select_from(AuditEvent)
        .where(AuditEvent.action == "content.retire", AuditEvent.entity_id == v1["id"])
    )
    assert retire_events == 1


def test_validation_does_not_retire_other_language(client, world, lead2):
    fr = _validated(client, world, "lead", lead2)
    mg = _validated(client, world, "lead", lead2, language="mg", title="Lohateny", body="Votoaty")
    assert (
        client.get(f"/contents/{fr['id']}", headers=world.headers("lead")).json()["status"]
        == "validated"
    )
    assert mg["status"] == "validated"


def test_retire_and_duplicates(client, world, lead2):
    item = _validated(client, world, "lead", lead2)
    assert _post(client, world, "admin", f"/contents/{item['id']}/retire").status_code == 403
    assert _post(client, world, "lead", f"/contents/{item['id']}/retire").json()["status"] == (
        "retired"
    )
    assert _post(client, world, "lead", f"/contents/{item['id']}/retire").status_code == 409
    # Même code et même langue : passer par une nouvelle version.
    assert _post(client, world, "lead", "/contents", DRAFT).status_code == 409
    # Même code, autre module : refusé.
    other = DRAFT | {"language": "mg", "module": "tanora"}
    assert _post(client, world, "lead", "/contents", other).status_code == 422
    draft = _create(client, world, "lead", code="MSG_TEST_OTHER")
    assert _post(client, world, "lead", f"/contents/{draft['id']}/retire").status_code == 409


def test_management_roles(client, world):
    for who in ("ac_a", "head_a", "advisor_a", "data", "tech"):
        assert _post(client, world, who, "/contents", DRAFT).status_code == 403
        assert client.get("/contents", headers=world.headers(who)).status_code == 403
    item = _create(client, world, "admin")
    listed = client.get(
        "/contents?status=draft&module=reny&language=fr", headers=world.headers("lead")
    ).json()
    assert listed["total"] == 1 and listed["items"][0]["id"] == item["id"]
    assert (
        client.get("/contents?status=validated", headers=world.headers("lead")).json()["total"] == 0
    )


def test_published_respects_demo_mode(client, world, session_factory, settings, app):
    import_demo_contents(session_factory)
    headers = world.headers("ac_a")
    assert client.get("/contents/published", headers=headers).json()["total"] == 0
    settings.allow_demo_content = True
    published = client.get("/contents/published?language=fr", headers=headers).json()
    assert published["total"] >= 6
    assert {i["status"] for i in published["items"]} == {"demo"}
    # Le filtre module inclut les contenus "common" (message de fallback).
    reny = client.get("/contents/published?module=reny", headers=headers).json()["items"]
    assert "MSG_DEMO_TRANSFER_COUNSELOR" in {i["code"] for i in reny}
    tanora = client.get("/contents/published?module=tanora", headers=headers).json()["items"]
    # Filtre module : contenus tanora + communs, jamais ceux réservés à reny.
    tanora_codes = {i["code"] for i in tanora}
    assert {"MSG_DEMO_TRANSFER_COUNSELOR", "MSG_DEMO_INFO_MENSTRUATION"} <= tanora_codes
    assert "MSG_DEMO_CRITICAL" not in tanora_codes


def test_validated_content_preferred_over_demo(client, world, session_factory, settings, db):
    import_demo_contents(session_factory)
    settings.allow_demo_content = True
    demo = db.scalar(
        select(ContentItem).where(
            ContentItem.code == "MSG_DEMO_ROUTINE", ContentItem.language == "fr"
        )
    )
    db.add(
        ContentItem(
            code=demo.code,
            module=demo.module,
            language=demo.language,
            title="Validé fictif",
            body="Texte validé fictif.",
            version=2,
            status=ContentStatus.VALIDATED,
        )
    )
    db.commit()
    items = client.get("/contents/published", headers=world.headers("ac_a")).json()["items"]
    routine = [i for i in items if i["code"] == "MSG_DEMO_ROUTINE" and i["language"] == "fr"]
    assert [(i["status"], i["title"]) for i in routine] == [("validated", "Validé fictif")]


# --- Catalogue de démonstration et commande d'import -------------------------


def test_demo_catalog_covers_rules_and_is_marked_demo():
    text = DEFAULT_CONTENTS_DEMO_PATH.read_text(encoding="utf-8")
    assert "DÉMONSTRATION — NON VALIDÉ CLINIQUEMENT" in text
    catalog = load_catalog(DEFAULT_CONTENTS_DEMO_PATH)
    assert catalog.status == "demo"
    ruleset = yaml.safe_load(DEFAULT_RULESET_PATH.read_text(encoding="utf-8"))
    required = {r["message_code"] for r in ruleset["rules"]} | {ruleset["fallback_message_code"]}
    assert required <= catalog.codes
    for item in catalog.items:
        assert item.body.startswith(("[DÉMO]", "[DEMO]"))
        # Orientation uniquement : ni médicament, ni dosage, ni promesse de prise en charge.
        lowered = item.body.lower()
        for forbidden in (
            "médicament",
            " mg ",
            "comprimé",
            "dose",
            "va vous rappeler",
            "pris en charge",
            "prise en charge",
            "immédiatement",
        ):
            assert forbidden not in lowered, (item.code, forbidden)
    fallback = next(i for i in catalog.items if i.code == ruleset["fallback_message_code"])
    assert re.search(r"aucun délai .* garanti", fallback.body)
    assert "centre de santé le plus proche" in fallback.body


def _file_settings(settings, tmp_path: Path):
    url = f"sqlite:///{tmp_path / 'contents.db'}"
    engine = make_engine(url)
    Base.metadata.create_all(engine)
    engine.dispose()
    return settings.model_copy(update={"database_url": url})


def test_cli_import_demo_is_idempotent(settings, tmp_path, capsys):
    local = _file_settings(settings, tmp_path)
    assert contents_cli.import_demo(DEFAULT_CONTENTS_DEMO_PATH, local) == 0
    assert "importés : 22" in capsys.readouterr().out
    assert contents_cli.import_demo(DEFAULT_CONTENTS_DEMO_PATH, local) == 0
    assert "importés : 0, déjà présents : 22" in capsys.readouterr().out
    engine = make_engine(local.database_url)
    try:
        with engine.connect() as conn:
            statuses = set(conn.scalars(select(ContentItem.status)))
        assert statuses == {ContentStatus.DEMO}
    finally:
        engine.dispose()


def test_cli_import_refuses_production_and_non_demo(settings, tmp_path, capsys):
    production = settings.model_copy(update={"environment": Environment.PRODUCTION})
    assert contents_cli.import_demo(DEFAULT_CONTENTS_DEMO_PATH, production) == 1
    validated = tmp_path / "contents.yaml"
    raw = yaml.safe_load(DEFAULT_CONTENTS_DEMO_PATH.read_text(encoding="utf-8"))
    validated.write_text(yaml.safe_dump(raw | {"status": "validated"}), encoding="utf-8")
    assert contents_cli.import_demo(validated, _file_settings(settings, tmp_path)) == 1
    assert "invalide" in capsys.readouterr().err
