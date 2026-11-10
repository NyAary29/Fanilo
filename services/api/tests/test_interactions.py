"""POST /interactions/ask (section 6) : formes audio, texte et signes, service IA
factice (succès, délai, 5xx, confiance basse, code inconnu), consentements,
contenus publiés, alertes ; revue des interactions. Données fictives."""

import logging
import uuid
from datetime import timedelta

import httpx
import pytest
from sqlalchemy import select

from app.db.types import utcnow
from app.modules.alerts.models import Alert, AlertEvent
from app.modules.audit.models import AuditEvent
from app.modules.contents.models import ContentItem, ContentLanguage, ContentModule, ContentStatus
from app.modules.interactions.ai_client import HttpAiClient, get_ai_client
from app.modules.interactions.models import Interaction
from app.modules.users.roles import Role
from tests.helpers import FakeAi, add_consent, create_beneficiary, import_demo_contents

DISCLAIMER = "FANILO ne remplace pas un professionnel de santé."
FAKE_AUDIO = b"RIFF" + b"\x00" * 2000  # octets fictifs, jamais décodés


@pytest.fixture
def settings(settings):
    return settings.model_copy(update={"allow_demo_content": True})


@pytest.fixture
def contents(session_factory):
    import_demo_contents(session_factory)


@pytest.fixture
def fake_ai(app):
    fake = FakeAi()
    app.dependency_overrides[get_ai_client] = lambda: fake
    return fake


def _ask(client, world, who="ac_a", **body):
    resp = client.post("/interactions/ask", json=body, headers=world.headers(who))
    return resp


def _ask_ok(client, world, who="ac_a", **body):
    resp = _ask(client, world, who, **body)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["disclaimer"] == DISCLAIMER
    return data


def _ask_audio(client, world, who="ac_a", audio=FAKE_AUDIO, **fields):
    data = {"module": "reny"} | {k: str(v) for k, v in fields.items()}
    return client.post(
        "/interactions/ask",
        data=data,
        files={"audio": ("question.wav", audio, "audio/wav")},
        headers=world.headers(who),
    )


# --- Forme sign_codes : moteur de règles directement ----------------------------


def test_sign_codes_critical_creates_alert_with_recipient(client, world, contents, fake_ai, db):
    bid = create_beneficiary(client, world)
    before = utcnow()
    data = _ask_ok(
        client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_01"]
    )
    assert data["outcome"] == "danger_sign"
    assert data["severity"] == "critical"
    assert data["actions"] == ["refer_reference_facility"]
    assert data["transcript"] is None and data["transcript_needs_review"] is False
    # Contenu en malgache demandé par défaut : repli en français (démo).
    assert data["content"]["code"] == "MSG_DEMO_CRITICAL"
    assert data["content"]["status"] == "demo"
    assert data["is_demo"] is True
    assert fake_ai.calls == []  # aucun appel à l'IA pour une saisie déterministe

    alert = db.get(Alert, uuid.UUID(data["alert_id"]))
    assert alert.status == "open" and alert.severity == "critical"
    assert alert.rule_id == "DEMO-RENY-001"
    assert alert.recipient_user_id == world.users["head_a"].id
    assert alert.backup_user_id == world.users["advisor_a"].id
    assert alert.beneficiary_id == bid and alert.site_id == world.site_a.id
    # Règle de démo à délai placeholder : délai par défaut de DÉMO (60 min).
    assert alert.due_at_is_demo is True
    expected = before + timedelta(minutes=60)
    assert abs((alert.due_at - expected).total_seconds()) < 60
    assert alert.is_demo is True and alert.version == 1

    interaction = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert interaction.review_status == "pending"
    assert interaction.detection_confidence is None
    assert interaction.sign_codes == ["SIGN_DEMO_01"]
    assert interaction.alert_id == alert.id
    assert interaction.ruleset_version == "0.1.0"
    assert any(step["step"] == "decision" for step in interaction.decision_trace)
    actions = set(db.scalars(select(AuditEvent.action)))
    assert {"interaction.ask", "alert.create"} <= actions
    events = db.scalars(select(AlertEvent.type).where(AlertEvent.alert_id == alert.id)).all()
    assert events == ["created"]


def test_sign_codes_routine_is_answer_without_alert(client, world, contents, fake_ai, db):
    data = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_05"])
    assert data["outcome"] == "answer"
    assert data["severity"] == "routine"
    assert data["alert_id"] is None
    assert data["content"]["code"] == "MSG_DEMO_ROUTINE"
    interaction = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert interaction.review_status == "not_required"
    assert interaction.site_id == world.site_a.id  # site de l'auteur, sans bénéficiaire


