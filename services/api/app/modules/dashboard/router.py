"""Tableau de bord (section 9 du contrat) : **agrégats uniquement**.

Aucun identifiant, nom, code de bénéficiaire ni contenu n'est renvoyé : seulement
des compteurs et un taux, calculés dans le périmètre de l'utilisateur (ou du
site demandé et de ses descendants, s'il est dans ce périmètre).

Définitions :
- ``open_alerts`` : alertes ``open``, ``acknowledged`` ou ``escalated`` ;
- ``overdue_alerts`` : alertes non acquittées (``open`` ou ``escalated``) dont
  l'échéance ``due_at`` est dépassée ;
- ``pending_referrals`` : références ``proposed``, ``accepted`` ou ``transferred`` ;
- ``upcoming_anc_7d`` : visites ``planned`` des 7 prochains jours (grossesses actives) ;
- ``missed_anc_30d`` : visites des 30 derniers jours ``missed``, ou encore
  ``planned`` à une date passée ;
- ``active_agents_30d`` / ``total_agents`` : agents communautaires actifs connectés
  depuis 30 jours / au total ;
- ``fallback_rate_30d`` : part des interactions des 30 derniers jours en fallback.
"""

import uuid
from collections.abc import Callable
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import ColumnElement, and_, func, or_, select

from app.core.errors import NotFoundError
from app.db.types import utcnow
from app.modules.alerts.models import Alert, AlertStatus
from app.modules.beneficiaries.models import Beneficiary
from app.modules.interactions.models import Interaction, Outcome
from app.modules.referrals.models import Referral, ReferralStatus
from app.modules.reny.models import AncVisit, AncVisitStatus, Pregnancy, PregnancyStatus
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext, descendant_site_ids, get_actor_context
from app.modules.users.models import User
from app.modules.users.roles import Role

router = APIRouter(prefix="/dashboard", tags=["tableau de bord"])

DASHBOARD_ROLES: frozenset[Role] = frozenset(
    {Role.CSB_HEAD, Role.CLINICAL_LEAD, Role.ADMIN, Role.DATA_OFFICER}
)


class DashboardSummary(BaseModel):
    open_alerts: int
    overdue_alerts: int
    pending_referrals: int
    upcoming_anc_7d: int
    missed_anc_30d: int
    active_agents_30d: int
    total_agents: int
    active_pregnancies: int
    interactions_30d: int
    fallback_rate_30d: float
    generated_at: datetime


SiteFilter = Callable[[ColumnElement], ColumnElement[bool]]


def _site_filter(ctx: ActorContext, site_id: uuid.UUID | None) -> SiteFilter:
    if site_id is None:
        return ctx.scope.filter
    if ctx.session.get(Site, site_id) is None:
        raise NotFoundError
    ctx.scope.ensure_contains(site_id)
    site_ids = descendant_site_ids(ctx.session, site_id)
    return lambda column: column.in_(site_ids)


def _count(ctx: ActorContext, stmt) -> int:
    return int(ctx.session.scalar(select(func.count()).select_from(stmt.subquery())) or 0)


def compute_summary(ctx: ActorContext, site_id: uuid.UUID | None) -> DashboardSummary:
    ctx.ensure_role(DASHBOARD_ROLES)
    in_scope = _site_filter(ctx, site_id)
    now = utcnow()
    today = now.date()
    since_30d = now - timedelta(days=30)

    alerts = select(Alert.id).where(Alert.deleted_at.is_(None), in_scope(Alert.site_id))
    open_alerts = alerts.where(
        Alert.status.in_((AlertStatus.OPEN, AlertStatus.ACKNOWLEDGED, AlertStatus.ESCALATED))
    )
    overdue = alerts.where(
        Alert.status.in_((AlertStatus.OPEN, AlertStatus.ESCALATED)), Alert.due_at < now
    )

    referrals = (
        select(Referral.id)
        .join(Beneficiary, Referral.beneficiary_id == Beneficiary.id)
        .where(
            Referral.deleted_at.is_(None),
            or_(in_scope(Beneficiary.site_id), in_scope(Referral.to_site_id)),
            Referral.status.in_(
                (ReferralStatus.PROPOSED, ReferralStatus.ACCEPTED, ReferralStatus.TRANSFERRED)
            ),
        )
    )

    active_pregnancies = (
        select(Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
            Beneficiary.deleted_at.is_(None),
            in_scope(Beneficiary.site_id),
        )
    )
    visits = (
        select(AncVisit.id)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            AncVisit.deleted_at.is_(None),
            Pregnancy.deleted_at.is_(None),
            Beneficiary.deleted_at.is_(None),
            in_scope(Beneficiary.site_id),
        )
    )
    upcoming = visits.where(
        Pregnancy.status == PregnancyStatus.ACTIVE,
        AncVisit.status == AncVisitStatus.PLANNED,
        AncVisit.scheduled_date >= today,
        AncVisit.scheduled_date <= today + timedelta(days=7),
    )
    missed = visits.where(
        AncVisit.scheduled_date >= today - timedelta(days=30),
        or_(
            and_(AncVisit.status == AncVisitStatus.MISSED, AncVisit.scheduled_date <= today),
            and_(AncVisit.status == AncVisitStatus.PLANNED, AncVisit.scheduled_date < today),
        ),
    )

    agents = select(User.id).where(
        User.role == Role.COMMUNITY_AGENT,
        User.is_active.is_(True),
        User.deleted_at.is_(None),
        in_scope(User.site_id),
    )
    active_agents = agents.where(User.last_login_at >= since_30d)

    interactions = select(Interaction.id).where(
        Interaction.created_at >= since_30d, in_scope(Interaction.site_id)
    )
    interactions_30d = _count(ctx, interactions)
    fallbacks = _count(ctx, interactions.where(Interaction.outcome == Outcome.FALLBACK))

    return DashboardSummary(
        open_alerts=_count(ctx, open_alerts),
        overdue_alerts=_count(ctx, overdue),
        pending_referrals=_count(ctx, referrals),
        upcoming_anc_7d=_count(ctx, upcoming),
        missed_anc_30d=_count(ctx, missed),
        active_agents_30d=_count(ctx, active_agents),
        total_agents=_count(ctx, agents),
        active_pregnancies=_count(ctx, active_pregnancies),
        interactions_30d=interactions_30d,
        fallback_rate_30d=round(fallbacks / interactions_30d, 4) if interactions_30d else 0.0,
        generated_at=now,
    )


@router.get("/summary", response_model=DashboardSummary, summary="Indicateurs agrégés")
def summary(
    site_id: uuid.UUID | None = None,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> DashboardSummary:
    return compute_summary(ctx, site_id)
