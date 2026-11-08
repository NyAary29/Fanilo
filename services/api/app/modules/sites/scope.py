"""Périmètre par site : helper réutilisable par tous les modules.

Règle (contrat, conventions) : un utilisateur rattaché à un site voit les
données de son site **et de tous ses sites descendants**. ``admin``,
``clinical_lead`` et ``data_officer`` ont une vue globale. Un utilisateur non
global sans site ne voit rien.

Usage ::

    from app.modules.sites.scope import SiteScope, get_site_scope

    @router.get("/alerts")
    def list_alerts(scope: SiteScope = Depends(get_site_scope), db=Depends(get_db)):
        stmt = select(Alert).join(Beneficiary).where(scope.filter(Beneficiary.site_id))
        ...

    # Contrôle d'un objet isolé (404 hors périmètre, on ne révèle pas l'existence) :
    scope.ensure_contains(beneficiary.site_id)

Hors FastAPI : ``compute_site_scope(session, user)``.
"""

import uuid
from collections import defaultdict, deque
from dataclasses import dataclass

from fastapi import Depends
from sqlalchemy import ColumnElement, false, select, true
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.errors import ForbiddenError, NotFoundError
from app.db.session import get_db
from app.modules.auth.dependencies import get_current_user
from app.modules.sites.models import Site
from app.modules.users.models import User
from app.modules.users.roles import Role

GLOBAL_SCOPE_ROLES: frozenset[Role] = frozenset({Role.ADMIN, Role.CLINICAL_LEAD, Role.DATA_OFFICER})


@dataclass(frozen=True)
class SiteScope:
    """Ensemble des sites visibles par un utilisateur."""

    is_global: bool
    site_ids: frozenset[uuid.UUID]

    def contains(self, site_id: uuid.UUID | None) -> bool:
        """Vrai si une donnée rattachée à ``site_id`` est visible.

        Une donnée sans site (``None``) n'est visible qu'en vue globale.
        """
        if self.is_global:
            return True
        return site_id is not None and site_id in self.site_ids

    def filter(self, site_column: ColumnElement) -> ColumnElement[bool]:
        """Clause SQL à mettre dans ``.where()`` pour restreindre au périmètre."""
        if self.is_global:
            return true()
        if not self.site_ids:
            return false()
        return site_column.in_(self.site_ids)

    def ensure_contains(self, site_id: uuid.UUID | None) -> None:
        """Lève :class:`NotFoundError` (404) si la donnée est hors périmètre."""
        if not self.contains(site_id):
            raise NotFoundError

    def ensure_writable(self, site_id: uuid.UUID | None) -> None:
        """Lève :class:`ForbiddenError` (403) si l'on tente d'écrire vers un site
        hors périmètre (le site cible est connu du client, rien n'est révélé)."""
        if not self.contains(site_id):
            raise ForbiddenError("Site hors de votre périmètre.")


def descendant_site_ids(session: Session, root_id: uuid.UUID) -> frozenset[uuid.UUID]:
    """``root_id`` et tous ses descendants (sites inactifs compris).

    Parcours en largeur en Python : le nombre de sites est faible et la requête
    reste portable (PostgreSQL / SQLite). Robuste à un cycle accidentel.
    """
    children: dict[uuid.UUID, list[uuid.UUID]] = defaultdict(list)
    for site_id, parent_id in session.execute(select(Site.id, Site.parent_site_id)):
        if parent_id is not None:
            children[parent_id].append(site_id)
    seen = {root_id}
    queue = deque([root_id])
    while queue:
        for child in children[queue.popleft()]:
            if child not in seen:
                seen.add(child)
                queue.append(child)
    return frozenset(seen)


def compute_site_scope(session: Session, user: User) -> SiteScope:
    if user.role in GLOBAL_SCOPE_ROLES:
        return SiteScope(is_global=True, site_ids=frozenset())
    if user.site_id is None:
        return SiteScope(is_global=False, site_ids=frozenset())
    return SiteScope(is_global=False, site_ids=descendant_site_ids(session, user.site_id))


def get_site_scope(
    user: User = Depends(get_current_user),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
) -> SiteScope:
    """Dépendance FastAPI : périmètre de l'utilisateur courant."""
    return compute_site_scope(db, user)


@dataclass(frozen=True)
class ActorContext:
    """Contexte d'une opération métier : session, acteur, périmètre et settings.

    Partagé par les routeurs REST et la synchronisation, pour que les mêmes
    contrôles (rôle, périmètre, audit) s'appliquent quel que soit le canal.
    """

    session: Session
    actor: User
    scope: SiteScope
    settings: Settings

    def ensure_role(self, roles: frozenset[Role]) -> None:
        if self.actor.role not in roles:
            raise ForbiddenError


def get_actor_context(
    user: User = Depends(get_current_user),  # noqa: B008
    db: Session = Depends(get_db),  # noqa: B008
    settings: Settings = Depends(get_settings),  # noqa: B008
) -> ActorContext:
    """Dépendance FastAPI : contexte de l'utilisateur courant."""
    return ActorContext(db, user, compute_site_scope(db, user), settings)
