"""Construction du backend ASR à partir de la configuration."""

from __future__ import annotations

from app.asr.base import AsrBackend
from app.asr.none_backend import NoneBackend
from app.config import AsrBackendName, Settings


def build_asr_backend(settings: Settings) -> AsrBackend:
    """Échoue explicitement si un backend Transformers est demandé sans l'extra [asr]."""
    if settings.asr_backend is AsrBackendName.NONE:
        return NoneBackend()
    if settings.asr_backend is AsrBackendName.OPENAI:
        from app.asr.openai_backend import OpenAiAsrBackend
        from app.openai_client import build_openai_client

        fallback = None
        if settings.openai_asr_fallback not in (AsrBackendName.NONE, AsrBackendName.OPENAI):
            try:
                fallback = build_asr_backend(
                    settings.model_copy(update={"asr_backend": settings.openai_asr_fallback})
                )
            except RuntimeError:  # extra [asr] absent : pas de secours local
                fallback = None
        return OpenAiAsrBackend(
            build_openai_client(settings), settings.openai_asr_model, fallback=fallback
        )

    # Import local : le module ne tire torch/transformers qu'à l'instanciation.
    from app.asr.transformers_backend import (
        CtcBackend,
        TransformersWhisperBackend,
    )

    backend_cls = (
        TransformersWhisperBackend if settings.asr_backend is AsrBackendName.WHISPER else CtcBackend
    )
    model = settings.resolved_asr_model
    if model is None:  # pragma: no cover - impossible pour un backend autre que NONE
        raise RuntimeError("Aucun modèle ASR résolu.")
    return backend_cls(
        model,
        revision=settings.asr_model_revision,
        device=settings.asr_device,
        sampling_rate=settings.asr_sampling_rate,
    )
