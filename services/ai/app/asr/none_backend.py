"""Backend par défaut : aucun ASR. `/transcribe` répond 503 avec un message explicite."""

from app.asr.base import AsrBackend, AsrUnavailableError, TranscriptionResult
from app.audio import AudioInput

NONE_BACKEND_MESSAGE = (
    "Aucun backend ASR n'est configuré (FANILO_AI_ASR_BACKEND=none). "
    "La transcription vocale est indisponible : utiliser la saisie texte ou les signes cochés, "
    "ou transférer au conseiller."
)


class NoneBackend(AsrBackend):
    name = "none"
    unavailable_reason = NONE_BACKEND_MESSAGE

    @property
    def available(self) -> bool:
        return False

    def transcribe(self, audio: AudioInput, max_seconds: float) -> TranscriptionResult:
        raise AsrUnavailableError(NONE_BACKEND_MESSAGE)
