"""Question et réponse contrôlée (``POST /interactions/ask``).

Chaîne de décision (docs/securite-medicale.md) :

1. consentement : si une bénéficiaire est désignée, consentement actif pour le
   module (``reny`` ou ``tanora``), plus ``voice_processing`` pour l'audio
   (422 ``consent_required`` sinon) ;
2. le service IA **propose** une transcription puis des codes de signes (forme
   audio ou texte) ; la forme ``sign_codes`` va directement au moteur avec une
   confiance nulle (saisie déterministe) ;
3. **la décision vient du moteur de règles**, jamais de l'IA. Service IA en
   échec, moteur absent, entrée non couverte, confiance basse ou contenu non
   publié : fallback et transfert au conseiller ;
4. le contenu servi est le contenu publié du ``message_code`` (langue demandée,
   repli en français). Un contenu absent ne masque jamais une alerte ;
5. une règle ``urgent`` ou ``critical`` crée une alerte ;
6. l'interaction est journalisée (``review_status = pending`` pour un fallback
   ou un signe de danger) et auditée. L'audio n'est jamais persisté ; ni
   l'audio ni le texte ne sont journalisés.
"""

import logging
import uuid
from dataclasses import dataclass

from fanilo_rules import (
    Action,
    EvaluationContext,
    EvaluationInput,
    EvaluationResult,
    Module,
    RuleEngine,
)
from fanilo_rules import Severity as RuleSeverity
from sqlalchemy import select

from app.core.errors import ConsentRequiredError, NotFoundError, StateConflictError
from app.db.types import utcnow
from app.modules.alerts.models import AlertSeverity
from app.modules.alerts.service import AlertRequest, create_alert
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import Beneficiary, ConsentScope
from app.modules.beneficiaries.service import CARE_ROLES, get_beneficiary
from app.modules.contents.models import ContentItem, ContentLanguage, ContentStatus
from app.modules.contents.service import resolve_published
from app.modules.interactions.ai_client import AiClient, AiServiceError
from app.modules.interactions.models import (
    InputKind,
    Interaction,
    InteractionModule,
    Outcome,
    ReviewStatus,
    Severity,
)
from app.modules.interactions.rules_runtime import RulesRuntime
from app.modules.interactions.schemas import AskContent, AskResponse
from app.modules.reny.models import Pregnancy, PregnancyStatus
from app.modules.reny.reminders import has_active_consent
from app.modules.sites.scope import ActorContext
from app.modules.users.roles import Role

logger = logging.getLogger("fanilo.interactions")

ASK_ROLES: frozenset[Role] = CARE_ROLES
REVIEW_ROLES: frozenset[Role] = frozenset({Role.CLINICAL_ADVISOR, Role.CLINICAL_LEAD})
ALERT_SEVERITIES = (RuleSeverity.URGENT, RuleSeverity.CRITICAL)
TRANSFER = str(Action.TRANSFER_COUNSELOR)
ASR_LANGUAGE = "mg"


@dataclass
class AskInput:
    module: InteractionModule
    beneficiary_id: uuid.UUID | None
    language: ContentLanguage
    text: str | None = None
    sign_codes: list[str] | None = None
    audio: bytes | None = None
    audio_content_type: str | None = None

    @property
    def kind(self) -> InputKind:
        if self.audio is not None:
            return InputKind.AUDIO
        if self.text is not None:
            return InputKind.TEXT
        return InputKind.SIGN_CODES


@dataclass
class _Detection:
    """Propositions de l'IA (ou saisie de l'AC), avant toute décision."""

    transcript: str | None = None
    needs_review: bool = False
    sign_codes: tuple[str, ...] = ()
    confidence: float | None = None
    ai_model: str | None = None
    ai_is_demo: bool = False
    failure: str | None = None


def _check_consents(ctx: ActorContext, beneficiary: Beneficiary, inp: AskInput) -> None:
    scope = ConsentScope(str(inp.module))
    if not has_active_consent(ctx.session, beneficiary.id, scope):
        raise ConsentRequiredError(f"Consentement « {scope} » actif requis.")
    if inp.kind is InputKind.AUDIO and not has_active_consent(
        ctx.session, beneficiary.id, ConsentScope.VOICE_PROCESSING
    ):
        raise ConsentRequiredError(
            "Consentement « voice_processing » actif requis pour une question vocale."
        )


