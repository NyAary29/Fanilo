"""API publique anonyme (/public) : référentiels, question texte et audio,
urgence, jeton de suivi, réponse du conseiller, effacement, limitation de débit.
Données fictives."""

import uuid

import pytest
from sqlalchemy import select

from app.modules.alerts.models import Alert
from app.modules.interactions.ai_client import get_ai_client
from app.modules.interactions.models import Interaction
from app.modules.public import router as public_router
from tests.helpers import FakeAi, import_demo_contents

FAKE_AUDIO = b"RIFF" + b"\x00" * 2000


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


@pytest.fixture(autouse=True)
def fresh_limiter(monkeypatch):
    monkeypatch.setattr(public_router, "_limiter", public_router._RateLimiter())


@pytest.fixture
def contents(session_factory):
    import_demo_contents(session_factory)


def _fake(app, **kw):
    fake = FakeAi(**kw)
    app.dependency_overrides[get_ai_client] = lambda: fake
    return fake


def test_public_reference_endpoints_need_no_account(client, world, contents):
    sites = client.get("/public/sites").json()["items"]
    assert {s["name"] for s in sites} == {"Site fictif CSB-A", "Site fictif CSB-B"}  # CSB seulement
    info = client.get("/public/information").json()["items"]
    assert {i["scope"] for i in info} <= {"reny", "tanora", "voice_processing"}
    menu = client.get("/public/menus?module=tanora&language=fr").json()
    assert [i["key"] for i in menu["items"]] == [1, 2, 3]


def test_anonymous_tanora_question_follow_up_and_counselor_answer(app, client, world, contents, db):
    _fake(app, sign_codes=(), intent="ask_menstruation", confidence=0.9)
    data = client.post(
        "/public/ask",
        json={"module": "tanora", "text": "fadimbolana", "site_id": str(world.site_a.id)},
    ).json()
    assert data["outcome"] == "answer" and data["urgent"] is False
    token = data["follow_up"]["token"]
    qid = data["question_id"]
    row = db.get(Interaction, uuid.UUID(qid))
    assert row.asked_by_user_id is None and row.beneficiary_id is None
    assert row.channel == "public_app" and row.follow_up_token_hash != token  # empreinte seulement

    assert client.get(f"/public/questions/{qid}?token={token}").json()["status"] == "pending"
    assert client.get(f"/public/questions/{qid}?token={'x' * 30}").status_code == 404
    resp = client.post(
        f"/interactions/{qid}/review",
        json={"note": "Réponse fictive du conseiller"},
        headers=world.headers("advisor_a"),
    )
    assert resp.status_code == 200, resp.text
    answered = client.get(f"/public/questions/{qid}?token={token}").json()
    assert (
        answered["status"] == "answered" and answered["answer"] == "Réponse fictive du conseiller"
    )

    assert client.delete(f"/public/questions/{qid}?token={token}").status_code == 204
    assert client.get(f"/public/questions/{qid}?token={token}").status_code == 404
    db.expire_all()
    row = db.get(Interaction, uuid.UUID(qid))
    assert row.transcript is None and row.review_note is None


def test_siteless_anonymous_question_is_reviewable_by_any_advisor(app, client, world, contents):
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    qid = client.post("/public/ask", json={"module": "reny", "text": "autre"}).json()["question_id"]
    pending = client.get(
        "/interactions?review_status=pending", headers=world.headers("advisor_a")
    ).json()["items"]
    assert qid in {i["id"] for i in pending}


def test_danger_sign_is_urgent_without_any_alert(app, client, world, contents, db):
    _fake(app, sign_codes=("SIGN_DEMO_01",), confidence=0.95)
    data = client.post("/public/ask", json={"module": "reny", "text": "fictif"}).json()
    assert data["outcome"] == "danger_sign" and data["urgent"] is True
    assert db.scalars(select(Alert)).all() == []


def test_suspected_sign_under_threshold_is_still_urgent(app, client, world, contents):
    _fake(app, sign_codes=("SIGN_DEMO_01",), confidence=0.5)
    data = client.post("/public/ask", json={"module": "reny", "text": "fictif"}).json()
    assert data["outcome"] == "fallback" and data["urgent"] is True
    assert data["follow_up"] is not None


def test_audio_requires_voice_consent(app, client, world, contents):
    fake = _fake(app, sign_codes=(), intent="ask_anc_schedule", confidence=0.9)
    files = {"audio": ("q.wav", FAKE_AUDIO, "audio/wav")}
    resp = client.post("/public/ask", data={"module": "reny"}, files=files)
    assert resp.status_code == 422
    assert fake.calls == []
    resp = client.post("/public/ask", data={"module": "reny", "voice_consent": "true"}, files=files)
    assert resp.status_code == 200, resp.text
    assert resp.json()["transcript"] == "texte fictif transcrit"


def test_unknown_site_and_rate_limit(app, client, world, contents, settings):
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    bad = client.post(
        "/public/ask", json={"module": "reny", "text": "x", "site_id": str(world.zone_a1.id)}
    )
    assert bad.status_code == 422  # une zone communautaire n'est pas un CSB
    settings.public_ask_per_hour = 3  # la requête refusée ci-dessus compte aussi
    codes = [
        client.post("/public/ask", json={"module": "reny", "text": "x"}).status_code
        for _ in range(3)
    ]
    assert codes == [200, 200, 429]


