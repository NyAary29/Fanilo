"""Réponses informatives (F-06), menus vocaux et TANORA (F-15), statistiques
thématiques (F-16), export DHIS2 (F-17) et jeu de démonstration. Données fictives."""

import uuid
from datetime import date

import pytest
from sqlalchemy import select

from app.core.config import Environment
from app.modules.audit.models import AuditEvent
from app.modules.devseed import DEMO_USERS, seed
from app.modules.interactions.ai_client import get_ai_client
from app.modules.interactions.models import Interaction
from app.modules.users.models import User
from tests.helpers import FakeAi, create_beneficiary, import_demo_contents


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True, "stats_min_cell_size": 2})


@pytest.fixture
def contents(session_factory):
    import_demo_contents(session_factory)


def _fake(app, **kwargs) -> FakeAi:
    fake = FakeAi(**kwargs)
    app.dependency_overrides[get_ai_client] = lambda: fake
    return fake


def _ask(client, world, who="ac_a", **body):
    resp = client.post("/interactions/ask", json=body, headers=world.headers(who))
    assert resp.status_code == 200, resp.text
    return resp.json()


# --- Réponses informatives -----------------------------------------------------


def test_covered_intent_answers_from_approved_content(app, client, world, contents, db):
    _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.6)
    data = _ask(client, world, module="reny", text="fizahana vohoka")
    assert data["outcome"] == "answer"
    assert data["actions"] == []
    assert data["content"]["code"] == "MSG_DEMO_INFO_ANC"
    assert data["is_demo"] is True
    row = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert row.intent == "ask_anc_schedule"
    assert row.review_status == "not_required"
    assert row.decision_trace[-1]["step"] == "intent_answer"


def test_tanora_answer_requires_counselor_confirmation(app, client, world, contents, db):
    _fake(app, sign_codes=(), intent="ask_menstruation", confidence=0.6)
    data = _ask(client, world, module="tanora", text="fadimbolana")
    assert data["outcome"] == "answer"
    assert data["content"]["code"] == "MSG_DEMO_INFO_MENSTRUATION"
    row = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert row.review_status == "pending"


def test_detected_sign_always_wins_over_intent(app, client, world, contents):
    _fake(app, sign_codes=("SIGN_DEMO_01",), intent="ask_anc_schedule", confidence=0.95)
    data = _ask(client, world, module="reny", text="fizahana vohoka sy ra")
    assert data["outcome"] == "danger_sign"
    assert data["alert_id"]


def test_low_sign_confidence_with_intent_goes_to_human(app, client, world, contents):
    _fake(app, sign_codes=("SIGN_DEMO_01",), intent="ask_anc_schedule", confidence=0.6)
    data = _ask(client, world, module="reny", text="fizahana vohoka sy ra")
    assert data["outcome"] == "fallback"
    assert "transfer_counselor" in data["actions"]


@pytest.mark.parametrize(
    ("intent", "confidence", "module"),
    [
        ("ask_anc_schedule", 0.5, "reny"),  # sous le seuil de la configuration
        ("out_of_scope", 0.9, "reny"),  # intention non couverte
        ("ask_menstruation", 0.9, "reny"),  # couverte pour tanora seulement
    ],
)
def test_uncovered_or_uncertain_intent_falls_back(
    app, client, world, contents, intent, confidence, module
):
    _fake(app, sign_codes=(), intent=intent, confidence=confidence)
    data = _ask(client, world, module=module, text="texte fictif")
    assert data["outcome"] == "fallback"
    assert data["actions"] == ["transfer_counselor"]


def test_intent_without_published_content_falls_back(app, client, world):
    _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.9)
    data = _ask(client, world, module="reny", text="fizahana vohoka")
    assert data["outcome"] == "fallback"


def test_demo_information_config_ignored_without_demo_mode(app, client, world, contents, settings):
    settings.allow_demo_content = False
    _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.9)
    resp = client.post(
        "/interactions/ask",
        json={"module": "reny", "text": "fizahana vohoka"},
        headers=world.headers("ac_a"),
    )
    assert resp.json()["outcome"] == "fallback"
    menu = client.get("/reference/menus?module=reny", headers=world.headers("ac_a"))
    assert menu.status_code == 503


# --- Menus vocaux --------------------------------------------------------------


