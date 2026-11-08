"""Chargement sécurisé des fichiers YAML (jeux de règles et référentiels de signes).

Politique de chargement :
- ``allow_demo=False`` (production) : seuls les documents au statut ``validated`` sont
  acceptés, pour le jeu de règles ET pour le référentiel de signes ;
- ``allow_demo=True`` (développement, démonstration) : tout statut est accepté sauf
  ``retired`` ;
- un document ``retired`` est toujours refusé.

Le paramètre ``allow_demo`` est obligatoire et nommé : il n'existe aucune valeur par
défaut implicite.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, ValidationError

from .schema import GovernedDocument, Ruleset, SignCatalog, Status


class RulesError(Exception):
    """Erreur de base du moteur de règles."""


class RulesetValidationError(RulesError):
    """Fichier YAML illisible ou non conforme au schéma."""


class RulesetPolicyError(RulesError):
    """Document conforme mais refusé par la politique de chargement."""


class _UniqueKeySafeLoader(yaml.SafeLoader):
    """SafeLoader qui refuse les clés dupliquées (PyYAML garde sinon la dernière)."""


def _construct_mapping(loader: _UniqueKeySafeLoader, node: yaml.MappingNode) -> dict[Any, Any]:
    keys: set[Any] = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=True)
        if key in keys:
            raise yaml.constructor.ConstructorError(
                None, None, f"clé dupliquée : {key!r}", key_node.start_mark
            )
        keys.add(key)
    return loader.construct_mapping(node, deep=True)


_UniqueKeySafeLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_mapping
)


def _read_yaml(path: Path) -> Any:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise RulesetValidationError(f"lecture impossible de {path} : {exc}") from exc
    try:
        return yaml.load(text, Loader=_UniqueKeySafeLoader)  # noqa: S506 (SafeLoader dérivé)
    except yaml.YAMLError as exc:
        raise RulesetValidationError(f"YAML invalide dans {path} : {exc}") from exc


def _parse[T: BaseModel](model: type[T], path: Path) -> T:
    data = _read_yaml(path)
    if not isinstance(data, dict):
        raise RulesetValidationError(f"{path} : le document YAML doit être un objet")
    try:
        return model.model_validate(data)
    except ValidationError as exc:
        raise RulesetValidationError(f"{path} : schéma invalide\n{exc}") from exc


def check_policy(document: GovernedDocument, *, allow_demo: bool, label: str) -> None:
    """Applique la politique de chargement à un document gouverné."""
    if document.status is Status.RETIRED:
        raise RulesetPolicyError(f"{label} : statut 'retired', chargement refusé")
    if not allow_demo and document.status is not Status.VALIDATED:
        raise RulesetPolicyError(
            f"{label} : statut '{document.status}' refusé en production "
            "(seul 'validated' est accepté ; allow_demo=False)"
        )


def load_sign_catalog(path: str | Path, *, allow_demo: bool) -> SignCatalog:
    """Charge et valide un référentiel de codes de signes."""
    catalog = _parse(SignCatalog, Path(path))
    check_policy(catalog, allow_demo=allow_demo, label=f"référentiel {catalog.catalog_id}")
    return catalog


def load_ruleset(path: str | Path, *, allow_demo: bool) -> Ruleset:
    """Charge et valide un jeu de règles (sans contrôle croisé avec le référentiel)."""
    ruleset = _parse(Ruleset, Path(path))
    check_policy(ruleset, allow_demo=allow_demo, label=f"jeu de règles {ruleset.ruleset_id}")
    return ruleset
