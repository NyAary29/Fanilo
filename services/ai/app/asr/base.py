"""Interface des backends ASR.

Un backend **propose** une transcription. Il ne prend aucune décision médicale : la
transcription est ensuite classée, puis évaluée par le moteur de règles déterministe.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass

from app.audio import AudioInput


@dataclass(frozen=True)
class TranscriptionResult:
    text: str
    # Confiance du modèle si elle est disponible et calibrée ; sinon None (jamais inventée).
    confidence: float | None
    model: str
    duration_s: float


class AsrUnavailableError(Exception):
    """Aucun backend ASR utilisable : l'API doit répondre `fallback`."""


class AsrBackend(ABC):
    #: Identifiant court exposé par /health (ex. "none", "transformers-whisper").
    name: str = "abstract"
    #: Message renvoyé (503) quand `available` est faux.
    unavailable_reason: str = "Le service de transcription est indisponible."

    @property
    @abstractmethod
    def available(self) -> bool:
        """Vrai si le backend peut transcrire."""

    @property
    def model_id(self) -> str | None:
        return None

    def describe(self) -> str:
        return self.name if self.model_id is None else f"{self.name}:{self.model_id}"

    @abstractmethod
    def transcribe(self, audio: AudioInput, max_seconds: float) -> TranscriptionResult:
        """Transcrit l'audio (bloquant). Lève `AudioValidationError` ou `AsrUnavailableError`."""
