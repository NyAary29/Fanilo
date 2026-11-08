"""Schéma des jeux de règles et du référentiel des codes de signes.

Ce module ne contient AUCUN contenu médical : uniquement la structure, validée par
pydantic, des fichiers YAML rédigés et validés par le responsable clinique.

Garanties apportées au chargement :
- tout champ inconnu est rejeté (``extra="forbid"``) ;
- les actions sont limitées à un enum fermé d'orientations (aucune prescription) ;
- les identifiants de règles et les codes de signes sont uniques ;
- un statut ``validated`` exige ``validated_by`` et ``validated_at`` ;
- un jeu ``validated`` ne peut contenir aucun délai « placeholder ».
"""

from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import Annotated, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StrictBool,
    StrictInt,
    StringConstraints,
    model_validator,
)

SEMVER_PATTERN = (
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)

SemVer = Annotated[str, StringConstraints(pattern=SEMVER_PATTERN)]
SignCode = Annotated[str, StringConstraints(pattern=r"^SIGN_[A-Z0-9_]+$", max_length=64)]
MessageCode = Annotated[str, StringConstraints(pattern=r"^MSG_[A-Z0-9_]+$", max_length=64)]
RuleId = Annotated[str, StringConstraints(pattern=r"^[A-Z][A-Z0-9_.-]{2,63}$")]
Identifier = Annotated[str, StringConstraints(pattern=r"^[a-z0-9][a-z0-9_.-]{2,63}$")]
LanguageTag = Annotated[str, StringConstraints(pattern=r"^[a-z]{2,3}(-[A-Z]{2})?$")]
NonEmptyText = Annotated[
    str, StringConstraints(min_length=1, max_length=500, strip_whitespace=True)
]


class _Model(BaseModel):
    """Base commune : immuable, champs inconnus interdits."""

    model_config = ConfigDict(extra="forbid", frozen=True)


class Status(StrEnum):
    """Cycle de vie d'un jeu de règles ou d'un référentiel."""

    DEMO = "demo"
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    VALIDATED = "validated"
    RETIRED = "retired"


class Module(StrEnum):
    """Modules fonctionnels de FANILO."""

    RENY = "reny"
    TANORA = "tanora"


class Severity(StrEnum):
    """Niveau de sévérité d'une règle (ordre : routine < urgent < critical)."""

    ROUTINE = "routine"
    URGENT = "urgent"
    CRITICAL = "critical"

    @property
    def rank(self) -> int:
        """Rang numérique utilisé pour déterminer la sévérité maximale."""
        return _SEVERITY_RANK[self]


_SEVERITY_RANK: dict[Severity, int] = {
    Severity.ROUTINE: 1,
    Severity.URGENT: 2,
    Severity.CRITICAL: 3,
}


class Action(StrEnum):
    """Enum FERMÉ des actions possibles : uniquement des orientations.

    Aucune prescription, aucun médicament, aucun dosage, aucune conduite thérapeutique.
    """

    REFER_COMMUNITY_AGENT = "refer_community_agent"
    """Orienter vers l'agent communautaire (AC)."""
    TRANSFER_COUNSELOR = "transfer_counselor"
    """Transférer vers un conseiller humain."""
    REFER_CSB = "refer_csb"
    """Orienter vers le centre de santé de base (CSB)."""
    REFER_REFERENCE_FACILITY = "refer_reference_facility"
    """Orienter vers une structure de référence."""


class MatchMode(StrEnum):
    """Logique de combinaison des conditions d'une règle."""

    ANY = "any"
    ALL = "all"


class GovernedDocument(_Model):
    """Métadonnées de gouvernance communes (jeu de règles, référentiel de signes)."""

    version: SemVer
    status: Status
    validated_by: NonEmptyText | None = None
    validated_at: date | None = None
    source: NonEmptyText
    language: LanguageTag

    @property
    def is_demo(self) -> bool:
        """Vrai si le document n'est pas validé cliniquement."""
        return self.status is not Status.VALIDATED

    @model_validator(mode="after")
    def _check_validation_metadata(self) -> Self:
        if self.status is Status.VALIDATED and (
            self.validated_by is None or self.validated_at is None
        ):
            raise ValueError(
                "un statut 'validated' exige 'validated_by' et 'validated_at' renseignés"
            )
        return self


# --- Référentiel des codes de signes -------------------------------------------------


