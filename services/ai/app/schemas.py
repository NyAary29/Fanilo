"""Schémas HTTP, conformes à docs/api-contrat.md, section 11."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    status: Literal["ok"]
    asr_backend: str
    classifier: str


class TranscribeResponse(BaseModel):
    text: str
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    model: str
    duration_s: float


class ClassifyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str
    module: Literal["reny", "tanora"]


class ClassifyResponse(BaseModel):
    intent: str
    sign_codes: list[str]
    confidence: float = Field(ge=0.0, le=1.0)
    model: str
    is_demo: bool
