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

from fastapi import APIRouter, Depends, Query
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


# --- Statistiques thématiques (F-16) -------------------------------------------


class TopicCell(BaseModel):
    module: str
    intent: str | None
    outcome: str
    content_code: str | None
    count: int


class TopicStats(BaseModel):
    """Comptages agrégés des questions par thème. Toute cellule inférieure à
    ``min_cell_size`` est masquée et seulement comptée dans ``suppressed_total``
    (secret statistique : aucune petite cellule ne permet de réidentifier)."""

    period_days: int
    min_cell_size: int
    total: int
    suppressed_cells: int
    suppressed_total: int
    items: list[TopicCell]
    generated_at: datetime


def compute_topics(ctx: ActorContext, site_id: uuid.UUID | None, days: int) -> TopicStats:
    ctx.ensure_role(DASHBOARD_ROLES)
    in_scope = _site_filter(ctx, site_id)
    now = utcnow()
    k = ctx.settings.stats_min_cell_size
    rows = ctx.session.execute(
        select(
            Interaction.module,
            Interaction.intent,
            Interaction.outcome,
            Interaction.content_code,
            func.count(),
        )
        .where(Interaction.created_at >= now - timedelta(days=days), in_scope(Interaction.site_id))
        .group_by(
            Interaction.module, Interaction.intent, Interaction.outcome, Interaction.content_code
        )
    ).all()
    items: list[TopicCell] = []
    suppressed_cells = suppressed_total = total = 0
    for module, intent, outcome, content_code, count in rows:
        total += count
        if count < k:
            suppressed_cells += 1
            suppressed_total += count
            continue
        items.append(
            TopicCell(
                module=str(module),
                intent=intent,
                outcome=str(outcome),
                content_code=content_code,
                count=count,
            )
        )
    items.sort(key=lambda c: (-c.count, c.module, c.intent or "", c.outcome))
    return TopicStats(
        period_days=days,
        min_cell_size=k,
        total=total,
        suppressed_cells=suppressed_cells,
        suppressed_total=suppressed_total,
        items=items,
        generated_at=now,
    )


@router.get("/topics", response_model=TopicStats, summary="Statistiques thématiques agrégées")
def topics(
    site_id: uuid.UUID | None = None,
    days: int = Query(30, ge=1, le=366),
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> TopicStats:
    return compute_topics(ctx, site_id, days)


# --- Activité mensuelle et répartition par site (graphique du tableau de bord) ---


class MonthActivity(BaseModel):
    month: str  # AAAA-MM
    pregnancies: int
    alerts: int
    questions: int
    anc_done: int


class SiteActivity(BaseModel):
    site_id: uuid.UUID
    name: str
    code: str
    region: str
    active_pregnancies: int
    open_alerts: int


class Activity(BaseModel):
    months: list[MonthActivity]
    sites: list[SiteActivity]
    generated_at: datetime


def _month_keys(today, months: int) -> list[str]:
    keys = []
    year, month = today.year, today.month
    for _ in range(months):
        keys.append(f"{year:04d}-{month:02d}")
        month -= 1
        if month == 0:
            year, month = year - 1, 12
    return list(reversed(keys))


def compute_activity(ctx: ActorContext, site_id: uuid.UUID | None, months: int) -> Activity:
    ctx.ensure_role(DASHBOARD_ROLES)
    in_scope = _site_filter(ctx, site_id)
    session = ctx.session
    now = utcnow()
    keys = _month_keys(now.date(), months)
    first_year, first_month = (int(p) for p in keys[0].split("-"))
    start = datetime(first_year, first_month, 1, tzinfo=now.tzinfo)
    series: dict[str, dict[str, int]] = {
        k: {"pregnancies": 0, "alerts": 0, "questions": 0, "anc_done": 0} for k in keys
    }

    def bump(name: str, when) -> None:
        if when is None:
            return
        key = f"{when.year:04d}-{when.month:02d}"
        if key in series:
            series[key][name] += 1

    for (created,) in session.execute(
        select(Pregnancy.created_at)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            Pregnancy.deleted_at.is_(None),
            Pregnancy.created_at >= start,
            in_scope(Beneficiary.site_id),
        )
    ):
        bump("pregnancies", created)
    for (created,) in session.execute(
        select(Alert.created_at).where(
            Alert.deleted_at.is_(None), Alert.created_at >= start, in_scope(Alert.site_id)
        )
    ):
        bump("alerts", created)
    for (created,) in session.execute(
        select(Interaction.created_at).where(
            Interaction.created_at >= start, in_scope(Interaction.site_id)
        )
    ):
        bump("questions", created)
    for (done,) in session.execute(
        select(AncVisit.done_date)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            AncVisit.deleted_at.is_(None),
            AncVisit.status == AncVisitStatus.DONE,
            AncVisit.done_date >= start.date(),
            in_scope(Beneficiary.site_id),
        )
    ):
        bump("anc_done", done)

    # Répartition par CSB : une zone communautaire est comptée dans son CSB parent.
    all_sites = list(session.scalars(select(Site)))
    by_id = {s.id: s for s in all_sites}

    def csb_of(sid):
        current = by_id.get(sid)
        seen = set()
        while current is not None and current.id not in seen:
            if str(current.kind) == "csb":
                return current
            seen.add(current.id)
            current = by_id.get(current.parent_site_id) if current.parent_site_id else None
        return None

    counts: dict[uuid.UUID, dict[str, int]] = {}
    for (sid,) in session.execute(
        select(Beneficiary.site_id)
        .join(Pregnancy, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
            Beneficiary.deleted_at.is_(None),
            in_scope(Beneficiary.site_id),
        )
    ):
        csb = csb_of(sid)
        if csb is not None:
            counts.setdefault(csb.id, {"p": 0, "a": 0})["p"] += 1
    for (sid,) in session.execute(
        select(Alert.site_id).where(
            Alert.deleted_at.is_(None),
            Alert.status.in_((AlertStatus.OPEN, AlertStatus.ACKNOWLEDGED, AlertStatus.ESCALATED)),
            in_scope(Alert.site_id),
        )
    ):
        csb = csb_of(sid)
        if csb is not None:
            counts.setdefault(csb.id, {"p": 0, "a": 0})["a"] += 1
    visible_csbs = [
        s
        for s in all_sites
        if str(s.kind) == "csb"
        and s.is_active
        and (s.id in counts or (ctx.scope.contains(s.id) and site_id in (None, s.id)))
    ]
    sites = [
        SiteActivity(
            site_id=s.id,
            name=s.name,
            code=s.code,
            region=s.region,
            active_pregnancies=counts.get(s.id, {}).get("p", 0),
            open_alerts=counts.get(s.id, {}).get("a", 0),
        )
        for s in visible_csbs
    ]
    sites.sort(key=lambda s: (-s.open_alerts, -s.active_pregnancies, s.name))
    return Activity(
        months=[MonthActivity(month=k, **v) for k, v in series.items()],
        sites=sites,
        generated_at=now,
    )


@router.get("/activity", response_model=Activity, summary="Activité mensuelle et par CSB")
def activity(
    site_id: uuid.UUID | None = None,
    months: int = Query(6, ge=1, le=24),
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> Activity:
    return compute_activity(ctx, site_id, months)
