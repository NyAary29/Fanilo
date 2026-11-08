"""Base déclarative et mixin commun pour la synchronisation hors ligne (F-10).

Toute entité susceptible d'être créée ou modifiée hors ligne (application de
l'agent communautaire) hérite de :class:`SyncMixin` :

- ``id`` : UUID générable côté client, pour créer un enregistrement sans réseau ;
- ``created_at`` / ``updated_at`` : horodatages UTC ;
- ``version`` : entier incrémenté automatiquement à chaque UPDATE (verrou
  optimiste SQLAlchemy ``version_id_col``). Un client qui envoie une
  modification basée sur une version périmée provoque un conflit détectable ;
- ``deleted_at`` : suppression logique, pour propager les suppressions aux
  appareils lors de la synchronisation.

Les entités **distribuées par** ``/sync/pull`` héritent en plus de
:class:`SyncSequenced` : colonne ``sync_seq`` (voir ci-dessous).

Séquence de modification ``sync_seq`` (curseur de synchronisation)
------------------------------------------------------------------

Chaque INSERT ou UPDATE d'une entité :class:`SyncSequenced` reçoit, au flush,
une valeur ``sync_seq`` strictement croissante, tirée d'un **compteur
transactionnel** (table ``sync_counter``, une seule ligne), identique sur
PostgreSQL et SQLite :

    UPDATE sync_counter SET value = value + n WHERE id = 1;
    SELECT value FROM sync_counter WHERE id = 1;

Pourquoi pas une ``SEQUENCE`` PostgreSQL : ``nextval`` n'est pas
transactionnel. Une transaction longue qui obtient 10, puis valide après une
transaction courte qui a obtenu 11, ferait manquer la ligne 10 à un client
dont le curseur est déjà à 11. Avec le compteur, la mise à jour de la ligne
``sync_counter`` pose un verrou de ligne (PostgreSQL) ou le verrou d'écriture
de la base (SQLite) **jusqu'à la fin de la transaction** : les valeurs sont
attribuées dans l'ordre de validation, et une valeur lue (validée) ``H``
garantit que toutes les lignes de ``sync_seq <= H`` sont déjà visibles.
Le pull lit ``H`` d'abord et ne renvoie que ``sync_seq <= H``.

Contrepartie : les transactions qui écrivent des entités synchronisables sont
sérialisées entre leur premier flush et leur validation (acceptable aux
volumes de P0 ; les transactions concernées sont courtes et ne font aucun appel
réseau après leur premier flush). Les mises à jour en masse
(``session.execute(update(...))``) contournent l'ORM et sont donc interdites
sur ces tables.
"""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    DDL,
    BigInteger,
    Integer,
    MetaData,
    Uuid,
    event,
    select,
    update,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, declared_attr, mapped_column

from app.db.types import UTCDateTime, utcnow

# Conventions de nommage explicites : migrations Alembic stables et lisibles.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


class SyncMixin:
    """Colonnes communes aux entités synchronisables hors ligne."""

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime, default=utcnow, onupdate=utcnow, nullable=False
    )
    version: Mapped[int] = mapped_column(nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(UTCDateTime, nullable=True)

    @declared_attr.directive
    def __mapper_args__(cls) -> dict[str, Any]:  # noqa: N805
        # SQLAlchemy initialise version à 1 à l'INSERT, l'incrémente à chaque
        # UPDATE et lève StaleDataError si la ligne a changé entre-temps.
        return {"version_id_col": cls.version}

    @property
    def is_deleted(self) -> bool:
        return self.deleted_at is not None

    def soft_delete(self) -> None:
        """Marque l'enregistrement comme supprimé sans l'effacer physiquement."""
        if self.deleted_at is None:
            self.deleted_at = utcnow()


class SyncSequenced:
    """Entité distribuée par ``/sync/pull`` : porte la séquence ``sync_seq``.

    La valeur est attribuée automatiquement au flush (voir l'en-tête du module) ;
    elle ne doit jamais être renseignée à la main.
    """

    sync_seq: Mapped[int] = mapped_column(BigInteger, nullable=False, unique=True, index=True)


class SyncCounter(Base):
    """Compteur transactionnel unique (``id = 1``) alimentant ``sync_seq``."""

    __tablename__ = "sync_counter"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    value: Mapped[int] = mapped_column(BigInteger, nullable=False)


SYNC_COUNTER_ID = 1

# Ligne unique créée avec la table (``create_all`` des tests ; la migration 0003
# l'insère elle-même).
event.listen(
    SyncCounter.__table__,
    "after_create",
    DDL("INSERT INTO sync_counter (id, value) VALUES (1, 0)"),
)


def allocate_sync_seq(session: Session, count: int) -> int:
    """Réserve ``count`` valeurs consécutives ; renvoie la dernière.

    Verrouille la ligne du compteur jusqu'à la fin de la transaction courante.
    """
    table = SyncCounter.__table__
    conn = session.connection()
    result = conn.execute(
        update(table)
        .where(table.c.id == SYNC_COUNTER_ID)
        .values(value=table.c.value + count)
    )
    if result.rowcount != 1:
        raise RuntimeError("Compteur sync_counter absent : base non migrée ?")
    value = conn.execute(select(table.c.value).where(table.c.id == SYNC_COUNTER_ID)).scalar_one()
    return int(value)


def current_sync_seq(session: Session) -> int:
    """Dernière valeur validée du compteur (borne haute sûre pour un pull)."""
    table = SyncCounter.__table__
    value = session.execute(
        select(table.c.value).where(table.c.id == SYNC_COUNTER_ID)
    ).scalar_one_or_none()
    return int(value or 0)


def _table_order() -> dict[str, int]:
    # Ordre des dépendances (parents avant enfants) : à l'intérieur d'un même
    # flush, une bénéficiaire reçoit une valeur inférieure à sa grossesse.
    return {table.name: index for index, table in enumerate(Base.metadata.sorted_tables)}


@event.listens_for(Session, "before_flush")
def _assign_sync_seq(session: Session, _flush_context: Any, _instances: Any) -> None:
    pending = [obj for obj in session.new if isinstance(obj, SyncSequenced)]
    pending += [
        obj
        for obj in session.dirty
        if isinstance(obj, SyncSequenced)
        and obj not in session.deleted
        and session.is_modified(obj, include_collections=False)
    ]
    if not pending:
        return
    order = _table_order()
    pending.sort(key=lambda obj: (order.get(obj.__table__.name, 0), str(obj.id or "")))
    last = allocate_sync_seq(session, len(pending))
    for offset, obj in enumerate(pending):
        obj.sync_seq = last - len(pending) + 1 + offset
