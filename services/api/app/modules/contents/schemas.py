"""Schémas des contenus (section 5 du contrat)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.modules.contents.models import ContentLanguage, ContentModule, ContentStatus

CODE_PATTERN = r"^MSG_[A-Z0-9_]+$"


class ContentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    code: str
    module: ContentModule
    language: ContentLanguage
    title: str
    body: str
    audio_url: str | None
    version: int
    status: ContentStatus
    author_id: uuid.UUID | None
    validator_id: uuid.UUID | None
    validated_at: datetime | None
    source_ref: str | None
    review_note: str | None
    created_at: datetime
    updated_at: datetime


class ContentCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str = Field(pattern=CODE_PATTERN, max_length=64)
    module: ContentModule
    language: ContentLanguage
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=10_000)
    audio_url: str | None = Field(None, max_length=500)
    source_ref: str | None = Field(None, max_length=500)


class ContentPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(None, min_length=1, max_length=200)
    body: str | None = Field(None, min_length=1, max_length=10_000)
    audio_url: str | None = Field(None, max_length=500)
    source_ref: str | None = Field(None, max_length=500)


class NoteBody(BaseModel):
    model_config = ConfigDict(extra="forbid")

    note: str = Field(min_length=1, max_length=2_000)
