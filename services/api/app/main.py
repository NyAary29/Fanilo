from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm.exc import StaleDataError
from starlette.formparsers import MultiPartParser

from app.api import health
from app.core.config import Settings, get_settings
from app.core.errors import DomainError, VersionConflictError
from app.core.logging import RequestLoggingMiddleware, configure_logging
from app.modules.alerts.router import router as alerts_router
from app.modules.audit.router import router as audit_router
from app.modules.auth.router import router as auth_router
from app.modules.beneficiaries.router import router as beneficiaries_router
from app.modules.contents.router import router as contents_router
from app.modules.dashboard.router import router as dashboard_router
from app.modules.interactions.ai_client import AiClient, HttpAiClient
from app.modules.interactions.router import MULTIPART_OVERHEAD_BYTES
from app.modules.interactions.router import router as interactions_router
from app.modules.interactions.rules_runtime import load_rules_runtime
from app.modules.reference.router import router as reference_router
from app.modules.referrals.router import router as referrals_router
from app.modules.reny.router import router as reny_router
from app.modules.sites.router import router as sites_router
from app.modules.sync.router import router as sync_router
from app.modules.users.router import router as users_router


async def _domain_error_handler(_request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, DomainError)  # noqa: S101
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


async def _stale_data_handler(_request: Request, _exc: Exception) -> JSONResponse:
    """Modification concurrente détectée au flush (verrou optimiste)."""
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={"detail": VersionConflictError.default_detail},
    )


def create_app(settings: Settings | None = None, *, ai_client: AiClient | None = None) -> FastAPI:
    """Fabrique de l'application. Les tests injectent un client IA factice."""
    settings = settings or get_settings()
    configure_logging(settings.log_level, settings.log_format)

    app = FastAPI(
        title=settings.app_name,
        version=settings.version,
        description=(
            "API de FANILO. FANILO ne pose aucun diagnostic et ne se substitue "
            "jamais à un professionnel de santé."
        ),
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
    )
    app.dependency_overrides[get_settings] = lambda: settings
    # Moteur de règles chargé une seule fois ; None => toute question en fallback.
    app.state.rules = load_rules_runtime(settings)
    app.state.ai_client = ai_client or HttpAiClient(
        settings.ai_service_url, settings.ai_timeout_seconds
    )
    # L'audio reçu reste en mémoire : Starlette déborderait sur un fichier
    # temporaire au-delà de spool_max_size (1 Mio). Le corps est plafonné par
    # Content-Length dans /interactions/ask, donc jamais au-delà de ce seuil.
    MultiPartParser.spool_max_size = max(
        MultiPartParser.spool_max_size, settings.ai_max_audio_bytes + MULTIPART_OVERHEAD_BYTES
    )

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        )
    app.add_middleware(RequestLoggingMiddleware)
    app.add_exception_handler(DomainError, _domain_error_handler)
    app.add_exception_handler(StaleDataError, _stale_data_handler)

    app.include_router(health.router)
    app.include_router(auth_router)
    app.include_router(sites_router)
    app.include_router(users_router)
    app.include_router(audit_router)
    app.include_router(beneficiaries_router)
    app.include_router(reny_router)
    app.include_router(sync_router)
    app.include_router(contents_router)
    app.include_router(interactions_router)
    app.include_router(alerts_router)
    app.include_router(referrals_router)
    app.include_router(dashboard_router)
    app.include_router(reference_router)
    return app


app = create_app()
