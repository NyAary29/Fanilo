"""Transcription par l'API OpenAI (`gpt-4o-transcribe` par défaut), avec secours local.

L'audio est envoyé à OpenAI (hors de Madagascar) : l'information présentée à
l'utilisatrice doit le dire. Il n'est ni écrit sur disque ni journalisé ici.
En cas d'échec (réseau, quota, clé), le backend local (Whisper malgache) prend le relais
s'il est configuré ; sinon l'API FANILO répond en transfert au conseiller.
"""

from __future__ import annotations

import logging

from app.asr.base import AsrBackend, AsrUnavailableError, TranscriptionResult
from app.asr.guards import foreign_script, is_near_silent, looks_hallucinated
from app.audio import AudioInput
from app.openai_client import OpenAiClient, OpenAiError

logger = logging.getLogger("fanilo.ai.asr.openai")

_EXTENSIONS = {
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/vnd.wave": "wav",
    "audio/ogg": "ogg",
    "audio/opus": "ogg",
    "audio/webm": "webm",
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/x-m4a": "m4a",
    "audio/flac": "flac",
}


class OpenAiAsrBackend(AsrBackend):
    name = "openai"

    def __init__(self, client: OpenAiClient, model: str, fallback: AsrBackend | None = None):
        self._client = client
        self._model = model
        self._fallback = fallback

    @property
    def available(self) -> bool:
        return True

    @property
    def model_id(self) -> str:
        suffix = f"+secours:{self._fallback.describe()}" if self._fallback else ""
        return f"{self._model}{suffix}"

    def _silent(self, audio: AudioInput) -> bool:
        """Contrôle local du silence avant tout envoi (si le décodeur local est disponible)."""
        decode = getattr(self._fallback, "_decode", None)
        if decode is None:
            return False
        try:
            return is_near_silent(decode(audio))
        except Exception:  # noqa: BLE001 - audio illisible : OpenAI tranchera
            return False

    def transcribe(self, audio: AudioInput, max_seconds: float) -> TranscriptionResult:
        if self._silent(audio):
            return TranscriptionResult(text="", confidence=None, model=self._model, duration_s=0)
        content_type = audio.mime_type.split(";")[0].strip().lower()
        ext = _EXTENSIONS.get(content_type, "wav")
        try:
            text = self._client.transcribe(
                audio=audio.data,
                filename=f"question.{ext}",
                content_type=content_type,
                model=self._model,
                language=audio.language,
            ).strip()
        except OpenAiError as exc:
            logger.warning("openai_asr_failed reason=%s", exc)
            if self._fallback is not None and self._fallback.available:
                return self._fallback.transcribe(audio, max_seconds)
            raise AsrUnavailableError(f"Transcription externe indisponible ({exc}).") from exc
        if looks_hallucinated(text) or foreign_script(text):
            text = ""
        # Durée non mesurée côté FANILO (l'audio n'est pas décodé localement).
        return TranscriptionResult(text=text, confidence=None, model=self._model, duration_s=0.0)
