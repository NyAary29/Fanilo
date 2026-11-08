"""FANILO — moteur de règles déterministe (signes de danger et orientation).

Ce paquet ne dépend d'aucune bibliothèque d'IA, d'aucun framework web ni d'aucune base
de données. Il ne diagnostique pas et ne prescrit pas : il produit uniquement des
orientations issues d'une liste fermée et des codes de messages validés.
"""

from .evaluator import (
    EvaluationContext,
    EvaluationInput,
    EvaluationResult,
    FallbackReason,
    RuleEngine,
    TraceStep,
    TriggeredRule,
)
from .loader import (
    RulesError,
    RulesetPolicyError,
    RulesetValidationError,
    load_ruleset,
    load_sign_catalog,
)
from .schema import Action, MatchMode, Module, Rule, Ruleset, Severity, SignCatalog, Status

__all__ = [
    "Action",
    "EvaluationContext",
    "EvaluationInput",
    "EvaluationResult",
    "FallbackReason",
    "MatchMode",
    "Module",
    "Rule",
    "RuleEngine",
    "Ruleset",
    "RulesError",
    "RulesetPolicyError",
    "RulesetValidationError",
    "Severity",
    "SignCatalog",
    "Status",
    "TraceStep",
    "TriggeredRule",
    "load_ruleset",
    "load_sign_catalog",
]
