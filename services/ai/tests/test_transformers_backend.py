"""Logique des backends Transformers, testée avec un faux module `transformers` injecté :
aucune dépendance de l'extra [asr] n'est requise."""

import sys
import types

import pytest

from app.asr.base import AsrUnavailableError
from app.audio import AudioInput, AudioTooLongError, UndecodableAudioError


class FakePipe:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.calls: list[tuple[dict, dict]] = []

    def __call__(self, inputs: dict, **kwargs: object) -> dict:
        if self.fail:
            raise RuntimeError("boom")
        self.calls.append((inputs, kwargs))
        return {"text": "  misy ra  "}


@pytest.fixture
def fake_transformers(monkeypatch):
    state = {"pipe": FakePipe(), "pipeline_args": None}

    def pipeline(task, **kwargs):
        state["pipeline_args"] = (task, kwargs)
        return state["pipe"]

    def ffmpeg_read(data: bytes, sampling_rate: int):
        if data == b"bad":
            raise ValueError("ffmpeg error")
        # 1 octet = 1 échantillon, pour piloter la durée depuis le test.
        return [0.0] * len(data)

    transformers = types.ModuleType("transformers")
    transformers.pipeline = pipeline
    pipelines = types.ModuleType("transformers.pipelines")
    audio_utils = types.ModuleType("transformers.pipelines.audio_utils")
    audio_utils.ffmpeg_read = ffmpeg_read
    monkeypatch.setitem(sys.modules, "transformers", transformers)
    monkeypatch.setitem(sys.modules, "transformers.pipelines", pipelines)
    monkeypatch.setitem(sys.modules, "transformers.pipelines.audio_utils", audio_utils)
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/ffmpeg")
    return state


def _audio(n: int, data: bytes | None = None) -> AudioInput:
    return AudioInput(
        data=data if data is not None else b"\x00" * n, mime_type="audio/ogg", language="mg"
    )


def test_whisper_backend(fake_transformers) -> None:
    from app.asr.transformers_backend import TransformersWhisperBackend

    backend = TransformersWhisperBackend("org/whisper", revision="abc", sampling_rate=100)
    assert fake_transformers["pipeline_args"] == (
        "automatic-speech-recognition",
        {"model": "org/whisper", "revision": "abc", "device": "cpu"},
    )
    result = backend.transcribe(_audio(250), max_seconds=60)
    assert result.text == "misy ra"
    assert result.confidence is None
    assert result.duration_s == 2.5
    assert backend.describe() == "transformers-whisper:org/whisper"
    inputs, kwargs = fake_transformers["pipe"].calls[0]
    assert inputs["sampling_rate"] == 100
    assert kwargs == {"generate_kwargs": {"language": "mg", "task": "transcribe"}}


def test_whisper_long_audio_is_chunked(fake_transformers) -> None:
    from app.asr.transformers_backend import TransformersWhisperBackend

    backend = TransformersWhisperBackend("m", sampling_rate=10)
    backend.transcribe(_audio(400), max_seconds=60)  # 40 s
    assert fake_transformers["pipe"].calls[0][1]["chunk_length_s"] == 30.0


def test_ctc_backend_and_limits(fake_transformers) -> None:
    from app.asr.transformers_backend import CtcBackend

    backend = CtcBackend("org/ctc", sampling_rate=10)
    backend.transcribe(_audio(10), max_seconds=60)
    assert fake_transformers["pipe"].calls[0][1] == {}
    with pytest.raises(AudioTooLongError):
        backend.transcribe(_audio(1000), max_seconds=60)  # 100 s
    with pytest.raises(UndecodableAudioError):
        backend.transcribe(_audio(0, b"bad"), max_seconds=60)
    with pytest.raises(UndecodableAudioError):
        backend.transcribe(_audio(0, b""), max_seconds=60)


def test_inference_failure_maps_to_unavailable(fake_transformers) -> None:
    from app.asr.transformers_backend import CtcBackend

    fake_transformers["pipe"] = FakePipe(fail=True)
    backend = CtcBackend("m", sampling_rate=10)
    with pytest.raises(AsrUnavailableError):
        backend.transcribe(_audio(10), max_seconds=60)
