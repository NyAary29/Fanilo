"""Configuration de l'API, chargée exclusivement depuis l'environnement.

Aucun secret n'est codé en dur : les valeurs par défaut ne sont acceptables
qu'en développement et sont refusées au démarrage en production.
"""

import logging
from enum import StrEnum
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

_INSECURE_SECRET_DEFAULTS = {"", "change-me-dev-only", "changeme", "secret"}
_MIN_SECRET_LENGTH = 32
API_DIR = Path(__file__).resolve().parents[2]
DEFAULT_ANC_SCHEDULE_PATH = API_DIR / "config" / "anc_schedule.demo.yaml"
DEFAULT_CONTENTS_DEMO_PATH = API_DIR / "config" / "contents.demo.yaml"
DEFAULT_CONSENT_INFORMATION_PATH = API_DIR / "config" / "consent_information.demo.yaml"
# Jeu de règles et référentiel de DÉMONSTRATION de services/rules (dépôt).
_DEMO_RULESETS_DIR = API_DIR.parent / "rules" / "rulesets" / "demo"
DEFAULT_RULESET_PATH = _DEMO_RULESETS_DIR / "reny_danger_signs.demo.yaml"
DEFAULT_SIGN_CATALOG_PATH = _DEMO_RULESETS_DIR / "sign_codes.demo.yaml"

logger = logging.getLogger("fanilo.config")


class Environment(StrEnum):
    DEVELOPMENT = "development"
    TEST = "test"
    PRODUCTION = "production"


class LogFormat(StrEnum):
    JSON = "json"
    TEXT = "text"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="FANILO_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "FANILO API"
    version: str = "0.1.0"
    environment: Environment = Environment.DEVELOPMENT

    # Valeur de développement uniquement : refusée au démarrage en production.
    secret_key: str = "change-me-dev-only"  # noqa: S105

    log_level: str = "INFO"
    log_format: LogFormat = LogFormat.JSON

    cors_origins: Annotated[list[str], NoDecode] = Field(default_factory=list)
    enable_docs: bool | None = None

    # Contenus de démonstration NON validés cliniquement (voir docs/securite-medicale.md).
    allow_demo_content: bool = False

    # Base de données (lot P0.2). Aucun mot de passe par défaut : en local, le
    # définir via FANILO_DATABASE_URL (voir .env.example).
    database_url: str = "postgresql+psycopg://fanilo@localhost:5432/fanilo"
    database_echo: bool = False

    # Authentification (lot P0.3).
    access_token_ttl_minutes: int = Field(default=15, ge=1, le=60)
    refresh_token_ttl_days: int = Field(default=30, ge=1, le=90)
    # Limitation des tentatives de connexion (en mémoire, par instance).
    login_max_attempts: int = Field(default=5, ge=1)
    login_window_seconds: int = Field(default=300, ge=1)

    # Chiffrement des colonnes nominatives (lot P0.5). Clé(s) Fernet, séparées par
    # des virgules pour une rotation. Obligatoire en production ; en
    # développement et en test, une clé éphémère est générée (données illisibles
    # après redémarrage).
    data_encryption_key: SecretStr | None = None

    # Calendrier CPN configuré (lot P0.7), jamais codé en dur.
    anc_schedule_path: Path = DEFAULT_ANC_SCHEDULE_PATH

    # Moteur de règles (services/rules), chargé une fois au démarrage avec
    # allow_demo=allow_demo_content. Absent ou refusé : /interactions/ask répond
    # toujours en fallback (transfert au conseiller).
    rules_ruleset_path: Path = DEFAULT_RULESET_PATH
    rules_sign_catalog_path: Path = DEFAULT_SIGN_CATALOG_PATH
    # Code de message de repli utilisé seulement si aucun jeu de règles n'est
    # chargé (sinon : fallback_message_code du jeu de règles).
    fallback_message_code: str | None = Field(default=None, pattern=r"^MSG_[A-Z0-9_]+$")

    # Service IA interne (services/ai) : délai maximal court, échec => fallback.
    ai_service_url: str = "http://localhost:8001"
    ai_timeout_seconds: float = Field(default=5.0, gt=0, le=30)
    # Même limite que le service IA (FANILO_AI_MAX_AUDIO_BYTES) ; l'audio est
    # relayé en mémoire et jamais écrit sur disque.
    ai_max_audio_bytes: int = Field(default=5 * 1024 * 1024, ge=1_024, le=50 * 1024 * 1024)

    # Délai de réponse d'une alerte quand la règle ne porte qu'un délai
    # PLACEHOLDER (jeux de démonstration). Valeur de DÉMONSTRATION, non clinique.
    alert_demo_response_minutes: int = Field(default=60, ge=1, le=7 * 24 * 60)

    # Information présentée lors du consentement (fichier versionné).
    consent_information_path: Path = DEFAULT_CONSENT_INFORMATION_PATH

    @model_validator(mode="before")
    @classmethod
    def _split_cors(cls, data: dict) -> dict:
        raw = data.get("cors_origins") if isinstance(data, dict) else None
        if isinstance(raw, str):
            data["cors_origins"] = [o.strip() for o in raw.split(",") if o.strip()]
        return data

    @model_validator(mode="after")
    def _enforce_production_safety(self) -> "Settings":
        if self.environment is Environment.PRODUCTION:
            if (
                self.secret_key in _INSECURE_SECRET_DEFAULTS
                or len(self.secret_key) < _MIN_SECRET_LENGTH
            ):
                raise ValueError(
                    "FANILO_SECRET_KEY doit être défini (>= 32 caractères) en production."
                )
            if self.allow_demo_content:
                raise ValueError(
                    "FANILO_ALLOW_DEMO_CONTENT est interdit en production : "
                    "seuls les contenus validés cliniquement peuvent être servis."
                )
            if "*" in self.cors_origins:
                raise ValueError("FANILO_CORS_ORIGINS='*' est interdit en production.")
            if self.database_url.startswith("sqlite"):
                raise ValueError("FANILO_DATABASE_URL : SQLite est interdit en production.")
        return self

    @model_validator(mode="after")
    def _ensure_data_encryption_key(self) -> "Settings":
        # Import local : app.core.crypto dépend de ce module.
        from cryptography.fernet import Fernet

        from app.core.crypto import parse_keys

        if self.data_encryption_key is None or not parse_keys(
            self.data_encryption_key.get_secret_value()
        ):
            if self.environment is Environment.PRODUCTION:
                raise ValueError(
                    "FANILO_DATA_ENCRYPTION_KEY doit être défini en production "
                    "(clé Fernet, voir .env.example)."
                )
            logger.warning(
                "FANILO_DATA_ENCRYPTION_KEY absente : clé de chiffrement ÉPHÉMÈRE générée "
                "(développement/test uniquement, données nominatives illisibles après "
                "redémarrage)."
            )
            self.data_encryption_key = SecretStr(Fernet.generate_key().decode("ascii"))
            return self
        try:
            for key in parse_keys(self.data_encryption_key.get_secret_value()):
                Fernet(key.encode("ascii"))
        except (ValueError, UnicodeEncodeError) as exc:
            raise ValueError(
                "FANILO_DATA_ENCRYPTION_KEY invalide : clé Fernet attendue "
                "(32 octets encodés en base64 URL)."
            ) from exc
        return self

    @property
    def docs_enabled(self) -> bool:
        if self.enable_docs is not None:
            return self.enable_docs
        return self.environment is not Environment.PRODUCTION


@lru_cache
def get_settings() -> Settings:
    return Settings()
