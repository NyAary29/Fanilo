"""Chargement du calendrier CPN configuré (fichier YAML versionné).

Le calendrier n'est **jamais codé en dur**. Politique de chargement (alignée
sur ``services/rules``) :

- ``retired`` : toujours refusé ;
- ``validated`` : accepté (``validated_by`` et ``validated_at`` obligatoires) ;
- tout autre statut (``demo``, ``draft``, ``in_review``) : accepté seulement si
  ``allow_demo_content`` est vrai (jamais en production).
"""

from datetime import date, timedelta
from enum import StrEnum
from functools import lru_cache
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

from app.core.config import Settings


class ScheduleStatus(StrEnum):
    DEMO = "demo"
    DRAFT = "draft"
    IN_REVIEW = "in_review"
    VALIDATED = "validated"
    RETIRED = "retired"


class ScheduleUnavailableError(Exception):
    """Calendrier absent, invalide ou non autorisé par la politique de chargement."""


class ReminderPolicy(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    days_before: int = Field(ge=0, le=30)
    send_hour_utc: int = Field(ge=0, le=23)
    message_code: str = Field(pattern=r"^MSG_[A-Z0-9_]+$")


class ScheduledVisit(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    sequence: int = Field(ge=1)
    gestational_week: int = Field(ge=1, le=45)


class AncSchedule(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schedule_id: str = Field(min_length=1)
    version: str = Field(pattern=r"^\d+\.\d+\.\d+$")
    status: ScheduleStatus
    source: str = Field(min_length=1)
    validated_by: str | None = None
    validated_at: date | None = None
    pregnancy_duration_days: int = Field(ge=200, le=320)
    reminders: ReminderPolicy
    visits: tuple[ScheduledVisit, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def _check(self) -> "AncSchedule":
        sequences = [v.sequence for v in self.visits]
        if len(set(sequences)) != len(sequences):
            raise ValueError("Numéros de séquence de visite dupliqués.")
        weeks = [v.gestational_week for v in sorted(self.visits, key=lambda v: v.sequence)]
        if weeks != sorted(weeks):
            raise ValueError("Les semaines doivent croître avec la séquence.")
        if self.status is ScheduleStatus.VALIDATED and not (
            self.validated_by and self.validated_at
        ):
            raise ValueError("Un calendrier validé exige validated_by et validated_at.")
        return self

    @property
    def is_demo(self) -> bool:
        return self.status is not ScheduleStatus.VALIDATED

    def reference_lmp(self, lmp_date: date | None, due_date: date | None) -> date | None:
        """Date de référence (dernières règles), déduite si besoin de la date prévue."""
        if lmp_date is not None:
            return lmp_date
        if due_date is not None:
            return due_date - timedelta(days=self.pregnancy_duration_days)
        return None

    def visit_dates(self, lmp: date) -> list[tuple[int, date]]:
        """(séquence, date prévue) pour chaque visite du calendrier."""
        return [
            (v.sequence, lmp + timedelta(weeks=v.gestational_week))
            for v in sorted(self.visits, key=lambda v: v.sequence)
        ]


@lru_cache(maxsize=8)
def _parse(path: Path, mtime_ns: int) -> AncSchedule:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
        return AncSchedule.model_validate(raw)
    except (OSError, yaml.YAMLError, ValidationError) as exc:
        raise ScheduleUnavailableError(f"Calendrier CPN invalide ({path.name}) : {exc}") from exc


def load_schedule(path: Path, *, allow_demo: bool) -> AncSchedule:
    try:
        mtime = path.stat().st_mtime_ns
    except OSError as exc:
        raise ScheduleUnavailableError(f"Calendrier CPN introuvable : {path.name}.") from exc
    schedule = _parse(path, mtime)
    if schedule.status is ScheduleStatus.RETIRED:
        raise ScheduleUnavailableError(
            f"Calendrier CPN {schedule.schedule_id} {schedule.version} retiré : génération refusée."
        )
    if schedule.status is not ScheduleStatus.VALIDATED and not allow_demo:
        raise ScheduleUnavailableError(
            f"Calendrier CPN {schedule.schedule_id} {schedule.version} au statut "
            f"« {schedule.status} », non validé cliniquement : génération refusée "
            "(FANILO_ALLOW_DEMO_CONTENT=false)."
        )
    return schedule


def get_schedule(settings: Settings) -> AncSchedule:
    """Calendrier configuré, selon la politique de l'environnement."""
    return load_schedule(settings.anc_schedule_path, allow_demo=settings.allow_demo_content)
