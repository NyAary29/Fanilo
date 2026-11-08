"""Fixtures communes : chemins des fichiers de démonstration et fabrique de YAML."""

from __future__ import annotations

import copy
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
import yaml

from fanilo_rules import RuleEngine

DEMO_DIR = Path(__file__).resolve().parents[1] / "rulesets" / "demo"
DEMO_RULESET = DEMO_DIR / "reny_danger_signs.demo.yaml"
DEMO_CATALOG = DEMO_DIR / "sign_codes.demo.yaml"


@pytest.fixture
def ruleset_data() -> dict[str, Any]:
    """Copie modifiable du jeu de règles de démonstration."""
    return copy.deepcopy(yaml.safe_load(DEMO_RULESET.read_text(encoding="utf-8")))


@pytest.fixture
def catalog_data() -> dict[str, Any]:
    """Copie modifiable du référentiel de démonstration."""
    return copy.deepcopy(yaml.safe_load(DEMO_CATALOG.read_text(encoding="utf-8")))


@pytest.fixture
def write_yaml(tmp_path: Path) -> Callable[[Any, str], Path]:
    """Écrit un objet (ou un texte brut) en YAML dans un fichier temporaire."""

    def _write(data: Any, name: str = "doc.yaml") -> Path:
        path = tmp_path / name
        text = data if isinstance(data, str) else yaml.safe_dump(data, allow_unicode=True)
        path.write_text(text, encoding="utf-8")
        return path

    return _write


@pytest.fixture
def engine() -> RuleEngine:
    """Moteur chargé avec les fichiers de démonstration."""
    return RuleEngine.from_files(DEMO_RULESET, DEMO_CATALOG, allow_demo=True)
