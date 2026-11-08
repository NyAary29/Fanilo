"""Registre des entités synchronisables.

Chaque entité déclare : son modèle, une requête « dans le périmètre » (lignes
supprimées comprises, pour propager les suppressions), sa sérialisation, les
rôles autorisés en lecture et en écriture, et ses opérations d'écriture
(``None`` = lecture seule, ex. ``alert``).

Entités enregistrées (voir ``entities.py``) : ``site`` (lecture seule),
``beneficiary``, ``beneficiary_identity``, ``consent``, ``pregnancy``,
``anc_visit``, ``alert`` (lecture seule) et ``referral``. Rangs utilisés :
5, 10, 20, 30, 40, 50, 60, 70.

Le modèle doit hériter de :class:`app.db.base.SyncSequenced` : le pull ordonne
et pagine par ``sync_seq`` ; le rang ne sert qu'à départager (jamais en
pratique, ``sync_seq`` étant unique) et à documenter l'ordre parent → enfant.

Une entité non enregistrée est refusée au push (``rejected``) et absente du pull.
"""

import uuid
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any, Protocol

from sqlalchemy import Select

from app.db.base import SyncSequenced
from app.modules.sites.scope import ActorContext, SiteScope
from app.modules.users.roles import Role


class PushOperations(Protocol):
    """Écritures d'une entité. Les fonctions appliquent rôle, périmètre et audit
    (en réutilisant les services métier) et lèvent des ``DomainError``."""

    def create(self, ctx: ActorContext, entity_id: uuid.UUID, data: dict[str, Any]) -> Any: ...

    def update(
        self, ctx: ActorContext, obj: Any, data: dict[str, Any], base_version: int
    ) -> Any: ...

    def delete(self, ctx: ActorContext, obj: Any) -> None: ...


@dataclass(frozen=True)
class SyncEntity:
    name: str
    model: type
    # Départage stable entre entités (parents avant enfants).
    rank: int
    scoped_select: Callable[[SiteScope], Select]
    serialize: Callable[[ActorContext, Any], dict[str, Any]]
    # None : tout utilisateur authentifié (dans son périmètre).
    pull_roles: frozenset[Role] | None
    push: PushOperations | None
    push_roles: frozenset[Role] = frozenset()
    # Entité nominative : lecture auditée, résultat stocké chiffré.
    nominative: bool = False
    on_pull: Callable[[ActorContext, Any], None] | None = None


REGISTRY: dict[str, SyncEntity] = {}


def register_sync_entity(entity: SyncEntity) -> None:
    if not issubclass(entity.model, SyncSequenced):
        raise TypeError(f"{entity.name} : le modèle doit hériter de SyncSequenced (sync_seq).")
    if entity.name in REGISTRY:
        raise ValueError(f"Entité de synchronisation déjà enregistrée : {entity.name}")
    if any(e.rank == entity.rank for e in REGISTRY.values()):
        raise ValueError(f"Rang de synchronisation déjà utilisé : {entity.rank}")
    REGISTRY[entity.name] = entity
