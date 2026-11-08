"""Backends ASR Hugging Face `transformers` (extra optionnel `[asr]`).

Ce module n'importe **ni torch ni transformers au chargement** : les imports ont lieu dans
le constructeur, si bien que le service démarre et se teste sans l'extra `[asr]`.

Décodage : l'audio est passé à ffmpeg par stdin et relu sur stdout
(`transformers.pipelines.audio_utils.ffmpeg_read`), sans aucun fichier sur disque.
"""

from __future__ import annotations

import shutil
import threading
from typing import Any

from app.asr.base import AsrBackend, AsrUnavailableError, TranscriptionResult
from app.audio import AudioInput, UndecodableAudioError, check_duration

ASR_EXTRA_MISSING = (
    "Le backend ASR demandé requiert l'extra optionnel [asr] (torch, transformers) : "
    "`uv sync --extra asr`."
)
FFMPEG_MISSING = "Le binaire ffmpeg est introuvable : il est requis pour décoder l'audio."

# Whisper traite des fenêtres de 30 s ; au-delà, le pipeline découpe l'audio.
_WHISPER_WINDOW_S = 30.0


class _TransformersAsrBackend(AsrBackend):
    """Socle commun : pipeline `automatic-speech-recognition` de transformers."""

    def __init__(
        self,
        model: str,
        *,
        revision: str | None = None,
        device: str = "cpu",
        sampling_rate: int = 16_000,
    ) -> None:
        try:
            from transformers import pipeline  # import paresseux voulu
            from transformers.pipelines.audio_utils import ffmpeg_read
        except ImportError as exc:
            raise RuntimeError(ASR_EXTRA_MISSING) from exc
        if shutil.which("ffmpeg") is None:  # pragma: no cover - dépend de l'image
            raise RuntimeError(FFMPEG_MISSING)

        self._model = model
        self._sampling_rate = sampling_rate
        self._ffmpeg_read = ffmpeg_read
        self._pipe: Any = pipeline(
            "automatic-speech-recognition",
            model=model,
            revision=revision,
            device=device,
        )
        # Les pipelines ne sont pas garantis thread-safe : une inférence à la fois.
        self._lock = threading.Lock()

    @property
    def available(self) -> bool:
        return True

    @property
    def model_id(self) -> str:
        return self._model

    def _decode(self, audio: AudioInput) -> Any:
        try:
            samples = self._ffmpeg_read(audio.data, self._sampling_rate)
        except ValueError as exc:
            raise UndecodableAudioError(f"Audio illisible : {exc}") from exc
        if samples is None or len(samples) == 0:
            raise UndecodableAudioError()
        return samples

    def _call_kwargs(self, audio: AudioInput, duration_s: float) -> dict[str, Any]:
        return {}

    def transcribe(self, audio: AudioInput, max_seconds: float) -> TranscriptionResult:
        samples = self._decode(audio)
        duration_s = len(samples) / float(self._sampling_rate)
        check_duration(duration_s, max_seconds)
        try:
            with self._lock:
                output = self._pipe(
                    {"raw": samples, "sampling_rate": self._sampling_rate},
                    **self._call_kwargs(audio, duration_s),
                )
        except Exception as exc:  # erreur d'inférence : l'API basculera en fallback
            raise AsrUnavailableError(f"Échec de l'inférence ASR ({type(exc).__name__}).") from exc
        text = str(output.get("text", "")).strip() if isinstance(output, dict) else ""
        # Le pipeline ne fournit pas de confiance calibrée : on renvoie None plutôt qu'un
        # chiffre trompeur. L'API traite alors la transcription comme « à revoir ».
        return TranscriptionResult(
            text=text, confidence=None, model=self._model, duration_s=round(duration_s, 3)
        )


class TransformersWhisperBackend(_TransformersAsrBackend):
    """Modèles Whisper (encodeur-décodeur). Whisper sans affinage est inutilisable en malgache
    (voir docs/ia/benchmark-asr-malgache.md) : n'utiliser qu'un modèle affiné."""

    name = "transformers-whisper"

    def _call_kwargs(self, audio: AudioInput, duration_s: float) -> dict[str, Any]:
        kwargs: dict[str, Any] = {
            "generate_kwargs": {"language": audio.language, "task": "transcribe"}
        }
        if duration_s > _WHISPER_WINDOW_S:
            kwargs["chunk_length_s"] = _WHISPER_WINDOW_S
        return kwargs


class CtcBackend(_TransformersAsrBackend):
    """Modèles CTC (wav2vec2, XLS-R, w2v-BERT 2.0...). Décodage glouton, sans modèle de langue."""

    name = "transformers-ctc"
