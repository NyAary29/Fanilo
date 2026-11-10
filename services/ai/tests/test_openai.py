"""Backends OpenAI (transcription, classification) avec un faux serveur HTTP : requêtes
envoyées, sorties contraintes, garde-fous et secours en cas d'échec."""

import json

import httpx
import pytest

from app.asr.base import AsrBackend, AsrUnavailableError, TranscriptionResult
from app.asr.openai_backend import OpenAiAsrBackend
from app.audio import AudioInput
from app.config import DEFAULT_LEXICON_PATH, Settings
from app.nlu.lexicon import load_lexicon
from app.nlu.openai_classifier import LLM_CONFIDENCE, OpenAiIntentClassifier
from app.openai_client import OpenAiClient, build_openai_client

AUDIO = AudioInput(data=b"RIFF" + b"\x00" * 100, mime_type="audio/x-m4a", language="mg")


def _client(handler) -> OpenAiClient:
    return OpenAiClient("sk-test", transport=httpx.MockTransport(handler))


def _chat(payload: dict):
    def handler(request: httpx.Request) -> httpx.Response:
        handler.body = json.loads(request.content)
        return httpx.Response(
            200, json={"choices": [{"message": {"content": json.dumps(payload)}}]}
        )

    return handler


class _Local(AsrBackend):
    name = "local"

    @property
    def available(self) -> bool:
        return True

    def transcribe(self, audio, max_seconds):
        return TranscriptionResult(text="secours local", confidence=None, model="m", duration_s=1)


def test_transcription_request_and_result():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["auth"] = request.headers["authorization"]
        seen["body"] = request.content
        return httpx.Response(200, json={"text": "  rahoviana ny fizahana vohoka  "})

    backend = OpenAiAsrBackend(_client(handler), "gpt-4o-transcribe")
    result = backend.transcribe(AUDIO, 60)
    assert result.text == "rahoviana ny fizahana vohoka"
    assert seen["auth"] == "Bearer sk-test"
    assert b'name="language"' in seen["body"] and b"mg" in seen["body"]
    assert b'filename="question.m4a"' in seen["body"]


def test_transcription_hallucination_is_blanked():
    loop = "izay miendrika efajoro eny " * 6
    backend = OpenAiAsrBackend(_client(lambda r: httpx.Response(200, json={"text": loop})), "m")
    assert backend.transcribe(AUDIO, 60).text == ""


def test_transcription_falls_back_then_fails_cleanly():
    down = _client(lambda r: httpx.Response(500))
    assert OpenAiAsrBackend(down, "m", fallback=_Local()).transcribe(AUDIO, 60).text == (
        "secours local"
    )
    with pytest.raises(AsrUnavailableError):
        OpenAiAsrBackend(down, "m").transcribe(AUDIO, 60)


def test_classifier_is_constrained_and_never_reaches_alert_threshold():
    lexicon = load_lexicon(DEFAULT_LEXICON_PATH)
    handler = _chat({"intent": "ask_nutrition", "sign_codes": ["SIGN_DEMO_01", "BIDON"]})
    clf = OpenAiIntentClassifier(_client(handler), "gpt-4o-mini", lexicon)
    result = clf.classify("mandeha ra aho", "reny")
    assert result.intent == "report_danger_sign"
    assert result.sign_codes == ["SIGN_DEMO_01"]  # code inventé écarté
    assert result.confidence == LLM_CONFIDENCE < 0.8
    schema = handler.body["response_format"]["json_schema"]
    assert schema["strict"] is True
    assert "ask_menstruation" not in schema["schema"]["properties"]["intent"]["enum"]  # tanora


def test_classifier_intent_and_fallback_to_lexicon():
    lexicon = load_lexicon(DEFAULT_LEXICON_PATH)
    clf = OpenAiIntentClassifier(
        _client(_chat({"intent": "ask_anc_schedule", "sign_codes": []})), "m", lexicon
    )
    assert clf.classify("rahoviana ny fizahana", "reny").intent == "ask_anc_schedule"
    broken = OpenAiIntentClassifier(_client(lambda r: httpx.Response(429)), "m", lexicon)
    assert broken.classify("sakafo", "reny").model.startswith("lexicon-baseline")


def test_missing_key_is_explicit():
    with pytest.raises(RuntimeError, match="FANILO_AI_OPENAI_API_KEY"):
        build_openai_client(Settings(_env_file=None))


def test_language_rejected_is_retried_without_language():
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(b'name="language"' in request.content)
        if calls[-1]:
            return httpx.Response(
                400, json={"error": {"code": "invalid_value", "param": "language"}}
            )
        return httpx.Response(200, json={"text": "salama"})

    backend = OpenAiAsrBackend(_client(handler), "gpt-4o-transcribe")
    assert backend.transcribe(AUDIO, 60).text == "salama"
    assert backend.transcribe(AUDIO, 60).text == "salama"
    assert calls == [True, False, False]  # la langue n'est plus envoyée ensuite