def test_tanora_menu_lists_published_contents(client, world, contents):
    resp = client.get("/reference/menus?module=tanora&language=fr", headers=world.headers("ac_a"))
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["is_demo"] is True
    assert [i["key"] for i in data["items"]] == [1, 2, 3]
    assert data["items"][0]["code"] == "MSG_DEMO_INFO_MENSTRUATION"


def test_menu_skips_unpublished_contents(client, world):
    resp = client.get("/reference/menus?module=tanora", headers=world.headers("ac_a"))
    assert resp.status_code == 200
    assert resp.json()["items"] == []


# --- Statistiques thématiques --------------------------------------------------


def test_topic_stats_are_aggregated_with_small_cell_suppression(app, client, world, contents):
    _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.9)
    for _ in range(3):
        _ask(client, world, module="reny", text="fizahana vohoka")
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    _ask(client, world, module="reny", text="autre")  # cellule de 1 < 2 : masquée

    resp = client.get("/dashboard/topics", headers=world.headers("head_a"))
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["total"] == 4
    assert data["suppressed_cells"] == 1 and data["suppressed_total"] == 1
    assert data["items"] == [
        {
            "module": "reny",
            "intent": "ask_anc_schedule",
            "outcome": "answer",
            "content_code": "MSG_DEMO_INFO_ANC",
            "count": 3,
        }
    ]
    assert "beneficiary" not in resp.text


def test_topic_stats_scope_and_roles(app, client, world, contents):
    _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.9)
    for _ in range(2):
        _ask(client, world, module="reny", text="fizahana vohoka")
    other = client.get(
        f"/dashboard/topics?site_id={world.site_b.id}", headers=world.headers("lead")
    )
    assert other.json()["total"] == 0
    assert client.get("/dashboard/topics", headers=world.headers("ac_a")).status_code == 403
    assert client.get(
        f"/dashboard/topics?site_id={world.site_b.id}", headers=world.headers("head_a")
    ).status_code == 404


# --- Export DHIS2 --------------------------------------------------------------


def test_dhis2_export_is_aggregated_audited_and_restricted(app, client, world, contents, db):
    bid = create_beneficiary(client, world)
    lmp = date.today().replace(day=1)
    resp = client.post(
        f"/beneficiaries/{bid}/pregnancies",
        json={"lmp_date": lmp.isoformat()},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 201, resp.text
    _fake(app)
    for _ in range(2):
        _ask(client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_01"])

    period = date.today().strftime("%Y%m")
    for who in ("admin", "head_a", "lead", "ac_a"):
        assert client.get(
            f"/interop/dhis2/data-value-set?period={period}", headers=world.headers(who)
        ).status_code == 403
    resp = client.get(
        f"/interop/dhis2/data-value-set?period={period}", headers=world.headers("data")
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    values = {(v["dataElement"], v["orgUnit"]): v["value"] for v in data["dataValues"]}
    assert values[("FANILO_ALERTS", "CSB-A")] == "2"
    assert values[("FANILO_QUESTIONS", "CSB-A")] == "2"
    # Une seule grossesse (< 2) : masquée par défaut, visible sur demande explicite.
    assert ("FANILO_PREG_NEW", "CSB-A") not in values
    assert data["suppressed_values"] >= 1
    full = client.get(
        f"/interop/dhis2/data-value-set?period={period}&include_small_cells=true",
        headers=world.headers("data"),
    ).json()
    assert any(v["dataElement"] == "FANILO_PREG_NEW" for v in full["dataValues"])
    assert str(bid) not in resp.text
    audits = db.scalars(select(AuditEvent).where(AuditEvent.action == "export.aggregates")).all()
    assert len(audits) == 2
    assert client.get(
        "/interop/dhis2/data-value-set?period=202613", headers=world.headers("data")
    ).status_code == 422


# --- Jeu de démonstration ------------------------------------------------------


def test_devseed_is_idempotent_and_refused_in_production(db, settings):
    first = seed(db, settings)
    db.commit()
    second = seed(db, settings)
    assert first.users_created == len(DEMO_USERS) and second.users_created == 0
    assert second.sites_created == 0 and second.contents_created == 0
    assert len(db.scalars(select(User)).all()) == len(DEMO_USERS)
    prod = settings.model_copy(update={"environment": Environment.PRODUCTION})
    with pytest.raises(RuntimeError):
        seed(db, prod)
