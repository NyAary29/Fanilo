"""Configuration versionnée des réponses informatives et des menus vocaux.

Fichier YAML (``config/information.demo.yaml`` par défaut) qui associe :

- une **intention** proposée par le classifieur (service IA) à un **code de
  contenu** approuvé (``MSG_...``), par module ;
- une **touche de menu vocal** (IVR/USSD, simulateur) à un code de contenu.

Ce fichier relève du responsable clinique au même titre que les contenus : il
porte un ``status``. Politique de chargement alignée sur les autres
référentiels : ``validated`` est toujours servi ; tout autre statut seulement si
``FANILO_ALLOW_DEMO_CONTENT=true`` ; sinon la configuration est ignorée (toute
question informative part en transfert au conseiller).

Le moteur de règles garde la priorité : une intention n'est utilisée que si
aucun signe n'est détecté et qu'aucune règle n'est déclenchée.
"""

import logging
from functools import lru_cache
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

logger = logging.getLogger("fanilo.information")

Status = Literal["demo", "draft", "in_review", "validated"]
ModuleName = Literal["reny", "tanora"]
MESSAGE_CODE = r"^MSG_[A-Z0-9_]+$"


class InformationConfigError(Exception):
    """Fichier absent ou invalide."""


class IntentAnswer(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    intent: str = Field(pattern=r"^[a-z][a-z0-9_]*$", max_length=64)
    modules: tuple[ModuleName, ...] = Field(min_length=1)
    message_code: str = Field(pattern=MESSAGE_CODE)


class MenuItem(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    key: int = Field(ge=1, le=9)
    message_code: str = Field(pattern=MESSAGE_CODE)


class InformationConfig(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    config_id: str = Field(min_length=1)
    version: str = Field(pattern=r"^\d+\.\d+\.\d+$")
    status: Status
    source: str = Field(min_length=1)
    validated_by: str | None = None
    validated_at: str | None = None
    # Confiance minimale du classifieur pour répondre sans humain.
    min_intent_confidence: float = Field(ge=0.0, le=1.0)
    # Modules dont TOUTE réponse est soumise à confirmation d'un conseiller
    # (protocole TANORA : « confirmation par un conseiller selon le protocole retenu »).
    counselor_confirmation_modules: tuple[ModuleName, ...] = ()
    intent_answers: tuple[IntentAnswer, ...] = ()
    menus: dict[ModuleName, tuple[MenuItem, ...]] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _unique(self) -> "InformationConfig":
        seen: set[tuple[str, str]] = set()
        for answer in self.intent_answers:
            for module in answer.modules:
                if (answer.intent, module) in seen:
                    raise ValueError(f"Intention en double : {answer.intent} ({module}).")
                seen.add((answer.intent, module))
        for module, items in self.menus.items():
            keys = [i.key for i in items]
            if len(keys) != len(set(keys)):
                raise ValueError(f"Touche de menu en double ({module}).")
        return self

    @property
    def is_demo(self) -> bool:
        return self.status != "validated"

    def answer_code(self, intent: str | None, module: str) -> str | None:
        if not intent:
            return None
        for answer in self.intent_answers:
            if answer.intent == intent and module in answer.modules:
                return answer.message_code
        return None

    def requires_counselor(self, module: str) -> bool:
        return module in self.counselor_confirmation_modules


@lru_cache(maxsize=8)
def _parse(path: Path, mtime_ns: int) -> InformationConfig:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        return InformationConfig.model_validate(raw)
    except (OSError, yaml.YAMLError, ValidationError) as exc:
        raise InformationConfigError(f"Configuration d'information invalide : {exc}") from exc


def load_information_config(path: Path) -> InformationConfig:
    try:
        mtime = path.stat().st_mtime_ns
    except OSError as exc:
        raise InformationConfigError(f"Fichier introuvable : {path.name}.") from exc
    return _parse(path, mtime)


def served_information_config(path: Path, *, allow_demo: bool) -> InformationConfig | None:
    """Configuration utilisable, ou ``None`` (absente, invalide ou non validée)."""
    try:
        config = load_information_config(path)
    except InformationConfigError as exc:
        logger.error("information_config_unavailable", extra={"reason": str(exc)[:300]})
        return None
    if config.status != "validated" and not allow_demo:
        return None
    return config
