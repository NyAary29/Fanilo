"""Client du service IA interne (``services/ai``, contrat section 11).

Le service **propose** une transcription et des codes de signes ; il ne décide
jamais. Toute indisponibilité, tout délai dépassé, toute réponse invalide ou
toute erreur HTTP lève :class:`AiServiceError` : l'appelant répond alors en
fallback (transfert au conseiller).

L'audio est transmis **en mémoire** (jamais écrit sur disque) ; ni l'audio ni
le texte ne sont journalisés.
"""

from dataclasses import dataclass
from typing import Any, Protocol

import httpx
from fastapi import Request
from pydantic import BaseModel, Field, ValidationError


class AiServiceError(Exception):
    """Échec d'appel au service IA. ``reason`` est un code court, sans donnée."""

    def __init__(self, reason: str) -> None:
        self.reason = reason
        super().__init__(reason)


class Transcription(BaseModel):
    text: str
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    model: str = ""


class Classification(BaseModel):
    intent: str
    sign_codes: list[str] = Field(max_length=50)
    confidence: float = Field(ge=0.0, le=1.0)
    model: str = ""
    is_demo: bool = True


class AiClient(Protocol):
    def transcribe(self, audio: bytes, content_type: str, language: str) -> Transcription: ...

    def classify(self, text: str, module: str) -> Classification: ...


@dataclass
class HttpAiClient:
    """Client HTTP synchrone (appelé depuis un thread de travail)."""

    base_url: str
    timeout_seconds: float
    # Transport injectable (tests : httpx.MockTransport).
    transport: httpx.BaseTransport | None = None

    def _post(self, path: str, **kwargs: Any) -> Any:
        try:
            with httpx.Client(
                base_url=self.base_url, timeout=self.timeout_seconds, transport=self.transport
            ) as client:
                response = client.post(path, **kwargs)
        except httpx.TimeoutException:
            raise AiServiceError("timeout") from None
        except httpx.HTTPError:
            raise AiServiceError("unavailable") from None
        if response.status_code != 200:
            raise AiServiceError(f"http_{response.status_code}")
        try:
            return response.json()
        except ValueError:
            raise AiServiceError("invalid_response") from None

    def transcribe(self, audio: bytes, content_type: str, language: str) -> Transcription:
        payload = self._post(
            "/transcribe",
            files={"audio": ("audio", audio, content_type)},
            data={"language": language},
        )
        try:
            return Transcription.model_validate(payload)
        except ValidationError:
            raise AiServiceError("invalid_response") from None

    def classify(self, text: str, module: str) -> Classification:
        payload = self._post("/classify", json={"text": text, "module": module})
        try:
            return Classification.model_validate(payload)
        except ValidationError:
            raise AiServiceError("invalid_response") from None


def get_ai_client(request: Request) -> AiClient:
    """Dépendance FastAPI (remplacée par un client factice dans les tests)."""
    return request.app.state.ai_client
