"""Types de colonnes portables PostgreSQL / SQLite."""

from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import DateTime, Enum
from sqlalchemy.engine import Dialect
from sqlalchemy.types import TypeDecorator


class UTCDateTime(TypeDecorator[datetime]):
    """Horodatage toujours en UTC et toujours « aware ».

    PostgreSQL stocke un ``timestamptz`` ; SQLite (tests) ne conserve pas le
    fuseau : on le réapplique à la lecture pour que les comparaisons restent
    valides quel que soit le moteur.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("Les horodatages doivent porter un fuseau horaire (UTC).")
        return value.astimezone(UTC)

    def process_result_value(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


def utcnow() -> datetime:
    return datetime.now(UTC)


def str_enum(enum_cls: type[StrEnum], name: str, length: int = 32) -> Enum:
    """Enum portable : VARCHAR + contrainte CHECK (pas de type natif PostgreSQL),
    valeurs stockées = valeurs de l'enum Python."""
    return Enum(
        enum_cls,
        name=name,
        native_enum=False,
        create_constraint=True,
        length=length,
        values_callable=lambda enum: [member.value for member in enum],
    )
