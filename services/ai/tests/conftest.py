"""Fixtures communes. Aucun test ne requiert l'extra [asr]."""

from __future__ import annotations

import io
import wave
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.asr.base import AsrBackend, TranscriptionResult
from app.audio import AudioInput, check_duration
from app.config import Settings
from app.main import create_app

SERVICE_ROOT = Path(__file__).resolve().parent.parent
RULES_SIGN_CATALOG = SERVICE_ROOT.parent / "rules" / "rulesets" / "demo" / "sign_codes.demo.yaml"


def make_wav(seconds: float, rate: int = 8_000) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(b"\x00\x00" * int(seconds * rate))
    return buffer.getvalue()


class FakeBackend(AsrBackend):
    """Backend factice : renvoie un texte fixe et enregistre les appels."""

    name = "fake"

    def __init__(self, text: str = "mandeha ra aho", duration_s: float = 1.0) -> None:
        self.text = text
        self.duration_s = duration_s
        self.calls: list[AudioInput] = []

    @property
    def available(self) -> bool:
        return True

    @property
    def model_id(self) -> str:
        return "fake-model"

    def transcribe(self, audio: AudioInput, max_seconds: float) -> TranscriptionResult:
        self.calls.append(audio)
        check_duration(self.duration_s, max_seconds)
        return TranscriptionResult(
            text=self.text, confidence=None, model="fake-model", duration_s=self.duration_s
        )


@pytest.fixture
def settings() -> Settings:
    return Settings(max_audio_bytes=32 * 1024, max_audio_seconds=2.0, _env_file=None)


@pytest.fixture
def make_client(settings: Settings) -> Iterator[Callable[..., TestClient]]:
    clients: list[TestClient] = []

    def factory(backend: AsrBackend | None = None, **overrides: object) -> TestClient:
        cfg = settings.model_copy(update=overrides) if overrides else settings
        client = TestClient(create_app(cfg, asr_backend=backend))
        client.__enter__()
        clients.append(client)
        return client

    yield factory
    for client in clients:
        client.__exit__(None, None, None)
