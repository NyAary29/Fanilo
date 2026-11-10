"""Configuration du service IA, lue uniquement dans l'environnement (préfixe FANILO_AI_)."""

from enum import StrEnum
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

SERVICE_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LEXICON_PATH = SERVICE_ROOT / "lexicons" / "intents.demo.yaml"

# Types MIME acceptés par défaut. Les paramètres (ex. "; codecs=opus") sont ignorés.
DEFAULT_ALLOWED_MIME_TYPES = [
    "audio/wav",
    "audio/x-wav",
    "audio/wave",
    "audio/vnd.wave",
    "audio/ogg",
    "audio/opus",
    "audio/webm",
    "audio/mpeg",
    "audio/mp4",
    "audio/x-m4a",
    "audio/flac",
]


class AsrBackendName(StrEnum):
    NONE = "none"
    WHISPER = "whisper"  # TransformersWhisperBackend
    CTC = "ctc"  # CtcBackend (wav2vec2 / XLS-R / w2v-BERT / MMS-like)
    OPENAI = "openai"  # API OpenAI (gpt-4o-transcribe), secours local facultatif


class NluBackendName(StrEnum):
    LEXICON = "lexicon"  # mots-clés (baseline, hors ligne)
    OPENAI = "openai"  # GPT contraint à une liste fermée, secours lexical


# Modèles suggérés par backend. Aucun n'est sous licence non commerciale (voir README,
# section « Choix du modèle par défaut », et docs/ia/benchmark-asr-malgache.md).
# Ces suggestions ne sont PAS des modèles évalués par FANILO : aucune performance n'est
# revendiquée tant que le protocole d'évaluation n'a pas été conduit sur un corpus FANILO.
DEFAULT_MODELS: dict[AsrBackendName, str] = {
    AsrBackendName.WHISPER: "waxal-benchmarking/whisper-small-waxal-mlg",  # CC-BY-4.0
    AsrBackendName.CTC: "Flo976/w2v-bert-malagasy",  # CC-BY-4.0 (réserve sur les données)
}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="FANILO_AI_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "FANILO AI"
    version: str = "0.1.0"
    log_level: str = "INFO"
    enable_docs: bool = False

    # --- ASR -------------------------------------------------------------------------
    asr_backend: AsrBackendName = AsrBackendName.NONE
    # Nom du modèle Hugging Face ; vide = modèle suggéré du backend (DEFAULT_MODELS).
    asr_model: str = ""
    # Révision (commit ou tag) du modèle, à épingler en production pour la traçabilité.
    asr_model_revision: str | None = None
    # "cpu", "cuda", "cuda:0"...
    asr_device: str = "cpu"
    # Taux d'échantillonnage cible du décodage ffmpeg.
    asr_sampling_rate: int = Field(default=16_000, ge=8_000, le=48_000)

    # --- OpenAI (facultatif) ------------------------------------------------------
    # Clé API : à mettre dans .env, jamais dans le code ni dans un commit.
    openai_api_key: SecretStr | None = None
    openai_base_url: str = "https://api.openai.com/v1"
    openai_asr_model: str = "gpt-4o-transcribe"
    openai_nlu_model: str = "gpt-4o-mini"
    # Court : en cas d'échec, le secours local doit encore tenir dans le délai de l API.
    openai_timeout_seconds: float = Field(default=15.0, gt=0, le=120)
    # Secours local si OpenAI échoue (réseau, quota) : whisper, ctc ou none.
    openai_asr_fallback: AsrBackendName = AsrBackendName.WHISPER
    nlu_backend: NluBackendName = NluBackendName.LEXICON

    # --- Limites audio ---------------------------------------------------------------
    max_audio_bytes: int = Field(default=5 * 1024 * 1024, ge=1_024, le=50 * 1024 * 1024)
    max_audio_seconds: float = Field(default=60.0, gt=0, le=600)
    allowed_mime_types: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: list(DEFAULT_ALLOWED_MIME_TYPES)
    )

    # --- Classifieur -----------------------------------------------------------------
    intent_lexicon_path: Path = DEFAULT_LEXICON_PATH
    max_text_chars: int = Field(default=2_000, ge=1, le=20_000)

    @field_validator("allowed_mime_types", mode="before")
    @classmethod
    def _split_mime_types(cls, value: object) -> object:
        if isinstance(value, str):
            return [item.strip().lower() for item in value.split(",") if item.strip()]
        return value

    @property
    def resolved_asr_model(self) -> str | None:
        if self.asr_backend is AsrBackendName.NONE:
            return None
        if self.asr_backend is AsrBackendName.OPENAI:
            return self.openai_asr_model
        return self.asr_model or DEFAULT_MODELS[self.asr_backend]


@lru_cache
def get_settings() -> Settings:
    return Settings()
