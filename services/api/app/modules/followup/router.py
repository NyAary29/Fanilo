"""Suivi des patientes (espace agent communautaire, web/tablette).

``GET /followup/patients`` : liste de travail des bénéficiaires du périmètre,
avec ce qu'il faut pour agir (grossesse en cours, prochaine CPN, CPN manquées,
alertes ouvertes) et un statut simple « à jour » / « à suivre ».

Données nominatives : rôles nominatifs uniquement. Chaque identité déchiffrée
et renvoyée produit un événement d'audit ``identity.read`` (comme
``GET /beneficiaries/{id}/identity``). Aucune information clinique libre.

Statut ``a_suivre`` si : alerte ouverte/escaladée/acquittée non résolue, CPN
manquée (ou planifiée à une date passée) sur la grossesse en cours, ou grossesse
en cours sans date de référence (aucun calendrier possible).
"""

import uuid
from datetime import date, datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import case, select

from app.core.crypto import get_cipher
from app.core.errors import NotFoundError
from app.db.types import utcnow
from app.modules.alerts.models import Alert, AlertStatus
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import Beneficiary, BeneficiaryIdentity
from app.modules.interactions.models import FollowUpStatus, Interaction, Triage
from app.modules.reny.models import AncVisit, AncVisitStatus, Pregnancy, PregnancyStatus
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext, get_actor_context
from app.modules.users.roles import NOMINATIVE_DATA_ROLES, Role

router = APIRouter(prefix="/followup", tags=["suivi des patientes"])

MAX_PATIENTS = 500
OPEN_ALERTS = (AlertStatus.OPEN, AlertStatus.ESCALATED, AlertStatus.ACKNOWLEDGED)


class NextAnc(BaseModel):
    visit_id: uuid.UUID
    sequence: int
    scheduled_date: date
    days: int


class PregnancyInfo(BaseModel):
    id: uuid.UUID
    month: int | None  # mois de grossesse depuis la DDR (indicatif, non clinique)
    lmp_date: date | None
    estimated_due_date: date | None


class Patient(BaseModel):
    beneficiary_id: uuid.UUID
    code: str
    site_id: uuid.UUID
    site_name: str
    age: int | None
    display_name: str | None
    village: str | None
    pregnancy: PregnancyInfo | None
    next_anc: NextAnc | None
    anc_done: int
    anc_total: int
    missed_anc: int
    open_alerts: int
    latest_alert_id: uuid.UUID | None
    status: Literal["a_jour", "a_suivre"]
    reasons: list[str]


class PatientList(BaseModel):
    items: list[Patient]
    total: int