class SignDefinition(_Model):
    """Définition d'un code de signe normalisé du référentiel."""

    code: SignCode
    modules: Annotated[tuple[Module, ...], Field(min_length=1)]
    label: NonEmptyText

    @model_validator(mode="after")
    def _check_unique_modules(self) -> Self:
        if len(set(self.modules)) != len(self.modules):
            raise ValueError(f"modules dupliqués pour le signe {self.code}")
        return self


class SignCatalog(GovernedDocument):
    """Référentiel versionné des codes de signes (liste fermée, exigence F-07)."""

    catalog_id: Identifier
    signs: Annotated[tuple[SignDefinition, ...], Field(min_length=1)]

    @model_validator(mode="after")
    def _check_unique_codes(self) -> Self:
        codes = [s.code for s in self.signs]
        duplicates = sorted({c for c in codes if codes.count(c) > 1})
        if duplicates:
            raise ValueError(f"codes de signes dupliqués : {', '.join(duplicates)}")
        return self

    def codes_for(self, module: Module) -> frozenset[str]:
        """Codes de signes connus pour un module donné."""
        return frozenset(s.code for s in self.signs if module in s.modules)


# --- Jeu de règles -------------------------------------------------------------------


class ContextRequirement(_Model):
    """Restriction optionnelle d'une règle selon un contexte minimal.

    Un contexte INCONNU ne supprime jamais une règle (principe de prudence).
    """

    pregnant: StrictBool | None = None


class Conditions(_Model):
    """Conditions d'une règle, exprimées uniquement par des codes de signes."""

    match: MatchMode
    signs: Annotated[tuple[SignCode, ...], Field(min_length=1)]
    context: ContextRequirement = ContextRequirement()

    @model_validator(mode="after")
    def _check_unique_signs(self) -> Self:
        if len(set(self.signs)) != len(self.signs):
            raise ValueError("codes de signes dupliqués dans les conditions")
        return self


class ResponseDelay(_Model):
    """Délai de réponse attendu pour l'alerte.

    En démonstration, ``is_placeholder`` est vrai et aucun délai chiffré n'est donné :
    seul le responsable clinique peut fixer un délai réel.
    """

    is_placeholder: StrictBool
    target_minutes: Annotated[StrictInt, Field(gt=0)] | None = None

    @model_validator(mode="after")
    def _check_consistency(self) -> Self:
        if self.is_placeholder and self.target_minutes is not None:
            raise ValueError("un délai placeholder ne doit pas porter de valeur chiffrée")
        if not self.is_placeholder and self.target_minutes is None:
            raise ValueError("un délai non placeholder exige 'target_minutes'")
        return self


class Rule(_Model):
    """Règle déterministe : signes → sévérité, orientation et code de message."""

    id: RuleId
    version: SemVer
    module: Module
    conditions: Conditions
    severity: Severity
    action: Action
    message_code: MessageCode
    response_delay: ResponseDelay | None = None

    @model_validator(mode="after")
    def _check_delay_required(self) -> Self:
        if self.severity is not Severity.ROUTINE and self.response_delay is None:
            raise ValueError(f"la règle {self.id} ({self.severity}) exige un 'response_delay'")
        return self


class CatalogReference(_Model):
    """Référence au référentiel de signes utilisé par le jeu de règles."""

    catalog_id: Identifier
    version: SemVer


class Ruleset(GovernedDocument):
    """Jeu de règles versionné."""

    ruleset_id: Identifier
    sign_catalog: CatalogReference
    min_detection_confidence: Annotated[float, Field(ge=0.0, le=1.0)]
    fallback_message_code: MessageCode
    rules: Annotated[tuple[Rule, ...], Field(min_length=1)]

    @model_validator(mode="after")
    def _check_rules(self) -> Self:
        ids = [r.id for r in self.rules]
        duplicates = sorted({i for i in ids if ids.count(i) > 1})
        if duplicates:
            raise ValueError(f"identifiants de règles dupliqués : {', '.join(duplicates)}")
        if self.status is Status.VALIDATED:
            placeholders = sorted(
                r.id
                for r in self.rules
                if r.response_delay is not None and r.response_delay.is_placeholder
            )
            if placeholders:
                raise ValueError(
                    "un jeu 'validated' ne peut contenir de délai placeholder : "
                    + ", ".join(placeholders)
                )
        return self

    def rules_for(self, module: Module) -> tuple[Rule, ...]:
        """Règles applicables à un module, triées par identifiant (déterminisme)."""
        return tuple(sorted((r for r in self.rules if r.module is module), key=lambda r: r.id))