def _detect(ai: AiClient, inp: AskInput, engine: RuleEngine | None) -> _Detection:
    if inp.kind is InputKind.SIGN_CODES:
        # Saisie déterministe par l'AC : aucune confiance de détection.
        return _Detection(sign_codes=tuple(inp.sign_codes or ()), confidence=None)

    detection = _Detection()
    asr_confidence: float | None = None
    if inp.kind is InputKind.AUDIO:
        try:
            transcription = ai.transcribe(
                inp.audio or b"", inp.audio_content_type or "application/octet-stream", ASR_LANGUAGE
            )
        except AiServiceError as exc:
            detection.failure = f"ai_transcribe_{exc.reason}"
            return detection
        detection.transcript = transcription.text.strip() or None
        asr_confidence = transcription.confidence
        threshold = engine.ruleset.min_detection_confidence if engine is not None else 1.0
        # Pas de confiance calibrée (backends actuels) : transcription à revoir.
        detection.needs_review = asr_confidence is None or asr_confidence < threshold
        if detection.transcript is None:
            return detection  # entrée vide : le moteur répondra fallback
    else:
        detection.transcript = (inp.text or "").strip() or None
        if detection.transcript is None:
            return detection

    try:
        classification = ai.classify(detection.transcript, str(inp.module))
    except AiServiceError as exc:
        detection.failure = f"ai_classify_{exc.reason}"
        return detection
    detection.sign_codes = tuple(classification.sign_codes)
    confidence = classification.confidence
    if asr_confidence is not None:
        confidence = min(confidence, asr_confidence)
    detection.confidence = confidence
    detection.ai_model = classification.model[:128] or None
    detection.ai_is_demo = classification.is_demo
    return detection


def _pregnancy_context(ctx: ActorContext, beneficiary: Beneficiary | None) -> bool | None:
    """Vrai si une grossesse active est enregistrée, sinon inconnu (jamais faux :
    l'absence d'enregistrement ne prouve rien et ne doit supprimer aucune règle)."""
    if beneficiary is None:
        return None
    active = ctx.session.scalar(
        select(Pregnancy.id)
        .where(
            Pregnancy.beneficiary_id == beneficiary.id,
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
        )
        .limit(1)
    )
    return True if active is not None else None


def _response_minutes(ctx: ActorContext, result: EvaluationResult) -> tuple[int, bool]:
    """Délai le plus court des règles d'alerte ; placeholder → délai de DÉMO."""
    minutes: list[tuple[int, bool]] = []
    for rule in result.triggered_rules:
        if rule.severity not in ALERT_SEVERITIES:
            continue
        delay = rule.response_delay
        if delay is not None and not delay.is_placeholder and delay.target_minutes:
            minutes.append((delay.target_minutes, False))
        else:
            minutes.append((ctx.settings.alert_demo_response_minutes, True))
    return min(minutes, key=lambda m: m[0])


def _content_out(item: ContentItem | None) -> AskContent | None:
    if item is None:
        return None
    return AskContent(
        code=item.code,
        title=item.title,
        body=item.body,
        audio_url=item.audio_url,
        status=item.status,
    )


