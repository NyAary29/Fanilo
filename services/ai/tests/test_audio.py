import pytest

from app.audio import (
    AudioTooLargeError,
    UndecodableAudioError,
    UnsupportedMediaTypeError,
    check_mime,
    check_size,
    normalize_mime,
    wav_duration_seconds,
)
from app.config import AsrBackendName, Settings
from tests.conftest import make_wav


def test_normalize_mime() -> None:
    assert normalize_mime("Audio/OGG; codecs=opus") == "audio/ogg"
    assert normalize_mime(None) == ""


def test_check_mime() -> None:
    assert check_mime("audio/wav", ["audio/wav"]) == "audio/wav"
    with pytest.raises(UnsupportedMediaTypeError):
        check_mime(None, ["audio/wav"])


def test_check_size() -> None:
    check_size(b"x" * 10, 10)
    with pytest.raises(AudioTooLargeError):
        check_size(b"x" * 11, 10)
    with pytest.raises(UndecodableAudioError):
        check_size(b"", 10)


def test_wav_duration() -> None:
    assert wav_duration_seconds(make_wav(1.5, rate=8_000)) == pytest.approx(1.5)
    assert wav_duration_seconds(b"not a wav") is None


def test_settings_mime_list_from_env(monkeypatch) -> None:
    monkeypatch.setenv("FANILO_AI_ALLOWED_MIME_TYPES", "audio/wav, Audio/OGG")
    assert Settings(_env_file=None).allowed_mime_types == ["audio/wav", "audio/ogg"]


def test_default_models_are_resolved() -> None:
    assert Settings(_env_file=None).resolved_asr_model is None
    whisper = Settings(asr_backend=AsrBackendName.WHISPER, _env_file=None)
    assert whisper.resolved_asr_model == "waxal-benchmarking/whisper-small-waxal-mlg"
    custom = Settings(asr_backend=AsrBackendName.CTC, asr_model="org/model", _env_file=None)
    assert custom.resolved_asr_model == "org/model"


def test_factory_requires_asr_extra() -> None:
    # Sans l'extra [asr], demander un backend Transformers échoue explicitement.
    try:
        import transformers  # noqa: F401
    except ImportError:
        from app.asr.factory import build_asr_backend

        with pytest.raises(RuntimeError, match=r"\[asr\]"):
            build_asr_backend(Settings(asr_backend=AsrBackendName.WHISPER, _env_file=None))
    else:  # pragma: no cover - environnement avec l'extra
        pytest.skip("extra [asr] installé")
