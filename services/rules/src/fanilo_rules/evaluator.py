"""Évaluateur pur et déterministe des règles de signes de danger.

L'évaluateur ne fait AUCUN appel à un modèle d'IA, à une base de données ou au réseau.
Pour une même entrée (et un même jeu de règles), il renvoie toujours la même sortie.

Principes de sécurité appliqués :
- aucune entrée n'aboutit à « rien à signaler » : si aucune règle ne se déclenche,
  la sortie est un transfert au conseiller humain (``fallback``) ;
- entrée vide, code de signe inconnu, confiance sous le seuil → ``fallback`` ;
- un code inconnu ne masque jamais une règle déclenchée par les codes connus : les
  orientations des règles sont conservées ET le transfert au conseiller est ajouté ;
- une confiance sous le seuil rend toute la détection non fiable : aucune orientation
  automatique, transfert au conseiller, et les règles « candidates » sont exposées pour
  aider le conseiller à prioriser ;
- un contexte inconnu (ex. grossesse non renseignée) ne supprime jamais une règle.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StrictBool

from .loader import RulesetValidationError, load_ruleset, load_sign_catalog
from .schema import (
    Action,
    MatchMode,
    MessageCode,
    Module,
    ResponseDelay,
    Rule,
    Ruleset,
    Severity,
    SignCatalog,
)


class _Frozen(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class EvaluationContext(_Frozen):
    """Contexte minimal de la personne (``None`` = inconnu)."""

    pregnant: StrictBool | None = None


class EvaluationInput(_Frozen):
    """Entrée de l'évaluateur."""

    module: Module
    detected_signs: frozenset[str] = frozenset()
    detection_confidence: Annotated[float, Field(ge=0.0, le=1.0)] | None = None
    """Confiance de la détection amont (``None`` = saisie déterministe, ex. clavier)."""
    context: EvaluationContext = EvaluationContext()


class FallbackReason(StrEnum):
    """Motifs de transfert au conseiller humain."""

    EMPTY_INPUT = "empty_input"
    UNKNOWN_SIGN_CODE = "unknown_sign_code"
    LOW_CONFIDENCE = "low_confidence"
    NO_RULE_MATCHED = "no_rule_matched"


class TraceStep(_Frozen):
    """Étape de la trace explicable."""

    step: str
    detail: str


class TriggeredRule(_Frozen):
    """Règle déclenchée (ou candidate en cas de confiance basse)."""

    rule_id: str
    rule_version: str
    severity: Severity
    action: Action
    message_code: MessageCode
    matched_signs: tuple[str, ...]
    response_delay: ResponseDelay | None


class EvaluationResult(_Frozen):
    """Sortie de l'évaluateur."""

    ruleset_id: str
    ruleset_version: str
    sign_catalog_version: str
    is_demo: bool
    module: Module
    triggered_rules: tuple[TriggeredRule, ...]
    candidate_rules: tuple[TriggeredRule, ...]
    max_severity: Severity | None
    actions: tuple[Action, ...]
    message_codes: tuple[str, ...]
    fallback: bool
    fallback_reasons: tuple[FallbackReason, ...]
    unknown_signs: tuple[str, ...]
    trace: tuple[TraceStep, ...]


def _matches(rule: Rule, signs: frozenset[str], context: EvaluationContext) -> tuple[str, ...]:
    """Renvoie les signes correspondants si la règle se déclenche, sinon un tuple vide."""
    required = rule.conditions.context.pregnant
    if required is not None and context.pregnant is not None and required != context.pregnant:
        return ()
    matched = tuple(sorted(s for s in rule.conditions.signs if s in signs))
    if rule.conditions.match is MatchMode.ALL and len(matched) != len(rule.conditions.signs):
        return ()
    return matched


def _to_triggered(rule: Rule, matched: tuple[str, ...]) -> TriggeredRule:
    return TriggeredRule(
        rule_id=rule.id,
        rule_version=rule.version,
        severity=rule.severity,
        action=rule.action,
        message_code=rule.message_code,
        matched_signs=matched,
        response_delay=rule.response_delay,
    )


def _dedupe[T](items: Iterable[T]) -> tuple[T, ...]:
    return tuple(dict.fromkeys(items))