def ask(ctx: ActorContext, rules: RulesRuntime, ai: AiClient, inp: AskInput) -> AskResponse:
    ctx.ensure_role(ASK_ROLES)
    session = ctx.session
    beneficiary = None
    if inp.beneficiary_id is not None:
        beneficiary = get_beneficiary(ctx, inp.beneficiary_id)
        _check_consents(ctx, beneficiary, inp)

    engine = rules.engine
    input_kind = inp.kind
    detection = _detect(ai, inp, engine)
    inp.audio = None  # l'audio n'est plus référencé : jamais persisté

    fallback_reasons: list[str] = []
    result: EvaluationResult | None = None
    if detection.failure is not None:
        fallback_reasons.append(detection.failure)
        logger.warning("ai_service_failure", extra={"reason": detection.failure})
    elif engine is None:
        fallback_reasons.append("rules_unavailable")
        logger.error("ask_without_rules_engine", extra={"reason": (rules.error or "")[:300]})
    else:
        result = engine.evaluate(
            EvaluationInput(
                module=Module(str(inp.module)),
                detected_signs=frozenset(detection.sign_codes),
                detection_confidence=detection.confidence,
                context=EvaluationContext(pregnant=_pregnancy_context(ctx, beneficiary)),
            )
        )

    fallback_code = (
        engine.ruleset.fallback_message_code
        if engine is not None
        else ctx.settings.fallback_message_code
    )
    severity: Severity | None = None
    if result is None:
        outcome = Outcome.FALLBACK
        actions = [TRANSFER]
        message_code = fallback_code
    else:
        fallback_reasons += [str(r) for r in result.fallback_reasons]
        actions = [str(a) for a in result.actions]
        if result.max_severity is not None:
            severity = Severity(str(result.max_severity))
        if result.max_severity in ALERT_SEVERITIES:
            outcome = Outcome.DANGER_SIGN
        elif result.fallback:
            outcome = Outcome.FALLBACK
        else:
            outcome = Outcome.ANSWER
        message_code = (
            result.triggered_rules[0].message_code if result.triggered_rules else fallback_code
        )

    content = (
        resolve_published(session, ctx.settings, message_code, inp.language)
        if message_code
        else None
    )
    if content is None:
        if message_code:
            fallback_reasons.append("content_not_published")
            logger.warning("content_not_published", extra={"message_code": message_code})
        # Un contenu absent ne transforme jamais un signe de danger en réponse.
        if outcome is Outcome.ANSWER:
            outcome = Outcome.FALLBACK
        if TRANSFER not in actions:
            actions.append(TRANSFER)
        if fallback_code and fallback_code != message_code:
            content = resolve_published(session, ctx.settings, fallback_code, inp.language)
    if outcome is Outcome.FALLBACK and TRANSFER not in actions:
        actions.append(TRANSFER)

    is_demo = bool(
        (engine is not None and engine.is_demo)
        or (content is not None and content.status is ContentStatus.DEMO)
        or detection.ai_is_demo
    )
    site_id = beneficiary.site_id if beneficiary is not None else ctx.actor.site_id
    interaction = Interaction(
        id=uuid.uuid4(),
        module=inp.module,
        beneficiary_id=beneficiary.id if beneficiary is not None else None,
        site_id=site_id,
        asked_by_user_id=ctx.actor.id,
        input_kind=input_kind,
        language=str(inp.language),
        transcript=detection.transcript,
        transcript_needs_review=detection.needs_review,
        sign_codes=list(detection.sign_codes),
        detection_confidence=detection.confidence,
        ai_model=detection.ai_model,
        outcome=outcome,
        actions=actions,
        severity=severity,
        content_code=content.code if content is not None else None,
        is_demo=is_demo,
        ruleset_id=result.ruleset_id if result is not None else None,
        ruleset_version=result.ruleset_version if result is not None else None,
        fallback_reasons=fallback_reasons,
        decision_trace=[t.model_dump() for t in result.trace] if result is not None else [],
        review_status=(
            ReviewStatus.PENDING
            if outcome in (Outcome.FALLBACK, Outcome.DANGER_SIGN)
            else ReviewStatus.NOT_REQUIRED
        ),
    )
    session.add(interaction)
    session.flush()

    alert_id = None
    if result is not None and result.max_severity in ALERT_SEVERITIES:
        top = result.triggered_rules[0]
        minutes, minutes_are_demo = _response_minutes(ctx, result)
        alert = create_alert(
            session,
            ctx.actor,
            AlertRequest(
                beneficiary_id=interaction.beneficiary_id,
                site_id=site_id,
                interaction_id=interaction.id,
                rule_id=top.rule_id,
                ruleset_version=result.ruleset_version,
                severity=AlertSeverity(str(top.severity)),
                response_minutes=minutes,
                response_is_demo=minutes_are_demo,
                is_demo=is_demo,
            ),
        )
        alert_id = alert.id
        interaction.alert_id = alert.id

    record_audit(
        session, ctx.actor, AuditAction.INTERACTION_ASK, "interaction", interaction.id, site_id
    )
    session.flush()
    logger.info(
        "interaction_recorded",
        extra={
            "interaction_id": str(interaction.id),
            "input_kind": str(input_kind),
            "outcome": str(outcome),
            "severity": str(severity) if severity else None,
            "fallback_reasons": fallback_reasons,
            "is_demo": is_demo,
            "alert_id": str(alert_id) if alert_id else None,
        },
    )
    session.commit()
    return AskResponse(
        interaction_id=interaction.id,
        transcript=detection.transcript,
        transcript_needs_review=detection.needs_review,
        outcome=outcome,
        actions=actions,
        severity=severity,
        content=_content_out(content),
        alert_id=alert_id,
        is_demo=is_demo,
    )


# --- Revue --------------------------------------------------------------------


def get_interaction(ctx: ActorContext, interaction_id: uuid.UUID) -> Interaction:
    ctx.ensure_role(REVIEW_ROLES)
    interaction = ctx.session.get(Interaction, interaction_id)
    if interaction is None:
        raise NotFoundError
    ctx.scope.ensure_contains(interaction.site_id)
    return interaction


def review(ctx: ActorContext, interaction: Interaction, note: str) -> Interaction:
    ctx.ensure_role(REVIEW_ROLES)
    if interaction.review_status is not ReviewStatus.PENDING:
        raise StateConflictError("Cette interaction n'est pas en attente de revue.")
    interaction.review_status = ReviewStatus.REVIEWED
    interaction.reviewed_by_user_id = ctx.actor.id
    interaction.reviewed_at = utcnow()
    interaction.review_note = note.strip()
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.INTERACTION_REVIEW,
        "interaction",
        interaction.id,
        interaction.site_id,
    )
    return interaction
