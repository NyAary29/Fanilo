"""API publique ANONYME : application « FANILO Femmes & Adolescentes » (docs/api-publique.md).

Aucun compte, aucun nom, aucun téléphone. Garanties :

- même chaîne de décision que le canal agent (``interactions.service._decide``) :
  l'IA propose, les règles décident, contenus approuvés uniquement ;
- **aucune alerte** : personne n'est joignable. Un signe de danger reconnu renvoie
  ``urgent = true`` et l'orientation (« allez au centre de santé ») ;
- une question à revoir reçoit un **jeton de suivi** aléatoire, renvoyé une seule
  fois ; seule son empreinte SHA-256 est stockée. La réponse du conseiller
  (note de revue) est lisible avec ce jeton, et l'utilisatrice peut tout effacer ;
- l'audio est transcrit en mémoire, jamais conservé, et exige ``voice_consent`` ;
- limitation de débit par adresse IP (en mémoire, par instance).
"""

import hashlib
import hmac
import logging
import secrets
import threading
import time
import uuid
from collections import defaultdict, deque
from datetime import datetime
from typing import Literal

from fanilo_rules import Module
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import UploadFile

from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.modules.audit.service import AuditAction, record_audit
from app.modules.contents.models import ContentLanguage
from app.modules.contents.service import resolve_published
from app.modules.information.config import served_information_config
from app.modules.interactions import service as interactions
from app.modules.interactions.ai_client import AiClient, get_ai_client
from app.modules.interactions.models import Interaction, InteractionModule, Outcome, ReviewStatus
from app.modules.interactions.router import MULTIPART_OVERHEAD_BYTES
from app.modules.interactions.rules_runtime import RulesRuntime, get_rules_runtime
from app.modules.interactions.schemas import AskContent
from app.modules.reference.consent_information import (
    ConsentInformationError,
    load_consent_information,
    served_items,
)
from app.modules.reference.router import MenuItemOut, MenuResponse
from app.modules.sites.models import Site, SiteKind

logger = logging.getLogger("fanilo.public")
router = APIRouter(prefix="/public", tags=["public (anonyme)"])

CHANNEL = "public_app"
PUBLIC_SCOPES = ("reny", "tanora", "voice_processing")
DISCLAIMER = "FANILO ne remplace pas un professionnel de santé."


# --- Limitation de débit -------------------------------------------------------


class _RateLimiter:
    """Fenêtre glissante d'une heure par clé (adresse IP). En mémoire, par instance."""

    def __init__(self, clock=time.monotonic) -> None:
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._clock = clock

    def allow(self, key: str, limit: int, window: float = 3600.0) -> bool:
        with self._lock:
            now = self._clock()
            hits = self._hits[key]
            while hits and now - hits[0] >= window:
                hits.popleft()
            if len(hits) >= limit:
                return False
            hits.append(now)
            return True


_limiter = _RateLimiter()


def _enabled(settings: Settings = Depends(get_settings)) -> Settings:  # noqa: B008
    if not settings.public_api_enabled:
        raise HTTPException(status_code=404)
    return settings


# --- Référentiels --------------------------------------------------------------


class PublicSite(BaseModel):
    id: uuid.UUID
    name: str
    district: str
    region: str


class PublicSites(BaseModel):
    items: list[PublicSite]


