"""Validation de l'audio reçu : type MIME, taille, durée.

Politique de données : l'audio n'est **jamais écrit sur disque de façon persistante**.
- Le corps de requête est plafonné par `BodySizeLimitMiddleware` avant tout parsing.
- Le seuil de débordement sur disque du parseur multipart de Starlette est relevé au-dessus
  de la limite (voir `app.main`), si bien que le fichier reçu reste en mémoire.
- Les backends décodent l'audio en mémoire (pipe ffmpeg stdin/stdout, pas de fichier).
- Rien dans ce service ne journalise l'audio ni la transcription.
"""

from __future__ import annotations

import io
import json
import wave
from dataclasses import dataclass

from starlette.exceptions import HTTPException
from starlette.types import ASGIApp, Message, Receive, Scope, Send

# Marge pour l'enveloppe multipart (en-têtes, champ `language`, délimiteurs).
MULTIPART_OVERHEAD_BYTES = 64 * 1024


class AudioValidationError(Exception):
    """Erreur de validation de l'audio, portée jusqu'à un code HTTP explicite."""

    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


class AudioTooLargeError(AudioValidationError):
    def __init__(self, detail: str) -> None:
        super().__init__(413, detail)


class AudioTooLongError(AudioValidationError):
    def __init__(self, duration_s: float, max_seconds: float) -> None:
        super().__init__(
            413,
            f"Audio trop long : {duration_s:.1f} s (maximum {max_seconds:.0f} s).",
        )


class UnsupportedMediaTypeError(AudioValidationError):
    def __init__(self, detail: str) -> None:
        super().__init__(415, detail)


class UndecodableAudioError(AudioValidationError):
    def __init__(self, detail: str = "Audio vide ou illisible.") -> None:
        super().__init__(422, detail)


def normalize_mime(content_type: str | None) -> str:
    """`"Audio/Ogg; codecs=opus"` -> `"audio/ogg"`."""
    if not content_type:
        return ""
    return content_type.split(";", 1)[0].strip().lower()


def check_mime(content_type: str | None, allowed: list[str]) -> str:
    mime = normalize_mime(content_type)
    if mime not in allowed:
        raise UnsupportedMediaTypeError(
            f"Type audio non accepté : '{mime or 'inconnu'}'. "
            f"Types acceptés : {', '.join(allowed)}."
        )
    return mime


def check_size(audio: bytes, max_bytes: int) -> None:
    if len(audio) == 0:
        raise UndecodableAudioError("Fichier audio vide.")
    if len(audio) > max_bytes:
        raise AudioTooLargeError(
            f"Audio trop volumineux : {len(audio)} octets (maximum {max_bytes} octets)."
        )


def check_duration(duration_s: float, max_seconds: float) -> None:
    if duration_s > max_seconds:
        raise AudioTooLongError(duration_s, max_seconds)


def wav_duration_seconds(audio: bytes) -> float | None:
    """Durée d'un WAV PCM lue dans l'en-tête, en mémoire. `None` si ce n'est pas un WAV lisible."""
    try:
        with wave.open(io.BytesIO(audio), "rb") as wav:
            rate = wav.getframerate()
            if rate <= 0:
                return None
            return wav.getnframes() / float(rate)
    except (wave.Error, EOFError):
        return None


@dataclass(frozen=True)
class AudioInput:
    """Audio validé, conservé uniquement en mémoire le temps de la requête."""

    data: bytes
    mime_type: str
    language: str


_BODY_TOO_LARGE_DETAIL = "Requête trop volumineuse : limite de taille audio dépassée."


class _BodyTooLarge(HTTPException):
    """HTTPException : FastAPI la relaie telle quelle (413) au lieu d'un 400 générique."""

    def __init__(self) -> None:
        super().__init__(status_code=413, detail=_BODY_TOO_LARGE_DETAIL)


class BodySizeLimitMiddleware:
    """Refuse (413) les corps de requête trop volumineux sur les chemins donnés.

    Contrôle `Content-Length` quand il est présent, puis compte les octets réellement reçus
    (cas du transfert « chunked »), afin de ne jamais bufferiser un corps arbitrairement gros.
    """

    def __init__(self, app: ASGIApp, max_body_bytes: int, paths: tuple[str, ...]) -> None:
        self.app = app
        self.max_body_bytes = max_body_bytes
        self.paths = paths

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["path"] not in self.paths:
            await self.app(scope, receive, send)
            return

        for name, value in scope.get("headers", []):
            if name == b"content-length":
                try:
                    declared = int(value)
                except ValueError:
                    declared = 0
                if declared > self.max_body_bytes:
                    await self._reject(send)
                    return

        received = 0
        response_started = False

        async def limited_receive() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_body_bytes:
                    raise _BodyTooLarge
            return message

        async def tracking_send(message: Message) -> None:
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except _BodyTooLarge:
            if not response_started:
                await self._reject(send)

    async def _reject(self, send: Send) -> None:
        body = json.dumps({"detail": _BODY_TOO_LARGE_DETAIL}).encode()
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})