def test_public_api_can_be_disabled(client, settings):
    settings.public_api_enabled = False
    assert client.get("/public/sites").status_code == 404


def test_anonymous_fallback_never_promises_a_call_back(app, client, world, contents):
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    data = client.post("/public/ask", json={"module": "reny", "text": "autre"}).json()
    assert data["outcome"] == "fallback"
    assert data["content"]["code"] == "MSG_DEMO_PUBLIC_TRANSFER"
    # Malgache par défaut : le message renvoie vers « Ny fanontaniako » (Mes questions).
    assert "Ny fanontaniako" in data["content"]["body"]


def test_public_information_is_specific_to_anonymous_use(client):
    items = client.get("/public/information").json()["items"]
    assert items and all(i["version"].startswith("public-") for i in items)
    assert not any("dossier" in i["summary_fr"] for i in items)


def test_short_or_wrong_token_is_404(client):
    assert client.get(f"/public/questions/{uuid.uuid4()}?token=abc").status_code == 404


def test_counselor_orients_to_a_health_centre(app, client, world, contents, make_site):
    from app.modules.sites.models import SiteKind

    hospital = make_site("CHR-FICTIF", kind=SiteKind.REFERENCE_FACILITY)
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    data = client.post("/public/ask", json={"module": "tanora", "text": "fanontaniana"}).json()
    qid, token = data["question_id"], data["follow_up"]["token"]
    bad = client.post(
        f"/interactions/{qid}/review",
        json={"note": "x", "orientation_site_id": str(world.zone_a1.id)},
        headers=world.headers("advisor_a"),
    )
    assert bad.status_code == 422  # une zone communautaire n'est pas un centre de santé
    ok = client.post(
        f"/interactions/{qid}/review",
        json={"note": "Allez consulter demain matin.", "orientation_site_id": str(hospital.id)},
        headers=world.headers("advisor_a"),
    )
    assert ok.status_code == 200, ok.text
    answer = client.get(f"/public/questions/{qid}?token={token}").json()
    assert answer["status"] == "answered"
    assert answer["orientation"]["name"] == "Site fictif CHR-FICTIF"
    assert answer["orientation"]["kind"] == "reference_facility"


def test_urgent_questions_come_first_for_counselors(app, client, world, contents):
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    calm = client.post("/public/ask", json={"module": "reny", "text": "a"}).json()["question_id"]
    _fake(app, sign_codes=("SIGN_DEMO_01",), intent="report_danger_sign", confidence=0.5)
    urgent = client.post("/public/ask", json={"module": "reny", "text": "b"}).json()["question_id"]
    items = client.get(
        "/interactions?review_status=pending", headers=world.headers("advisor_a")
    ).json()["items"]
    ids = [i["id"] for i in items]
    assert ids.index(urgent) < ids.index(calm)


def test_triage_follow_up_by_health_centre(app, client, world, contents):
    """Femme → conseiller (classe, répond, oriente) → centre (venue / pas venue)."""
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    data = client.post("/public/ask", json={"module": "reny", "text": "marary aho"}).json()
    qid, token = data["question_id"], data["follow_up"]["token"]

    # « Urgent » sans centre : refusé.
    missing = client.post(
        f"/interactions/{qid}/review",
        json={"note": "Allez au CSB.", "triage": "urgent"},
        headers=world.headers("advisor_a"),
    )
    assert missing.status_code == 422
    ok = client.post(
        f"/interactions/{qid}/review",
        json={
            "note": "Allez au CSB.",
            "triage": "urgent",
            "orientation_site_id": str(world.site_a.id),
        },
        headers=world.headers("advisor_a"),
    )
    assert ok.status_code == 200, ok.text
    seen = client.get(f"/public/questions/{qid}?token={token}").json()
    assert seen["triage"] == "urgent" and seen["follow_up_status"] == "expected"
    code = seen["follow_up_code"]
    assert len(code) == 5 and code[2] == "-"

    # Le responsable du centre A retrouve la personne par son code, puis enregistre sa venue.
    listed = client.get(
        f"/followup/orientations?code={code.lower()}", headers=world.headers("head_a")
    )
    assert listed.status_code == 200, listed.text
    body = listed.json()
    assert [i["id"] for i in body["items"]] == [qid] and body["counts"]["expected"] == 1
    assert client.get("/followup/orientations", headers=world.headers("ac_a")).status_code == 403
    other = client.post(
        f"/followup/orientations/{qid}", json={"status": "came"}, headers=world.headers("ac_b")
    )
    assert other.status_code == 403
    done = client.post(
        f"/followup/orientations/{qid}",
        json={"status": "came", "note": "Vue en consultation"},
        headers=world.headers("head_a"),
    )
    assert done.status_code == 200 and done.json()["follow_up_status"] == "came"
    assert client.get(f"/public/questions/{qid}?token={token}").json()["follow_up_status"] == "came"


def test_simple_information_needs_no_centre(app, client, world, contents):
    _fake(app, sign_codes=(), intent="out_of_scope", confidence=0.1)
    qid = client.post("/public/ask", json={"module": "tanora", "text": "x"}).json()["question_id"]
    ok = client.post(
        f"/interactions/{qid}/review",
        json={"note": "Information.", "triage": "info"},
        headers=world.headers("advisor_a"),
    )
    assert ok.status_code == 200
    assert ok.json()["follow_up_code"] is None and ok.json()["triage"] == "info"