@router.get("/patients", response_model=PatientList, summary="Mes patientes (liste de travail)")
def patients(
    q: str | None = Query(None, max_length=100, description="Nom, code FAN-… ou village"),
    status: Literal["a_jour", "a_suivre"] | None = None,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> PatientList:
    ctx.ensure_role(NOMINATIVE_DATA_ROLES)
    session = ctx.session
    today = utcnow().date()
    beneficiaries = list(
        session.scalars(
            select(Beneficiary)
            .where(Beneficiary.deleted_at.is_(None), ctx.scope.filter(Beneficiary.site_id))
            .order_by(Beneficiary.created_at.desc())
            .limit(MAX_PATIENTS)
        )
    )
    ids = [b.id for b in beneficiaries]
    if not ids:
        return PatientList(items=[], total=0)
    sites = {s.id: s.name for s in session.scalars(select(Site))}
    identities = {
        i.beneficiary_id: i
        for i in session.scalars(
            select(BeneficiaryIdentity).where(
                BeneficiaryIdentity.beneficiary_id.in_(ids),
                BeneficiaryIdentity.deleted_at.is_(None),
            )
        )
    }
    pregnancies = {
        p.beneficiary_id: p
        for p in session.scalars(
            select(Pregnancy).where(
                Pregnancy.beneficiary_id.in_(ids),
                Pregnancy.status == PregnancyStatus.ACTIVE,
                Pregnancy.deleted_at.is_(None),
            )
        )
    }
    visits: dict[uuid.UUID, list[AncVisit]] = {}
    if pregnancies:
        for v in session.scalars(
            select(AncVisit).where(
                AncVisit.pregnancy_id.in_([p.id for p in pregnancies.values()]),
                AncVisit.deleted_at.is_(None),
            )
        ):
            visits.setdefault(v.pregnancy_id, []).append(v)
    alerts: dict[uuid.UUID, list[Alert]] = {}
    for a in session.scalars(
        select(Alert)
        .where(
            Alert.beneficiary_id.in_(ids), Alert.deleted_at.is_(None), Alert.status.in_(OPEN_ALERTS)
        )
        .order_by(Alert.created_at.desc())
    ):
        alerts.setdefault(a.beneficiary_id, []).append(a)

    cipher = get_cipher(ctx.settings)
    needle = (q or "").strip().lower()
    items: list[Patient] = []
    for b in beneficiaries:
        identity = identities.get(b.id)
        name = cipher.decrypt(identity.display_name_encrypted) if identity else None
        village = cipher.decrypt(identity.village_encrypted) if identity else None
        if needle and not any(needle in (field or "").lower() for field in (name, village, b.code)):
            continue
        preg = pregnancies.get(b.id)
        reasons: list[str] = []
        pregnancy_info = next_anc = None
        done = total = missed = 0
        if preg is not None:
            month = None
            if preg.lmp_date is not None:
                month = max(1, min(10, (today - preg.lmp_date).days // 30 + 1))
            pregnancy_info = PregnancyInfo(
                id=preg.id,
                month=month,
                lmp_date=preg.lmp_date,
                estimated_due_date=preg.estimated_due_date,
            )
            pv = sorted(visits.get(preg.id, []), key=lambda v: v.sequence)
            total = len([v for v in pv if v.status is not AncVisitStatus.CANCELLED])
            done = len([v for v in pv if v.status is AncVisitStatus.DONE])
            missed = len(
                [
                    v
                    for v in pv
                    if v.status is AncVisitStatus.MISSED
                    or (v.status is AncVisitStatus.PLANNED and v.scheduled_date < today)
                ]
            )
            upcoming = [
                v for v in pv if v.status is AncVisitStatus.PLANNED and v.scheduled_date >= today
            ]
            if upcoming:
                v = upcoming[0]
                next_anc = NextAnc(
                    visit_id=v.id,
                    sequence=v.sequence,
                    scheduled_date=v.scheduled_date,
                    days=(v.scheduled_date - today).days,
                )
            if missed:
                reasons.append("cpn_manquee")
            if preg.lmp_date is None and preg.estimated_due_date is None:
                reasons.append("dates_inconnues")
        open_alerts = alerts.get(b.id, [])
        if open_alerts:
            reasons.insert(0, "alerte_ouverte")
        patient_status = "a_suivre" if reasons else "a_jour"
        if status is not None and patient_status != status:
            continue
        if identity is not None:
            record_audit(
                session,
                ctx.actor,
                AuditAction.IDENTITY_READ,
                "beneficiary_identity",
                identity.id,
                site_id=b.site_id,
            )
        items.append(
            Patient(
                beneficiary_id=b.id,
                code=b.code,
                site_id=b.site_id,
                site_name=sites.get(b.site_id, ""),
                age=(today.year - b.birth_year) if b.birth_year else None,
                display_name=name,
                village=village,
                pregnancy=pregnancy_info,
                next_anc=next_anc,
                anc_done=done,
                anc_total=total,
                missed_anc=missed,
                open_alerts=len(open_alerts),
                latest_alert_id=open_alerts[0].id if open_alerts else None,
                status=patient_status,
                reasons=reasons,
            )
        )
    # « À suivre » d'abord, puis prochaine CPN la plus proche.
    items.sort(
        key=lambda p: (
            p.status != "a_suivre",
            p.next_anc.days if p.next_anc else 10_000,
            (p.display_name or p.code).lower(),
        )
    )
    session.commit()
    return PatientList(items=items, total=len(items))


# --- Suivi des orientations (responsable du centre de santé) -------------------

ORIENTATION_ROLES = frozenset({Role.CSB_HEAD, Role.CLINICAL_ADVISOR, Role.CLINICAL_LEAD})


class OrientationItem(BaseModel):
    id: uuid.UUID
    created_at: datetime
    module: str
    channel: str
    question: str | None
    triage: Triage | None
    answer: str | None
    reviewed_at: datetime | None
    orientation_site_id: uuid.UUID
    site_name: str
    follow_up_code: str | None
    follow_up_status: FollowUpStatus | None
    follow_up_at: datetime | None
    follow_up_note: str | None


class OrientationList(BaseModel):
    items: list[OrientationItem]
    total: int
    counts: dict[str, int]


def _item(row: Interaction, sites: dict[uuid.UUID, str]) -> OrientationItem:
    return OrientationItem(
        id=row.id,
        created_at=row.created_at,
        module=str(row.module),
        channel=row.channel,
        question=row.transcript,
        triage=row.triage,
        answer=row.review_note,
        reviewed_at=row.reviewed_at,
        orientation_site_id=row.orientation_site_id,
        site_name=sites.get(row.orientation_site_id, ""),
        follow_up_code=row.follow_up_code,
        follow_up_status=row.follow_up_status,
        follow_up_at=row.follow_up_at,
        follow_up_note=row.follow_up_note,
    )


@router.get(
    "/orientations",
    response_model=OrientationList,
    summary="Personnes orientées vers mon centre (suivi : venue / pas venue)",
)
def orientations(
    status: FollowUpStatus | None = None,
    code: str | None = Query(None, max_length=8),
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> OrientationList:
    ctx.ensure_role(ORIENTATION_ROLES)
    base = select(Interaction).where(
        Interaction.follow_up_status.is_not(None),
        Interaction.orientation_site_id.is_not(None),
        ctx.scope.filter(Interaction.orientation_site_id),
    )
    counts = {str(s): 0 for s in FollowUpStatus}
    for (row_status,) in ctx.session.execute(
        select(Interaction.follow_up_status).select_from(base.subquery())
    ):
        counts[str(row_status)] = counts.get(str(row_status), 0) + 1
    stmt = base
    if status is not None:
        stmt = stmt.where(Interaction.follow_up_status == status)
    if code:
        stmt = stmt.where(Interaction.follow_up_code == code.strip().upper())
    urgent_first = case((Interaction.triage == Triage.URGENT, 0), else_=1)
    rows = list(
        ctx.session.scalars(stmt.order_by(urgent_first, Interaction.reviewed_at.desc()).limit(200))
    )
    sites = {s.id: s.name for s in ctx.session.scalars(select(Site))}
    return OrientationList(items=[_item(r, sites) for r in rows], total=len(rows), counts=counts)


class OrientationUpdate(BaseModel):
    status: Literal["came", "no_show"]
    note: str | None = Field(None, max_length=1_000)


@router.post(
    "/orientations/{interaction_id}",
    response_model=OrientationItem,
    summary="Enregistrer si la personne est venue au centre",
)
def update_orientation(
    interaction_id: uuid.UUID,
    body: OrientationUpdate,
    ctx: ActorContext = Depends(get_actor_context),  # noqa: B008
) -> OrientationItem:
    ctx.ensure_role(ORIENTATION_ROLES)
    row = ctx.session.get(Interaction, interaction_id)
    if row is None or row.follow_up_status is None or row.orientation_site_id is None:
        raise NotFoundError
    ctx.scope.ensure_contains(row.orientation_site_id)
    row.follow_up_status = FollowUpStatus(body.status)
    row.follow_up_at = utcnow()
    row.follow_up_by_user_id = ctx.actor.id
    row.follow_up_note = (body.note or "").strip() or None
    record_audit(
        ctx.session,
        ctx.actor,
        "orientation.follow_up",
        "interaction",
        row.id,
        row.orientation_site_id,
    )
    ctx.session.commit()
    sites = {s.id: s.name for s in ctx.session.scalars(select(Site))}
    return _item(row, sites)
