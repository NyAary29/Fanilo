from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.config import Settings, get_settings

router = APIRouter(tags=["santé du service"])


class HealthResponse(BaseModel):
    status: str
    version: str


@router.get("/health", response_model=HealthResponse, summary="Vérification de disponibilité")
def health(settings: Settings = Depends(get_settings)) -> HealthResponse:  # noqa: B008
    """Liveness probe. La vérification de la base (readiness) arrive avec le lot P0.2."""
    return HealthResponse(status="ok", version=settings.version)
