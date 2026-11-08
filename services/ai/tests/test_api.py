import sys

from app.asr.none_backend import NONE_BACKEND_MESSAGE
from tests.conftest import FakeBackend, make_wav


def _post_audio(client, data: bytes, mime: str = "audio/wav", **form: str):
    return client.post("/transcribe", files={"audio": ("a.wav", data, mime)}, data=form or None)


# --- /health -------------------------------------------------------------------------


def test_health_default_none_backend(make_client) -> None:
    response = make_client().get("/health")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "asr_backend": "none",
        "classifier": "lexicon-baseline:fanilo-intents-demo@0.1.0",
    }


def test_health_with_fake_backend(make_client) -> None:
    body = make_client(FakeBackend()).get("/health").json()
    assert body["asr_backend"] == "fake:fake-model"


def test_asr_extra_not_imported_by_default(make_client) -> None:
    make_client().get("/health")
    assert "transformers" not in sys.modules
    assert "torch" not in sys.modules


# --- /transcribe ---------------------------------------------------------------------


def test_transcribe_none_backend_returns_503(make_client) -> None:
    response = _post_audio(make_client(), make_wav(0.5))
    assert response.status_code == 503
    assert response.json()["detail"] == NONE_BACKEND_MESSAGE
    assert "FANILO_AI_ASR_BACKEND" in NONE_BACKEND_MESSAGE


def test_transcribe_fake_backend(make_client) -> None:
    backend = FakeBackend(text="mandeha ra aho", duration_s=1.0)
    response = _post_audio(make_client(backend), make_wav(1.0), language="mg")
    assert response.status_code == 200
    assert response.json() == {
        "text": "mandeha ra aho",
        "confidence": None,
        "model": "fake-model",
        "duration_s": 1.0,
    }
    assert backend.calls[0].language == "mg"
    assert backend.calls[0].mime_type == "audio/wav"


def test_transcribe_default_language_is_mg(make_client) -> None:
    backend = FakeBackend()
    assert _post_audio(make_client(backend), make_wav(0.5)).status_code == 200
    assert backend.calls[0].language == "mg"


def test_transcribe_mime_parameters_are_ignored(make_client) -> None:
    backend = FakeBackend()
    response = _post_audio(make_client(backend), b"OggS fake", "audio/ogg; codecs=opus")
    assert response.status_code == 200
    assert backend.calls[0].mime_type == "audio/ogg"


def test_transcribe_rejects_unsupported_mime(make_client) -> None:
    backend = FakeBackend()
    response = _post_audio(make_client(backend), b"hello", "text/plain")
    assert response.status_code == 415
    assert backend.calls == []


def test_transcribe_rejects_invalid_language(make_client) -> None:
    response = _post_audio(make_client(FakeBackend()), make_wav(0.5), language="Malagasy!")
    assert response.status_code == 422


def test_transcribe_rejects_empty_audio(make_client) -> None:
    response = _post_audio(make_client(FakeBackend()), b"")
    assert response.status_code == 422


def test_transcribe_rejects_oversized_audio_after_read(make_client, settings) -> None:
    # Juste au-dessus de la limite audio mais sous la limite de corps (marge multipart) :
    # c'est le contrôle applicatif qui refuse.
    backend = FakeBackend()
    data = b"\x00" * (settings.max_audio_bytes + 10)
    response = _post_audio(make_client(backend), data, "audio/ogg")
    assert response.status_code == 413
    assert "trop volumineux" in response.json()["detail"]
    assert backend.calls == []


def test_transcribe_rejects_oversized_body_via_content_length(make_client, settings) -> None:
    backend = FakeBackend()
    data = b"\x00" * (settings.max_audio_bytes + 200 * 1024)
    response = _post_audio(make_client(backend), data, "audio/ogg")
    assert response.status_code == 413
    assert backend.calls == []


def test_transcribe_rejects_oversized_chunked_body(make_client, settings) -> None:
    backend = FakeBackend()
    client = make_client(backend)
    boundary = "xyz"
    head = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="audio"; filename="a.ogg"\r\n'
        "Content-Type: audio/ogg\r\n\r\n"
    ).encode()

    def chunks():
        yield head
        for _ in range(20):
            yield b"\x00" * (32 * 1024)
        yield f"\r\n--{boundary}--\r\n".encode()

    response = client.post(
        "/transcribe",
        content=chunks(),
        headers={"content-type": f"multipart/form-data; boundary={boundary}"},
    )
    assert response.status_code == 413
    assert backend.calls == []


def test_transcribe_rejects_too_long_wav(make_client, settings) -> None:
    backend = FakeBackend()
    # 10 s à 1 kHz : WAV de 20 Ko, sous la limite de taille mais au-delà de 2 s.
    long_wav = make_wav(seconds=10, rate=1_000)
    response = _post_audio(make_client(backend, max_audio_bytes=64 * 1024), long_wav)
    assert response.status_code == 413
    assert "trop long" in response.json()["detail"]
    assert backend.calls == []


def test_transcribe_backend_duration_limit(make_client) -> None:
    # Format non WAV : la durée n'est connue qu'après décodage par le backend.
    backend = FakeBackend(duration_s=30.0)
    response = _post_audio(make_client(backend), b"OggS fake", "audio/ogg")
    assert response.status_code == 413


# --- /classify -----------------------------------------------------------------------


def test_classify_contract(make_client) -> None:
    response = make_client().post("/classify", json={"text": "Mandeha ra aho", "module": "reny"})
    assert response.status_code == 200
    assert response.json() == {
        "intent": "report_danger_sign",
        "sign_codes": ["SIGN_DEMO_01"],
        "confidence": 0.6,
        "model": "lexicon-baseline:fanilo-intents-demo@0.1.0",
        "is_demo": True,
    }


def test_classify_out_of_scope(make_client) -> None:
    body = make_client().post("/classify", json={"text": "Salama", "module": "tanora"}).json()
    assert body["intent"] == "out_of_scope"
    assert body["confidence"] == 0.1
    assert body["sign_codes"] == []


def test_classify_rejects_unknown_module(make_client) -> None:
    response = make_client().post("/classify", json={"text": "x", "module": "autre"})
    assert response.status_code == 422


def test_classify_rejects_too_long_text(make_client) -> None:
    client = make_client(max_text_chars=10)
    response = client.post("/classify", json={"text": "a" * 11, "module": "reny"})
    assert response.status_code == 413


def test_upload_is_kept_in_memory(make_client, settings) -> None:
    from starlette.formparsers import MultiPartParser

    from app.audio import MULTIPART_OVERHEAD_BYTES

    make_client()
    assert MultiPartParser.spool_max_size >= settings.max_audio_bytes + MULTIPART_OVERHEAD_BYTES


def test_docs_disabled_by_default(make_client) -> None:
    assert make_client().get("/docs").status_code == 404