def test_sign_codes_unknown_or_empty_is_fallback(client, world, contents, fake_ai):
    for codes in (["SIGN_INCONNU"], []):
        data = _ask_ok(client, world, module="reny", sign_codes=codes)
        assert data["outcome"] == "fallback"
        assert data["actions"] == ["transfer_counselor"]
        assert data["content"]["code"] == "MSG_DEMO_TRANSFER_COUNSELOR"
        assert data["alert_id"] is None


def test_pregnancy_context_from_active_pregnancy(client, world, contents, fake_ai):
    bid = create_beneficiary(client, world)
    # Sans grossesse enregistrée : contexte inconnu, la règle conditionnée reste active.
    data = _ask_ok(
        client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_03"]
    )
    assert data["outcome"] == "danger_sign"
    assert data["actions"] == ["refer_community_agent"]


# --- Forme texte : /classify -------------------------------------------------------


def test_text_classified_then_decided_by_rules(client, world, contents, fake_ai):
    fake_ai.sign_codes = ["SIGN_DEMO_03", "SIGN_DEMO_04"]
    fake_ai.confidence = 0.9
    data = _ask_ok(client, world, module="reny", text="texte fictif")
    assert fake_ai.calls == [("classify", "texte fictif", "reny")]
    assert data["outcome"] == "danger_sign" and data["severity"] == "urgent"
    assert data["transcript"] == "texte fictif"
    assert data["transcript_needs_review"] is False
    assert set(data["actions"]) == {"refer_csb", "refer_community_agent"}
    assert data["alert_id"] is not None


def test_text_low_confidence_is_fallback_without_alert(client, world, contents, fake_ai, db):
    fake_ai.confidence = 0.6  # sous le seuil de démo (0.8)
    data = _ask_ok(client, world, module="reny", text="texte fictif")
    assert data["outcome"] == "fallback"
    assert data["actions"] == ["transfer_counselor"]
    assert data["alert_id"] is None
    assert data["content"]["code"] == "MSG_DEMO_TRANSFER_COUNSELOR"
    interaction = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert "low_confidence" in interaction.fallback_reasons
    assert interaction.review_status == "pending"


def test_text_unknown_code_is_fallback(client, world, contents, fake_ai):
    fake_ai.sign_codes = ["SIGN_NON_REFERENCE"]
    data = _ask_ok(client, world, module="reny", text="texte fictif")
    assert data["outcome"] == "fallback"


@pytest.mark.parametrize("error", ["timeout", "http_503", "unavailable"])
def test_ai_failure_is_fallback(client, world, contents, fake_ai, db, error):
    fake_ai.classify_error = error
    data = _ask_ok(client, world, module="reny", text="texte fictif")
    assert data["outcome"] == "fallback"
    assert data["actions"] == ["transfer_counselor"]
    assert data["alert_id"] is None
    interaction = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert interaction.fallback_reasons[0] == f"ai_classify_{error}"


# --- Client HTTP réel avec transport simulé -----------------------------------------


def _http_client(handler):
    return HttpAiClient("http://ia.fictive", 0.5, transport=httpx.MockTransport(handler))


def test_http_client_success_timeout_and_5xx():
    def ok(request):
        if request.url.path == "/classify":
            return httpx.Response(
                200,
                json={"intent": "x", "sign_codes": ["SIGN_DEMO_01"], "confidence": 0.9,
                      "model": "m", "is_demo": True},
            )
        return httpx.Response(200, json={"text": "t", "confidence": None, "model": "m",
                                         "duration_s": 1.0})

    client = _http_client(ok)
    assert client.classify("t", "reny").sign_codes == ["SIGN_DEMO_01"]
    assert client.transcribe(b"a", "audio/wav", "mg").text == "t"

    def timeout(request):
        raise httpx.ReadTimeout("délai", request=request)

    def server_error(request):
        return httpx.Response(503, json={"detail": "indisponible"})

    def invalid(request):
        return httpx.Response(200, json={"intent": "x", "sign_codes": [], "confidence": 7})

    def refused(request):
        raise httpx.ConnectError("refusé", request=request)

    for handler, reason in (
        (timeout, "timeout"), (server_error, "http_503"), (invalid, "invalid_response"),
        (refused, "unavailable"),
    ):
        with pytest.raises(Exception) as exc:
            _http_client(handler).classify("t", "reny")
        assert exc.value.reason == reason


def test_ask_through_http_client_timeout_and_5xx(client, world, contents, app):
    def timeout(request):
        raise httpx.ReadTimeout("délai", request=request)

    def server_error(request):
        return httpx.Response(500)

    for handler in (timeout, server_error):
        app.dependency_overrides[get_ai_client] = lambda h=handler: _http_client(h)
        data = _ask_ok(client, world, module="reny", text="texte fictif")
        assert data["outcome"] == "fallback"
        bid = create_beneficiary(client, world, consents=("reny", "voice_processing"))
        resp = _ask_audio(client, world, beneficiary_id=bid)
        assert resp.status_code == 200 and resp.json()["outcome"] == "fallback"


