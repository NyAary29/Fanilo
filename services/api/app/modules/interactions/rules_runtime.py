"""Chargement du moteur de règles (``services/rules``) au démarrage de l'API.

Le moteur est chargé **une fois**, avec ``allow_demo=settings.allow_demo_content``
(en production, seuls un jeu de règles et un référentiel ``validated`` sont
acceptés). Si aucun jeu chargeable n'existe, l'API démarre quand même :
``/interactions/ask`` répond alors toujours en fallback (transfert au
conseiller), et l'anomalie est journalisée à chaque question.

Le référentiel de codes de signes est conservé séparément : il reste servi par
``/reference/sign-codes`` même si le jeu de règles est refusé.
"""

import logging
from dataclasses import dataclass

from fanilo_rules import RuleEngine, RulesError, SignCatalog, load_sign_catalog
from fastapi import Request

from app.core.config import Settings

logger = logging.getLogger("fanilo.rules")


@dataclass(frozen=True)
class RulesRuntime:
    engine: RuleEngine | None
    catalog: SignCatalog | None
    error: str | None = None


def load_rules_runtime(settings: Settings) -> RulesRuntime:
    allow_demo = settings.allow_demo_content
    try:
        engine = RuleEngine.from_files(
            settings.rules_ruleset_path, settings.rules_sign_catalog_path, allow_demo=allow_demo
        )
    except RulesError as exc:
        logger.error("rules_engine_unavailable", extra={"reason": str(exc)[:500]})
        try:
            catalog = load_sign_catalog(settings.rules_sign_catalog_path, allow_demo=allow_demo)
        except RulesError:
            catalog = None
        return RulesRuntime(engine=None, catalog=catalog, error=str(exc))
    logger.info(
        "rules_engine_loaded",
        extra={
            "ruleset_id": engine.ruleset.ruleset_id,
            "ruleset_version": engine.ruleset.version,
            "is_demo": engine.is_demo,
        },
    )
    return RulesRuntime(engine=engine, catalog=engine.catalog)


def get_rules_runtime(request: Request) -> RulesRuntime:
    """Dépendance FastAPI : moteur chargé au démarrage (``app.state.rules``)."""
    return request.app.state.rules
