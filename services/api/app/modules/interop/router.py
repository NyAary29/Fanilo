"""Export agrégé mensuel au format DHIS2 ``dataValueSet`` (F-17).

Interface **documentée et préparatoire** : FANILO ne pousse rien vers un système
tiers. Le responsable données récupère le fichier et l'importe (ou un adaptateur
l'enverra) seulement après autorisation institutionnelle et validation de la
correspondance des éléments de données (voir docs/interoperabilite.md).

- Agrégats uniquement, par CSB (``orgUnit`` = code du site FANILO ; les zones
  communautaires sont rattachées à leur CSB). Aucune donnée nominative, aucun
  identifiant de bénéficiaire.
- Cellules inférieures à ``FANILO_STATS_MIN_CELL_SIZE`` exportées seulement si
  ``include_small_cells=true`` (secret statistique par défaut).
- Chaque export est audité (``export.aggregates``).
"""

import calendar
import uuid
from collections import Counter
from collections.abc import Iterable
from datetime import UTC, date, datetime, time

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select

from app.core.errors import ForbiddenError
from app.db.types import utcnow
from app.modules.alerts.models import Alert
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import Beneficiary
from app.modules.interactions.models import Interaction, Outcome
from app.modules.referrals.models import Referral, ReferralStatus
from app.modules.reny.models import AncVisit, AncVisitStatus, Pregnancy
from app.modules.sites.models import Site, SiteKind
from app.modules.sites.scope import ActorContext, get_actor_context
from app.modules.users.roles import Role

router = APIRouter(prefix="/interop", tags=["interopérabilité"])

EXPORT_ROLES: frozenset[Role] = frozenset({Role.DATA_OFFICER})
DATA_SET = "FANILO_MONTHLY"
# Semaines d'aménorrhée pour l'indicateur « CPN1 avant 16 semaines ».
EARLY_ANC_DAYS = 16 * 7

# Code de l'élément de données -> libellé (docs/interoperabilite.md).
DATA_ELEMENTS: dict[str, str] = {
    "FANILO_PREG_NEW": "Grossesses enregistrées",
    "FANILO_ANC_DONE": "CPN réalisées",
    "FANILO_ANC1_BEFORE_16W": "CPN1 réalisées avant 16 semaines (DDR connue)",
    "FANILO_ANC_MISSED": "CPN manquées",
    "FANILO_ALERTS": "Alertes signe de danger créées",
    "FANILO_ALERTS_ACK_IN_TIME": "Alertes acquittées avant l'échéance",
    "FANILO_REFERRALS": "Références créées",
    "FANILO_REFERRALS_ARRIVED": "Références arrivées",
    "FANILO_QUESTIONS": "Questions posées",
    "FANILO_QUESTIONS_TRANSFERRED": "Questions transférées au conseiller",
}


class DataValue(BaseModel):
    dataElement: str  # noqa: N815 - nom imposé par le format DHIS2
    orgUnit: str  # noqa: N815
    period: str
    value: str


class DataValueSet(BaseModel):
    dataSet: str  # noqa: N815
    period: str
    completeDate: str  # noqa: N815
    generated_at: datetime
    min_cell_size: int
    suppressed_values: int
    data_elements: dict[str, str]
    dataValues: list[DataValue]  # noqa: N815


def _csb_of(sites: list[Site]) -> dict[uuid.UUID, str]:
    """Site -> code du CSB de rattachement (lui-même ou l'ancêtre CSB le plus proche)."""
    by_id = {s.id: s for s in sites}
    result: dict[uuid.UUID, str] = {}
    for site in sites:
        current: Site | None = site
        seen: set[uuid.UUID] = set()
        while current is not None and current.id not in seen:
            if current.kind is SiteKind.CSB:
                result[site.id] = current.code
                break
            seen.add(current.id)
            current = by_id.get(current.parent_site_id) if current.parent_site_id else None
    return result


def _count(counter: Counter, element: str, site_ids: Iterable[uuid.UUID | None],
           csb: dict[uuid.UUID, str]) -> None:
    for site_id in site_ids:
        if site_id is not None and site_id in csb:
            counter[(element, csb[site_id])] += 1