# --- Forme audio : /transcribe puis /classify ------------------------------------


def test_audio_transcribed_classified_and_never_persisted(client, world, contents, fake_ai, db):
    bid = create_beneficiary(client, world, consents=("reny", "voice_processing"))
    resp = _ask_audio(client, world, beneficiary_id=bid)
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert fake_ai.calls[0] == ("transcribe", FAKE_AUDIO, "audio/wav", "mg")
    assert fake_ai.calls[1] == ("classify", "texte fictif transcrit", "reny")
    assert data["transcript"] == "texte fictif transcrit"
    # Confiance de transcription absente : transcription à revoir.
    assert data["transcript_needs_review"] is True
    assert data["outcome"] == "danger_sign"
    interaction = db.get(Interaction, uuid.UUID(data["interaction_id"]))
    assert interaction.input_kind == "audio"
    stored = [getattr(interaction, c.key) for c in Interaction.__table__.columns]
    assert FAKE_AUDIO not in stored
    assert not any(isinstance(value, bytes) for value in stored)


def test_audio_low_asr_confidence_lowers_detection(client, world, contents, fake_ai):
    fake_ai.asr_confidence = 0.5
    resp = _ask_audio(client, world)
    data = resp.json()
    assert data["transcript_needs_review"] is True
    assert data["outcome"] == "fallback"  # min(0.9, 0.5) sous le seuil


def test_audio_transcription_failure_is_fallback(client, world, contents, fake_ai):
    fake_ai.transcribe_error = "http_503"
    data = _ask_audio(client, world).json()
    assert data["outcome"] == "fallback" and data["transcript"] is None
    assert [c[0] for c in fake_ai.calls] == ["transcribe"]


def test_audio_size_limit_and_validation(client, world, settings, fake_ai):
    settings.ai_max_audio_bytes = 1024
    assert _ask_audio(client, world, audio=b"x" * 5000).status_code == 413
    assert fake_ai.calls == []
    settings.ai_max_audio_bytes = 5 * 1024 * 1024
    resp = client.post(
        "/interactions/ask", data={"module": "reny"}, files={"autre": ("a", b"x")},
        headers=world.headers("ac_a"),
    )
    assert resp.status_code == 422
    assert _ask_audio(client, world, module="inconnu").status_code == 422
    assert _ask_audio(client, world, audio=b"").status_code == 422


# --- Consentements, rôles, validation -------------------------------------------