@router.get("/sites", response_model=PublicSites, summary="CSB actifs (choix facultatif de zone)")
def public_sites(
    _settings: Settings = Depends(_enabled),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> PublicSites:
    sites = db.scalars(
        select(Site)
        .where(Site.kind == SiteKind.CSB, Site.is_active.is_(True), Site.deleted_at.is_(None))
        .order_by(Site.region, Site.name)
    )
    return PublicSites(
        items=[
            PublicSite(id=s.id, name=s.name, district=s.district, region=s.region) for s in sites
        ]
    )


class PublicInformation(BaseModel):
    scope: str
    version: str
    status: str
    summary_fr: str
    summary_mg: str | None


class PublicInformationList(BaseModel):
    items: list[PublicInformation]


@router.get("/information", response_model=PublicInformationList, summary="Information à présenter")
def public_information(settings: Settings = Depends(_enabled)) -> PublicInformationList:  # noqa: B008
    try:
        document = load_consent_information(settings.public_information_path)
    except ConsentInformationError:
        raise HTTPException(status_code=503, detail="Information indisponible.") from None
    items = [
        PublicInformation(**{**item, "scope": str(item["scope"])})
        for item in served_items(document, allow_demo=settings.allow_demo_content)
        if str(item["scope"]) in PUBLIC_SCOPES
    ]
    return PublicInformationList(items=items)


@router.get("/menus", response_model=MenuResponse, summary="Menu vocal d'un module")
def public_menu(
    module: Module,
    language: ContentLanguage = ContentLanguage.MG,
    settings: Settings = Depends(_enabled),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> MenuResponse:
    config = served_information_config(
        settings.information_config_path, allow_demo=settings.allow_demo_content
    )
    if config is None:
        raise HTTPException(status_code=503, detail="Menu vocal indisponible.")
    items = []
    for entry in config.menus.get(str(module), ()):
        content = resolve_published(db, settings, entry.message_code, language)
        if content is not None:
            items.append(
                MenuItemOut(
                    key=entry.key,
                    code=content.code,
                    title=content.title,
                    body=content.body,
                    audio_url=content.audio_url,
                    status=str(content.status),
                )
            )
    return MenuResponse(
        config_id=config.config_id,
        version=config.version,
        is_demo=config.is_demo or any(i.status != "validated" for i in items),
        module=str(module),
        items=sorted(items, key=lambda i: i.key),
    )


# --- Question ------------------------------------------------------------------


class PublicAskJson(BaseModel):
    module: InteractionModule
    text: str = Field(min_length=1, max_length=2_000)
    language: ContentLanguage = ContentLanguage.MG
    site_id: uuid.UUID | None = None


class FollowUp(BaseModel):
    token: str
    status: Literal["pending"] = "pending"


class PublicAskResponse(BaseModel):
    question_id: uuid.UUID
    transcript: str | None
    transcript_needs_review: bool
    outcome: Outcome
    actions: list[str]
    content: AskContent | None
    urgent: bool
    follow_up: FollowUp | None
    is_demo: bool
    disclaimer: str = DISCLAIMER


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _check_site(db: Session, site_id: uuid.UUID | None) -> None:
    if site_id is None:
        return
    site = db.get(Site, site_id)
    if site is None or site.kind is not SiteKind.CSB or not site.is_active:
        raise HTTPException(status_code=422, detail="Centre de santé inconnu.")


def _is_urgent(decision: interactions._Decision) -> bool:  # noqa: SLF001
    """Prudence : l'utilisatrice anonyme ne peut pas être rappelée. Un signe de danger
    décidé par les règles, OU simplement soupçonné (codes proposés par l'IA, règle
    candidate sous le seuil de confiance), affiche la consigne d'urgence. Cela ne crée
    aucune alerte et ne constitue pas un diagnostic."""
    result = decision.result
    return (
        decision.outcome is Outcome.DANGER_SIGN
        or bool(decision.detection.sign_codes)
        or (
            result is not None
            and any(str(r.severity) in ("urgent", "critical") for r in result.candidate_rules)
        )
    )


def _public_ask(
    db: Session,
    settings: Settings,
    rules: RulesRuntime,
    ai: AiClient,
    inp: interactions.AskInput,
    site_id: uuid.UUID | None,
) -> PublicAskResponse:
    decision = interactions._decide(db, settings, rules, ai, inp, pregnant=None)  # noqa: SLF001
    # Le message de transfert standard promet un rappel : impossible ici (anonyme).
    fallback_code = rules.engine.ruleset.fallback_message_code if rules.engine else None
    if decision.content is not None and decision.content.code == fallback_code:
        public = resolve_published(
            db, settings, settings.public_transfer_message_code, inp.language
        )
        if public is not None:
            decision.content = public
    inp.audio = None  # jamais conservé
    detection = decision.detection
    review = decision.review_required
    token = secrets.token_urlsafe(32) if review else None
    interaction = Interaction(
        id=uuid.uuid4(),
        module=inp.module,
        beneficiary_id=None,
        site_id=site_id,
        asked_by_user_id=None,
        channel=CHANNEL,
        follow_up_token_hash=_hash(token) if token else None,
        input_kind=decision.input_kind,
        language=str(inp.language),
        transcript=detection.transcript,
        transcript_needs_review=detection.needs_review,
        sign_codes=list(detection.sign_codes),
        intent=detection.intent,
        detection_confidence=detection.confidence,
        ai_model=detection.ai_model,
        outcome=decision.outcome,
        actions=decision.actions,
        severity=decision.severity,
        content_code=decision.content.code if decision.content is not None else None,
        is_demo=decision.is_demo,
        ruleset_id=decision.result.ruleset_id if decision.result is not None else None,
        ruleset_version=decision.result.ruleset_version if decision.result is not None else None,
        fallback_reasons=decision.fallback_reasons,
        decision_trace=decision.trace(),
        review_status=ReviewStatus.PENDING if review else ReviewStatus.NOT_REQUIRED,
    )
    db.add(interaction)
    db.flush()
    record_audit(db, None, AuditAction.INTERACTION_ASK, "interaction", interaction.id, site_id)
    db.commit()
    logger.info(
        "public_interaction_recorded",
        extra={"interaction_id": str(interaction.id), "outcome": str(decision.outcome)},
    )
    return PublicAskResponse(
        question_id=interaction.id,
        transcript=detection.transcript,
        transcript_needs_review=detection.needs_review,
        outcome=decision.outcome,
        actions=decision.actions,
        content=interactions._content_out(decision.content),  # noqa: SLF001
        urgent=_is_urgent(decision),
        follow_up=FollowUp(token=token) if token else None,
        is_demo=decision.is_demo,
    )


async def _read_multipart(
    request: Request, max_audio: int
) -> tuple[interactions.AskInput, uuid.UUID | None]:
    raw_length = request.headers.get("content-length")
    if raw_length is None or not raw_length.isdigit():
        raise HTTPException(status_code=411, detail="Content-Length requis pour un envoi audio.")
    if int(raw_length) > max_audio + MULTIPART_OVERHEAD_BYTES:
        raise HTTPException(status_code=413, detail="Audio trop volumineux.")
    form = await request.form(max_files=1, max_fields=10)
    try:
        if str(form.get("voice_consent", "")).lower() != "true":
            raise HTTPException(
                status_code=422,
                detail={"code": "consent_required", "message": "Accord pour la voix requis."},
            )
        audio = form.get("audio")
        if not isinstance(audio, UploadFile):
            raise HTTPException(status_code=422, detail="Champ 'audio' (fichier) obligatoire.")
        try:
            module = InteractionModule(str(form.get("module", "")))
            language = ContentLanguage(str(form.get("language") or ContentLanguage.MG))
            raw_site = form.get("site_id")
            site_id = uuid.UUID(str(raw_site)) if raw_site else None
        except ValueError:
            raise HTTPException(
                status_code=422, detail="Champs 'module', 'language' ou 'site_id' invalides."
            ) from None
        data = await audio.read(max_audio + 1)
        if len(data) > max_audio:
            raise HTTPException(status_code=413, detail="Audio trop volumineux.")
        if not data:
            raise HTTPException(status_code=422, detail="Audio vide.")
        inp = interactions.AskInput(
            module=module,
            beneficiary_id=None,
            language=language,
            audio=data,
            audio_content_type=audio.content_type or "application/octet-stream",
        )
        return inp, site_id
    finally:
        await form.close()


def _client_key(request: Request) -> str:
    return request.client.host if request.client else "inconnu"


@router.post("/ask", response_model=PublicAskResponse, summary="Poser une question (anonyme)")
async def public_ask(
    request: Request,
    settings: Settings = Depends(_enabled),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
    rules: RulesRuntime = Depends(get_rules_runtime),  # noqa: B008
    ai: AiClient = Depends(get_ai_client),  # noqa: B008
) -> PublicAskResponse:
    if not _limiter.allow(_client_key(request), settings.public_ask_per_hour):
        raise HTTPException(
            status_code=429,
            detail="Trop de questions. Réessayez plus tard.",
            headers={"Retry-After": "600"},
        )
    if request.headers.get("content-type", "").startswith("multipart/form-data"):
        inp, site_id = await _read_multipart(request, settings.ai_max_audio_bytes)
    else:
        try:
            body = PublicAskJson.model_validate(await request.json())
        except ValueError as exc:
            detail = (
                exc.errors(include_url=False, include_context=False)
                if isinstance(exc, ValidationError)
                else "Corps JSON invalide."
            )
            raise HTTPException(status_code=422, detail=detail) from None
        inp = interactions.AskInput(
            module=body.module, beneficiary_id=None, language=body.language, text=body.text
        )
        site_id = body.site_id
    _check_site(db, site_id)
    return await run_in_threadpool(_public_ask, db, settings, rules, ai, inp, site_id)


# --- Suivi par jeton -------------------------------------------------------------


class Orientation(BaseModel):
    """Centre de santé où le conseiller oriente la personne."""

    name: str
    kind: str
    district: str
    region: str


class PublicQuestion(BaseModel):
    question_id: uuid.UUID
    module: str
    status: Literal["pending", "answered"]
    answer: str | None
    answered_at: datetime | None
    orientation: Orientation | None = None
    # Classement du conseiller : urgent / follow_up (à suivre) / info.
    triage: str | None = None
    # Code à montrer au centre ; statut du suivi : expected / came / no_show.
    follow_up_code: str | None = None
    follow_up_status: str | None = None


def _find(db: Session, question_id: uuid.UUID, token: str) -> Interaction:
    item = db.get(Interaction, question_id)
    if (
        item is None
        or item.channel != CHANNEL
        or item.follow_up_token_hash is None
        or not hmac.compare_digest(item.follow_up_token_hash, _hash(token))
    ):
        raise HTTPException(status_code=404, detail="Question introuvable.")
    return item


def _orientation(db: Session, item: Interaction) -> Orientation | None:
    if item.orientation_site_id is None:
        return None
    site = db.get(Site, item.orientation_site_id)
    if site is None:
        return None
    return Orientation(
        name=site.name, kind=str(site.kind), district=site.district, region=site.region
    )


@router.get("/questions/{question_id}", response_model=PublicQuestion, summary="Suivre sa question")
def public_question(
    question_id: uuid.UUID,
    token: str = Query(min_length=1, max_length=256),
    _settings: Settings = Depends(_enabled),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> PublicQuestion:
    item = _find(db, question_id, token)
    answered = item.review_status is ReviewStatus.REVIEWED and bool(item.review_note)
    return PublicQuestion(
        question_id=item.id,
        module=str(item.module),
        status="answered" if answered else "pending",
        answer=item.review_note if answered else None,
        answered_at=item.reviewed_at if answered else None,
        orientation=_orientation(db, item) if answered else None,
        triage=str(item.triage) if answered and item.triage else None,
        follow_up_code=item.follow_up_code if answered else None,
        follow_up_status=str(item.follow_up_status) if answered and item.follow_up_status else None,
    )


@router.delete(
    "/questions/{question_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Effacer sa question (transcription et réponse)",
)
def delete_public_question(
    question_id: uuid.UUID,
    token: str = Query(min_length=1, max_length=256),
    _settings: Settings = Depends(_enabled),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> Response:
    item = _find(db, question_id, token)
    # On garde la ligne (statistiques agrégées) mais on efface tout contenu libre.
    item.transcript = None
    item.review_note = None
    item.orientation_site_id = None
    item.follow_up_token_hash = None
    if item.review_status is ReviewStatus.PENDING:
        item.review_status = ReviewStatus.NOT_REQUIRED
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
