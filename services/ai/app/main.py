"""Service IA interne de FANILO (non exposé publiquement).

Ce service **propose** une transcription et une intention. Il ne décide jamais d'une
conduite médicale : c'est le moteur de règles (`services/rules`) qui décide, et l'API
bascule en `fallback` (transfert au conseiller) si ce service échoue ou est peu fiable.

Journalisation : ni l'audio ni le texte de l'usager ne sont journalisés.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from starlette.formparsers import MultiPartParser

from app.asr.base import AsrBackend, AsrUnavailableError
from app.audio import (
    MULTIPART_OVERHEAD_BYTES,
    AudioInput,
    AudioValidationError,
    BodySizeLimitMiddleware,
    check_duration,
    check_mime,
    check_size,
    wav_duration_seconds,
)
from app.config import NluBackendName, Settings, get_settings
from app.nlu.base import IntentClassifier
from app.nlu.lexicon import LexiconIntentClassifier
from app.schemas import ClassifyRequest, ClassifyResponse, HealthResponse, TranscribeResponse

logger = logging.getLogger("fanilo.ai")

LANGUAGE_PATTERN = r"^[a-z]{2,3}$"


def create_app(
    settings: Settings | None = None,
    *,
    asr_backend: AsrBackend | None = None,
    classifier: IntentClassifier | None = None,
) -> FastAPI:
    """Fabrique de l'application. Les tests injectent un backend ou un classifieur factice."""
    settings = settings or get_settings()
    max_body = settings.max_audio_bytes + MULTIPART_OVERHEAD_BYTES

    # Garder le fichier reçu en mémoire : Starlette déborde sur un fichier temporaire au-delà
    # de `spool_max_size` (1 Mio par défaut). La limite de corps garantit qu'on ne dépasse pas.
    MultiPartParser.spool_max_size = max(MultiPartParser.spool_max_size, max_body)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if asr_backend is None:
            from app.asr.factory import build_asr_backend

            app.state.asr_backend = build_asr_backend(settings)
        else:
            app.state.asr_backend = asr_backend
        if classifier is not None:
            app.state.classifier = classifier
        elif settings.nlu_backend is NluBackendName.OPENAI:
            from app.nlu.lexicon import load_lexicon
            from app.nlu.openai_classifier import OpenAiIntentClassifier
            from app.openai_client import build_openai_client

            app.state.classifier = OpenAiIntentClassifier(
                build_openai_client(settings),
                settings.openai_nlu_model,
                load_lexicon(settings.intent_lexicon_path),
            )
        else:
            app.state.classifier = LexiconIntentClassifier.from_path(settings.intent_lexicon_path)
        logger.info(
            "service IA prêt : asr=%s classifieur=%s",
            app.state.asr_backend.describe(),
            app.state.classifier.model_id,
        )
        yield

    app = FastAPI(
        title=settings.app_name,
        version=settings.version,
        lifespan=lifespan,
        docs_url="/docs" if settings.enable_docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.enable_docs else None,
    )
    app.add_middleware(BodySizeLimitMiddleware, max_body_bytes=max_body, paths=("/transcribe",))

    @app.get("/health", response_model=HealthResponse)
    async def health(request: Request) -> HealthResponse:
        return HealthResponse(
            status="ok",
            asr_backend=request.app.state.asr_backend.describe(),
            classifier=request.app.state.classifier.model_id,
        )

    @app.post(
        "/transcribe",
        response_model=TranscribeResponse,
        responses={
            413: {"description": "Audio trop volumineux ou trop long"},
            415: {"description": "Type audio non accepté"},
            422: {"description": "Audio vide ou illisible"},
            503: {"description": "Aucun backend ASR configuré ou ASR indisponible"},
        },
    )
    async def transcribe(
        request: Request,
        audio: Annotated[UploadFile, File(description="Fichier audio")],
        language: Annotated[str, Form(pattern=LANGUAGE_PATTERN)] = "mg",
    ) -> TranscribeResponse:
        backend: AsrBackend = request.app.state.asr_backend
        if not backend.available:
            await audio.close()
            raise HTTPException(status_code=503, detail=backend.unavailable_reason)
        try:
            mime = check_mime(audio.content_type, settings.allowed_mime_types)
            data = await audio.read(settings.max_audio_bytes + 1)
            check_size(data, settings.max_audio_bytes)
            wav_duration = wav_duration_seconds(data)
            if wav_duration is not None:
                check_duration(wav_duration, settings.max_audio_seconds)
            result = await run_in_threadpool(
                backend.transcribe,
                AudioInput(data=data, mime_type=mime, language=language),
                settings.max_audio_seconds,
            )
        except AudioValidationError as exc:
            raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
        except AsrUnavailableError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        finally:
            await audio.close()
        return TranscribeResponse(
            text=result.text,
            confidence=result.confidence,
            model=result.model,
            duration_s=result.duration_s,
        )

    @app.post("/classify", response_model=ClassifyResponse)
    async def classify(body: ClassifyRequest, request: Request) -> ClassifyResponse:
        if len(body.text) > settings.max_text_chars:
            raise HTTPException(
                status_code=413,
                detail=f"Texte trop long (maximum {settings.max_text_chars} caractères).",
            )
        clf: IntentClassifier = request.app.state.classifier
        result = clf.classify(body.text, body.module)
        return ClassifyResponse(
            intent=result.intent,
            sign_codes=result.sign_codes,
            confidence=result.confidence,
            model=result.model,
            is_demo=result.is_demo,
        )

    return app


app = create_app()
