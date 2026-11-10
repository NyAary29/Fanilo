"""Schémas des interactions (section 6 du contrat)."""

import uuid
from datetime import datetime
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.modules.contents.models import ContentLanguage, ContentStatus
from app.modules.interactions.models import (
    FollowUpStatus,
    InteractionModule,
    Outcome,
    ReviewStatus,
    Severity,
    Triage,
)

DISCLAIMER = "FANILO ne remplace pas un professionnel de santé."
MAX_TEXT_CHARS = 2_000
MAX_SIGN_CODES = 50

SignCodeInput = Annotated[str, StringConstraints(min_length=1, max_length=64)]


class AskJson(BaseModel):
    """Forme JSON : texte déjà transcrit OU signes cochés par l'AC (exclusifs)."""

    model_config = ConfigDict(extra="forbid")

    module: InteractionModule
    beneficiary_id: uuid.UUID | None = None
    text: str | None = Field(None, min_length=1, max_length=MAX_TEXT_CHARS)
    sign_codes: list[SignCodeInput] | None = Field(None, max_length=MAX_SIGN_CODES)
    # Langue du contenu renvoyé (mg par défaut, repli en français).
    language: ContentLanguage = ContentLanguage.MG

    @model_validator(mode="after")
    def _one_input(self) -> Self:
        if (self.text is None) == (self.sign_codes is None):
            raise ValueError("Fournir soit 'text', soit 'sign_codes' (exactement un des deux).")
        return self


class AskContent(BaseModel):
    code: str
    title: str
    body: str
    audio_url: str | None
    status: ContentStatus


class AskResponse(BaseModel):
    interaction_id: uuid.UUID
    transcript: str | None
    transcript_needs_review: bool
    outcome: Outcome
    actions: list[str]
    severity: Severity | None
    content: AskContent | None
    alert_id: uuid.UUID | None
    is_demo: bool
    disclaimer: str = DISCLAIMER


class InteractionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    created_at: datetime
    module: InteractionModule
    beneficiary_id: uuid.UUID | None
    site_id: uuid.UUID | None
    asked_by_user_id: uuid.UUID | None
    channel: str = "agent"
    transcript: str | None
    transcript_needs_review: bool
    sign_codes: list[str]
    intent: str | None = None
    detection_confidence: float | None
    outcome: Outcome
    actions: list[str]
    severity: Severity | None
    content_code: str | None
    alert_id: uuid.UUID | None
    is_demo: bool
    ruleset_version: str | None
    fallback_reasons: list[str]
    review_status: ReviewStatus
    reviewed_by_user_id: uuid.UUID | None
    reviewed_at: datetime | None
    review_note: str | None
    orientation_site_id: uuid.UUID | None = None
    triage: Triage | None = None
    follow_up_code: str | None = None
    follow_up_status: FollowUpStatus | None = None
    follow_up_at: datetime | None = None
    follow_up_note: str | None = None


class ReviewBody(BaseModel):
    model_config = ConfigDict(extra="forbid")

    note: str = Field(min_length=1, max_length=2_000)
    # Centre de santé conseillé (CSB ou structure de référence), facultatif.
    orientation_site_id: uuid.UUID | None = None
    # Classement : urgent / à suivre / information. « urgent » et « à suivre »
    # exigent un centre : la personne y est attendue (suivi par le centre).
    triage: Triage | None = None