@router.get(
    "/dhis2/data-value-set",
    response_model=DataValueSet,
    summary="Export agrégé mensuel (format DHIS2 dataValueSet, préparatoire)",
)
def dhis2_data_value_set(
    period: str = Query(..., pattern=r"^\d{4}(0[1-9]|1[0-2])$", description="AAAAMM"),
    include_small_cells: bool = False,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> DataValueSet:
    if ctx.actor.role not in EXPORT_ROLES:
        raise ForbiddenError
    session = ctx.session
    year, month = int(period[:4]), int(period[4:])
    first = date(year, month, 1)
    last = date(year, month, calendar.monthrange(year, month)[1])
    start = datetime.combine(first, time.min, tzinfo=UTC)
    end = datetime.combine(last, time.max, tzinfo=UTC)

    csb = _csb_of(list(session.scalars(select(Site))))
    counter: Counter = Counter()

    pregnancies = session.execute(
        select(Beneficiary.site_id)
        .join(Pregnancy, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(Pregnancy.deleted_at.is_(None), Pregnancy.created_at.between(start, end))
    ).scalars()
    _count(counter, "FANILO_PREG_NEW", pregnancies, csb)

    visits = session.execute(
        select(Beneficiary.site_id, AncVisit.status, AncVisit.sequence, AncVisit.done_date,
               AncVisit.scheduled_date, Pregnancy.lmp_date)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .join(Beneficiary, Pregnancy.beneficiary_id == Beneficiary.id)
        .where(AncVisit.deleted_at.is_(None))
    ).all()
    for site_id, status, sequence, done_date, scheduled, lmp in visits:
        if status is AncVisitStatus.DONE and done_date and first <= done_date <= last:
            _count(counter, "FANILO_ANC_DONE", [site_id], csb)
            if sequence == 1 and lmp and (done_date - lmp).days <= EARLY_ANC_DAYS:
                _count(counter, "FANILO_ANC1_BEFORE_16W", [site_id], csb)
        elif status is AncVisitStatus.MISSED and first <= scheduled <= last:
            _count(counter, "FANILO_ANC_MISSED", [site_id], csb)

    alerts = session.execute(
        select(Alert.site_id, Alert.acknowledged_at, Alert.due_at).where(
            Alert.deleted_at.is_(None), Alert.created_at.between(start, end)
        )
    ).all()
    for site_id, acknowledged_at, due_at in alerts:
        _count(counter, "FANILO_ALERTS", [site_id], csb)
        if acknowledged_at is not None and acknowledged_at <= due_at:
            _count(counter, "FANILO_ALERTS_ACK_IN_TIME", [site_id], csb)

    referrals = session.execute(
        select(Beneficiary.site_id, Referral.status)
        .join(Beneficiary, Referral.beneficiary_id == Beneficiary.id)
        .where(Referral.deleted_at.is_(None), Referral.created_at.between(start, end))
    ).all()
    for site_id, status in referrals:
        _count(counter, "FANILO_REFERRALS", [site_id], csb)
        if status is ReferralStatus.ARRIVED:
            _count(counter, "FANILO_REFERRALS_ARRIVED", [site_id], csb)

    questions = session.execute(
        select(Interaction.site_id, Interaction.outcome).where(
            Interaction.created_at.between(start, end)
        )
    ).all()
    for site_id, outcome in questions:
        _count(counter, "FANILO_QUESTIONS", [site_id], csb)
        if outcome is Outcome.FALLBACK:
            _count(counter, "FANILO_QUESTIONS_TRANSFERRED", [site_id], csb)

    k = ctx.settings.stats_min_cell_size
    values: list[DataValue] = []
    suppressed = 0
    for (element, org_unit), count in sorted(counter.items()):
        if count < k and not include_small_cells:
            suppressed += 1
            continue
        values.append(
            DataValue(dataElement=element, orgUnit=org_unit, period=period, value=str(count))
        )

    record_audit(session, ctx.actor, AuditAction.EXPORT_AGGREGATES, "export", None)
    session.commit()
    now = utcnow()
    return DataValueSet(
        dataSet=DATA_SET,
        period=period,
        completeDate=now.date().isoformat(),
        generated_at=now,
        min_cell_size=k,
        suppressed_values=suppressed,
        data_elements=DATA_ELEMENTS,
        dataValues=values,
    )