def test_consent_required(client, world, contents, fake_ai):
    bid = create_beneficiary(client, world, consents=())
    resp = _ask(client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_01"])
    assert resp.status_code == 422 and "reny" in resp.json()["detail"]
    add_consent(client, world, bid, "tanora")
    assert _ask(
        client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_01"]
    ).status_code == 422
    assert _ask(
        client, world, module="tanora", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_06"]
    ).status_code == 200
    add_consent(client, world, bid, "reny")
    # Audio : voice_processing exigé en plus.
    resp = _ask_audio(client, world, beneficiary_id=bid)
    assert resp.status_code == 422 and "voice_processing" in resp.json()["detail"]
    assert fake_ai.calls == []


def test_consent_withdrawn_blocks(client, world, contents, fake_ai):
    bid = create_beneficiary(client, world, consents=())
    cid = add_consent(client, world, bid, "reny")
    client.post(f"/consents/{cid}/withdraw", headers=world.headers("ac_a"))
    resp = _ask(client, world, module="reny", beneficiary_id=str(bid), sign_codes=["SIGN_DEMO_01"])
    assert resp.status_code == 422


def test_roles_scope_and_body_validation(client, world, contents, fake_ai):
    for who in ("admin", "data", "tech"):
        assert _ask(client, world, who, module="reny", sign_codes=["SIGN_DEMO_01"]).status_code == (
            403
        )
    bid_b = create_beneficiary(client, world, who="ac_b")
    resp = _ask(client, world, module="reny", beneficiary_id=str(bid_b), sign_codes=[])
    assert resp.status_code == 404
    assert _ask(client, world, module="reny").status_code == 422
    assert _ask(client, world, module="reny", text="t", sign_codes=["X"]).status_code == 422
    assert _ask(client, world, module="autre", text="t").status_code == 422
    resp = client.post(
        "/interactions/ask", content=b"{", headers=world.headers("ac_a")
        | {"Content-Type": "application/json"},
    )
    assert resp.status_code == 422
    assert client.post("/interactions/ask", json={"module": "reny"}).status_code == 401


# --- Contenus, langue, démo, moteur absent ----------------------------------------


def test_content_not_published_is_fallback_but_alert_kept(client, world, fake_ai, db):
    # Aucun contenu importé.
    routine = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_05"])
    assert routine["outcome"] == "fallback" and routine["content"] is None
    assert "transfer_counselor" in routine["actions"]
    critical = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_01"])
    assert critical["outcome"] == "danger_sign" and critical["alert_id"] is not None
    assert critical["content"] is None
    assert "transfer_counselor" in critical["actions"]
    interaction = db.get(Interaction, uuid.UUID(critical["interaction_id"]))
    assert "content_not_published" in interaction.fallback_reasons


def test_language_preference_and_fallback(client, world, contents, fake_ai, db):
    db.add(
        ContentItem(
            code="MSG_DEMO_ROUTINE", module=ContentModule.RENY, language=ContentLanguage.MG,
            title="Lohateny fictif", body="Votoaty fictif.", version=2,
            status=ContentStatus.VALIDATED,
        )
    )
    db.commit()
    mg = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_05"])
    assert mg["content"]["title"] == "Lohateny fictif"
    fr = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_05"], language="fr")
    assert fr["content"]["status"] == "demo"


def test_without_rules_engine_always_fallback(client, world, app, fake_ai, caplog):
    from app.modules.interactions.rules_runtime import RulesRuntime

    app.state.rules = RulesRuntime(engine=None, catalog=None, error="refusé")
    with caplog.at_level(logging.ERROR, logger="fanilo.interactions"):
        data = _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_01"])
    assert data["outcome"] == "fallback" and data["alert_id"] is None
    assert data["actions"] == ["transfer_counselor"]
    assert any(r.message == "ask_without_rules_engine" for r in caplog.records)


def test_demo_rules_refused_without_demo_mode(world, settings, session_factory, make_site):
    """allow_demo_content=false : le jeu de démo est refusé, l'API démarre quand même."""
    from fastapi.testclient import TestClient

    from app.db.session import get_db
    from app.main import create_app

    strict = settings.model_copy(update={"allow_demo_content": False})
    app = create_app(strict, ai_client=FakeAi())

    def _get_db():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = _get_db
    assert app.state.rules.engine is None and app.state.rules.catalog is None
    with TestClient(app) as client:
        resp = client.post(
            "/interactions/ask", json={"module": "reny", "sign_codes": ["SIGN_DEMO_01"]},
            headers=world.headers("ac_a"),
        )
        data = resp.json()
        assert data["outcome"] == "fallback" and data["is_demo"] is False
        assert data["content"] is None


# --- Revue des interactions ---------------------------------------------------------


def test_review_queue_scope_and_review(client, world, contents, fake_ai, make_user):
    world.users["advisor_b"] = make_user(
        "conseil.b", Role.CLINICAL_ADVISOR, site_id=world.site_b.id
    )
    pending = _ask_ok(client, world, module="reny", sign_codes=["SIGN_INCONNU"])
    _ask_ok(client, world, module="reny", sign_codes=["SIGN_DEMO_05"])  # not_required
    other = _ask_ok(client, world, "ac_b", module="reny", sign_codes=["SIGN_INCONNU"])

    resp = client.get("/interactions?review_status=pending", headers=world.headers("advisor_a"))
    assert resp.status_code == 200
    ids = [i["id"] for i in resp.json()["items"]]
    assert ids == [pending["interaction_id"]]
    lead_ids = {
        i["id"] for i in client.get(
            "/interactions?review_status=pending", headers=world.headers("lead")
        ).json()["items"]
    }
    assert {pending["interaction_id"], other["interaction_id"]} <= lead_ids
    for who in ("ac_a", "head_a", "admin", "data"):
        assert client.get("/interactions", headers=world.headers(who)).status_code == 403

    path = f"/interactions/{pending['interaction_id']}/review"
    assert client.post(path, json={"note": "Rappel fictif"},
                       headers=world.headers("advisor_b")).status_code == 404
    reviewed = client.post(path, json={"note": "Orientation fictive documentée."},
                           headers=world.headers("advisor_a"))
    assert reviewed.status_code == 200
    body = reviewed.json()
    assert body["review_status"] == "reviewed"
    assert body["reviewed_by_user_id"] == str(world.users["advisor_a"].id)
    assert body["review_note"] == "Orientation fictive documentée."
    assert client.post(path, json={"note": "x"}, headers=world.headers("lead")).status_code == 409
    assert client.post(path, json={}, headers=world.headers("lead")).status_code == 422