@dataclass(frozen=True, slots=True)
class RuleEngine:
    """Association vérifiée d'un jeu de règles et de son référentiel de signes."""

    ruleset: Ruleset
    catalog: SignCatalog

    def __post_init__(self) -> None:
        ref = self.ruleset.sign_catalog
        if (ref.catalog_id, ref.version) != (self.catalog.catalog_id, self.catalog.version):
            raise RulesetValidationError(
                f"le jeu {self.ruleset.ruleset_id} référence le référentiel "
                f"{ref.catalog_id}@{ref.version}, chargé : "
                f"{self.catalog.catalog_id}@{self.catalog.version}"
            )
        for rule in self.ruleset.rules:
            unknown = sorted(set(rule.conditions.signs) - self.catalog.codes_for(rule.module))
            if unknown:
                raise RulesetValidationError(
                    f"la règle {rule.id} utilise des codes absents du référentiel pour le "
                    f"module {rule.module} : {', '.join(unknown)}"
                )

    @classmethod
    def from_files(
        cls, ruleset_path: str | Path, catalog_path: str | Path, *, allow_demo: bool
    ) -> RuleEngine:
        """Charge un jeu de règles et son référentiel selon la politique ``allow_demo``."""
        catalog = load_sign_catalog(catalog_path, allow_demo=allow_demo)
        ruleset = load_ruleset(ruleset_path, allow_demo=allow_demo)
        return cls(ruleset=ruleset, catalog=catalog)

    @property
    def is_demo(self) -> bool:
        """Vrai si le jeu de règles OU le référentiel n'est pas validé cliniquement."""
        return self.ruleset.is_demo or self.catalog.is_demo

    def evaluate(self, request: EvaluationInput) -> EvaluationResult:
        """Évalue une entrée de façon pure et déterministe."""
        trace: list[TraceStep] = [
            TraceStep(
                step="ruleset",
                detail=(
                    f"{self.ruleset.ruleset_id}@{self.ruleset.version} "
                    f"(statut {self.ruleset.status}), référentiel "
                    f"{self.catalog.catalog_id}@{self.catalog.version} "
                    f"(statut {self.catalog.status})"
                ),
            )
        ]
        reasons: list[FallbackReason] = []

        known_codes = self.catalog.codes_for(request.module)
        signs = frozenset(request.detected_signs)
        known = frozenset(s for s in signs if s in known_codes)
        unknown = tuple(sorted(signs - known))
        trace.append(
            TraceStep(
                step="input",
                detail=(
                    f"module={request.module} signes={sorted(signs)} "
                    f"confiance={request.detection_confidence} "
                    f"grossesse={request.context.pregnant}"
                ),
            )
        )

        if not signs:
            reasons.append(FallbackReason.EMPTY_INPUT)
            trace.append(TraceStep(step="fallback", detail="entrée vide"))
        if unknown:
            reasons.append(FallbackReason.UNKNOWN_SIGN_CODE)
            trace.append(
                TraceStep(
                    step="fallback",
                    detail=f"codes inconnus du référentiel pour ce module : {list(unknown)}",
                )
            )

        low_confidence = (
            request.detection_confidence is not None
            and request.detection_confidence < self.ruleset.min_detection_confidence
        )
        if low_confidence:
            reasons.append(FallbackReason.LOW_CONFIDENCE)
            trace.append(
                TraceStep(
                    step="fallback",
                    detail=(
                        f"confiance {request.detection_confidence} < seuil "
                        f"{self.ruleset.min_detection_confidence} : aucune orientation "
                        "automatique"
                    ),
                )
            )

        matched_rules: list[TriggeredRule] = []
        for rule in self.ruleset.rules_for(request.module):
            matched = _matches(rule, known, request.context)
            if matched:
                matched_rules.append(_to_triggered(rule, matched))
                trace.append(
                    TraceStep(
                        step="rule_matched",
                        detail=f"{rule.id}@{rule.version} ({rule.severity}) via {list(matched)}",
                    )
                )
            else:
                trace.append(TraceStep(step="rule_not_matched", detail=rule.id))
        matched_rules.sort(key=lambda t: (-t.severity.rank, t.rule_id))

        if low_confidence:
            triggered: tuple[TriggeredRule, ...] = ()
            candidates = tuple(matched_rules)
        else:
            triggered = tuple(matched_rules)
            candidates = ()

        if not triggered and not reasons:
            reasons.append(FallbackReason.NO_RULE_MATCHED)
            trace.append(TraceStep(step="fallback", detail="aucune règle déclenchée"))

        fallback = bool(reasons)
        actions = [t.action for t in triggered]
        message_codes = [t.message_code for t in triggered]
        if fallback:
            actions.append(Action.TRANSFER_COUNSELOR)
            message_codes.append(self.ruleset.fallback_message_code)

        max_severity = triggered[0].severity if triggered else None
        result_actions = _dedupe(actions)
        trace.append(
            TraceStep(
                step="decision",
                detail=(
                    f"sévérité max={max_severity} actions={[str(a) for a in result_actions]} "
                    f"fallback={fallback}"
                ),
            )
        )

        return EvaluationResult(
            ruleset_id=self.ruleset.ruleset_id,
            ruleset_version=self.ruleset.version,
            sign_catalog_version=self.catalog.version,
            is_demo=self.is_demo,
            module=request.module,
            triggered_rules=triggered,
            candidate_rules=candidates,
            max_severity=max_severity,
            actions=result_actions,
            message_codes=_dedupe(message_codes),
            fallback=fallback,
            fallback_reasons=tuple(reasons),
            unknown_signs=unknown,
            trace=tuple(trace),
        )
