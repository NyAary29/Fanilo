"""Endpoints des interactions (section 6 du contrat).

``POST /interactions/ask`` accepte deux formes :

- ``multipart/form-data`` : ``audio`` (fichier), ``module``, ``beneficiary_id?``,
  ``language?`` ; l'audio est lu **en mémoire** (``Content-Length`` obligatoire
  et plafonné à ``FANILO_AI_MAX_AUDIO_BYTES`` + en-têtes multipart), relayé au
  service IA puis oublié ; il n'est jamais écrit sur disque ni journalisé ;
- JSON ``{module, beneficiary_id?, text? | sign_codes?, language?}``.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import ValidationError
from sqlalchemy import case, or_, select
from starlette.datastructures import UploadFile

from app.core.pagination import Page, PageParams, page_params, paginate
from app.modules.contents.models import ContentLanguage
from app.modules.interactions import service
from app.modules.interactions.ai_client import AiClient, get_ai_client
from app.modules.interactions.models import Interaction, InteractionModule, Outcome, ReviewStatus
from app.modules.interactions.rules_runtime import RulesRuntime, get_rules_runtime
from app.modules.interactions.schemas import AskJson, AskResponse, InteractionOut, ReviewBody
from app.modules.sites.scope import ActorContext, get_actor_context

router = APIRouter(prefix="/interactions", tags=["interactions"])

# Marge pour les en-têtes et champs du formulaire multipart.
MULTIPART_OVERHEAD_BYTES = 64 * 1024


def _unprocessable(detail: str) -> HTTPException:
    return HTTPException(status_code=422, detail=detail)


async def _multipart_input(request: Request, max_audio: int) -> service.AskInput:
    raw_length = request.headers.get("content-length")
    if raw_length is None:
        raise HTTPException(status_code=411, detail="Content-Length requis pour un envoi audio.")
    try:
        length = int(raw_length)
    except ValueError:
        raise _unprocessable("Content-Length invalide.") from None
    if length > max_audio + MULTIPART_OVERHEAD_BYTES:
        raise HTTPException(status_code=413, detail="Audio trop volumineux.")
    form = await request.form(max_files=1, max_fields=10)
    try:
        audio = form.get("audio")
        if not isinstance(audio, UploadFile):
            raise _unprocessable("Champ 'audio' (fichier) obligatoire.")
        try:
            module = InteractionModule(str(form.get("module", "")))
            raw_beneficiary = form.get("beneficiary_id")
            beneficiary_id = uuid.UUID(str(raw_beneficiary)) if raw_beneficiary else None
            language = ContentLanguage(str(form.get("language") or ContentLanguage.MG))
        except ValueError:
            raise _unprocessable(
                "Champs 'module', 'beneficiary_id' ou 'language' invalides."
            ) from None
        data = await audio.read(max_audio + 1)
        if len(data) > max_audio:
            raise HTTPException(status_code=413, detail="Audio trop volumineux.")
        if not data:
            raise _unprocessable("Audio vide.")
        return service.AskInput(
            module=module,
            beneficiary_id=beneficiary_id,
            language=language,
            audio=data,
            audio_content_type=audio.content_type or "application/octet-stream",
        )
    finally:
        await form.close()


async def _json_input(request: Request) -> service.AskInput:
    try:
        raw = await request.json()
    except ValueError:
        raise _unprocessable("Corps JSON invalide.") from None
    try:
        body = AskJson.model_validate(raw)
    except ValidationError as exc:
        raise HTTPException(
            status_code=422, detail=exc.errors(include_url=False, include_context=False)
        ) from None
    return service.AskInput(
        module=body.module,
        beneficiary_id=body.beneficiary_id,
        language=body.language,
        text=body.text,
        sign_codes=body.sign_codes,
    )


@router.post(
    "/ask",
    response_model=AskResponse,
    summary="Poser une question (audio, texte ou signes) : réponse contrôlée par les règles",
)
async def ask(
    request: Request,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
    rules: RulesRuntime = Depends(get_rules_runtime),  # noqa: B008
    ai: AiClient = Depends(get_ai_client),  # noqa: B008
) -> AskResponse:
    ctx.ensure_role(service.ASK_ROLES)
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("multipart/form-data"):
        inp = await _multipart_input(request, ctx.settings.ai_max_audio_bytes)
    else:
        inp = await _json_input(request)
    return await run_in_threadpool(service.ask, ctx, rules, ai, inp)


@router.get(
    "",
    response_model=Page[InteractionOut],
    summary="Interactions (revue des questions transférées ou non couvertes)",
)
def list_interactions(
    review_status: ReviewStatus | None = None,
    module: InteractionModule | None = None,
    page: PageParams = Depends(page_params),  # noqa: B008
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> dict:
    ctx.ensure_role(service.REVIEW_ROLES)
    # Les questions anonymes (application publique) ne contiennent aucune donnée
    # nominative : tous les rôles de revue les voient, quelle que soit la zone
    # choisie par l'utilisatrice (sinon une question peut rester sans réponse).
    stmt = select(Interaction).where(
        or_(
            ctx.scope.filter(Interaction.site_id),
            Interaction.channel == "public_app",
        )
    )
    if review_status is not None:
        stmt = stmt.where(Interaction.review_status == review_status)
    if module is not None:
        stmt = stmt.where(Interaction.module == module)
    # Urgences d'abord (signe de danger décidé ou soupçonné), puis les plus anciennes.
    urgent = case(
        (
            or_(
                Interaction.outcome == Outcome.DANGER_SIGN,
                Interaction.severity.is_not(None),
                Interaction.intent == "report_danger_sign",
            ),
            0,
        ),
        else_=1,
    )
    stmt = stmt.order_by(urgent, Interaction.created_at, Interaction.id)
    items, total = paginate(ctx.session, stmt, page)
    return {"items": items, "total": total}


@router.post(
    "/{interaction_id}/review", response_model=InteractionOut, summary="Documenter la revue"
)
def review(
    interaction_id: uuid.UUID,
    body: ReviewBody,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Interaction:
    interaction = service.review(
        ctx,
        service.get_interaction(ctx, interaction_id),
        body.note,
        body.orientation_site_id,
        body.triage,
    )
    ctx.session.commit()
    return interaction
