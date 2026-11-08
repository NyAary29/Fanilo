"""Logique RENY : grossesse, génération du calendrier CPN, visites.

Mêmes conventions que ``beneficiaries.service`` : contrôle de rôle, périmètre,
audit, ``flush`` sans commit.
"""

import uuid
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import (
    ConsentRequiredError,
    InvalidDataError,
    NotFoundError,
    StateConflictError,
    check_version,
)
from app.db.types import utcnow
from app.modules.audit.service import AuditAction, record_audit
from app.modules.beneficiaries.models import Beneficiary, ConsentScope
from app.modules.beneficiaries.service import CARE_ROLES, get_beneficiary
from app.modules.reny.models import AncVisit, AncVisitStatus, Pregnancy, PregnancyStatus
from app.modules.reny.reminders import (
    cancel_scheduled_reminders,
    has_active_consent,
    plan_visit_reminder,
    reschedule_visit_reminders,
)
from app.modules.reny.schedule import (
    AncSchedule,
    ScheduleUnavailableError,
    get_schedule,
)
from app.modules.reny.schemas import AncVisitPatch, PregnancyCreate, PregnancyPatch
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext

NO_RENY_CONSENT = "Consentement RENY actif requis pour enregistrer une grossesse."
# Plage de cohérence des dates (non clinique : simple garde-fou de saisie).
MAX_LMP_AGE = timedelta(days=320)


def _schedule_or_error(ctx: ActorContext) -> AncSchedule:
    try:
        return get_schedule(ctx.settings)
    except ScheduleUnavailableError as exc:
        raise InvalidDataError(str(exc), code="anc_schedule_unavailable") from None


def _check_dates(lmp, due) -> None:
    today = utcnow().date()
    if lmp is not None and (lmp > today or lmp < today - MAX_LMP_AGE):
        raise InvalidDataError("Date des dernières règles incohérente.")
    if due is not None and lmp is not None and due <= lmp:
        raise InvalidDataError("La date prévue d'accouchement doit suivre les dernières règles.")


def generate_anc_visits(
    session: Session, beneficiary: Beneficiary, pregnancy: Pregnancy, schedule: AncSchedule
) -> list[AncVisit]:
    """Crée les visites CPN à venir selon le calendrier configuré.

    Les visites dont la date est déjà passée à l'enregistrement ne sont pas
    créées (la séquence du calendrier est conservée). Sans date de référence,
    aucune visite n'est générée.
    """
    lmp = schedule.reference_lmp(pregnancy.lmp_date, pregnancy.estimated_due_date)
    if lmp is None:
        return []
    today = utcnow().date()
    visits = [
        AncVisit(pregnancy_id=pregnancy.id, sequence=sequence, scheduled_date=when)
        for sequence, when in schedule.visit_dates(lmp)
        if when >= today
    ]
    session.add_all(visits)
    session.flush()
    if (pregnancy.anc_schedule_id, pregnancy.anc_schedule_version) != (
        schedule.schedule_id,
        schedule.version,
    ):
        pregnancy.anc_schedule_id = schedule.schedule_id
        pregnancy.anc_schedule_version = schedule.version
    for visit in visits:
        plan_visit_reminder(session, beneficiary, visit, schedule)
    return visits


def get_pregnancy(ctx: ActorContext, pregnancy_id: uuid.UUID) -> tuple[Pregnancy, Beneficiary]:
    pregnancy = ctx.session.get(Pregnancy, pregnancy_id)
    if pregnancy is None or pregnancy.deleted_at is not None:
        raise NotFoundError
    return pregnancy, get_beneficiary(ctx, pregnancy.beneficiary_id)


def create_pregnancy(
    ctx: ActorContext, beneficiary: Beneficiary, data: PregnancyCreate
) -> Pregnancy:
    """Refus (422) sans consentement RENY actif ou si le calendrier n'est pas
    autorisé : rien n'est créé dans ce cas."""
    ctx.ensure_role(CARE_ROLES)
    session = ctx.session
    if not has_active_consent(session, beneficiary.id, ConsentScope.RENY):
        raise ConsentRequiredError(NO_RENY_CONSENT)
    schedule = _schedule_or_error(ctx)
    _check_dates(data.lmp_date, data.estimated_due_date)
    if data.id is not None and session.get(Pregnancy, data.id) is not None:
        raise StateConflictError("Une grossesse existe déjà avec cet identifiant.")
    active = session.scalar(
        select(Pregnancy.id).where(
            Pregnancy.beneficiary_id == beneficiary.id,
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
        )
    )
    if active is not None:
        raise StateConflictError("Une grossesse active existe déjà pour cette bénéficiaire.")
    pregnancy = Pregnancy(
        beneficiary_id=beneficiary.id,
        status=PregnancyStatus.ACTIVE,
        lmp_date=data.lmp_date,
        estimated_due_date=data.estimated_due_date,
        dates_confirmed_by=data.dates_confirmed_by,
        anc_schedule_id=schedule.schedule_id,
        anc_schedule_version=schedule.version,
    )
    if data.id is not None:
        pregnancy.id = data.id
    session.add(pregnancy)
    session.flush()
    generate_anc_visits(session, beneficiary, pregnancy, schedule)
    session.flush()
    record_audit(
        session,
        ctx.actor,
        AuditAction.PREGNANCY_CREATE,
        "pregnancy",
        pregnancy.id,
        site_id=beneficiary.site_id,
    )
    return pregnancy


def _visit_ids(session: Session, pregnancy_id: uuid.UUID) -> list[uuid.UUID]:
    return list(session.scalars(select(AncVisit.id).where(AncVisit.pregnancy_id == pregnancy_id)))


def _close_pregnancy(session: Session, pregnancy: Pregnancy) -> None:
    """Grossesse terminée : visites planifiées annulées, rappels annulés."""
    for visit in session.scalars(
        select(AncVisit).where(
            AncVisit.pregnancy_id == pregnancy.id, AncVisit.status == AncVisitStatus.PLANNED
        )
    ):
        visit.status = AncVisitStatus.CANCELLED
    cancel_scheduled_reminders(session, anc_visit_ids=_visit_ids(session, pregnancy.id))


def update_pregnancy(
    ctx: ActorContext, pregnancy: Pregnancy, beneficiary: Beneficiary, data: PregnancyPatch
) -> Pregnancy:
    ctx.ensure_role(CARE_ROLES)
    session = ctx.session
    if data.version is not None:
        check_version(pregnancy.version, data.version)
    changes = data.model_dump(exclude_unset=True, exclude={"version"})
    for field in ("status", "dates_confirmed_by"):
        if field in changes and changes[field] is None:
            raise InvalidDataError(f"{field} ne peut pas être nul.")
    _check_dates(
        changes.get("lmp_date", pregnancy.lmp_date),
        changes.get("estimated_due_date", pregnancy.estimated_due_date),
    )
    was_active = pregnancy.status is PregnancyStatus.ACTIVE
    for field, value in changes.items():
        setattr(pregnancy, field, value)
    session.flush()
    if was_active and pregnancy.status is not PregnancyStatus.ACTIVE:
        _close_pregnancy(session, pregnancy)
    elif (
        pregnancy.status is PregnancyStatus.ACTIVE
        and {"lmp_date", "estimated_due_date"} & changes.keys()
        and not _visit_ids(session, pregnancy.id)
    ):
        # Dates connues après coup : le calendrier est généré s'il ne l'a pas été.
        generate_anc_visits(session, beneficiary, pregnancy, _schedule_or_error(ctx))
    session.flush()
    record_audit(
        session,
        ctx.actor,
        AuditAction.PREGNANCY_UPDATE,
        "pregnancy",
        pregnancy.id,
        site_id=beneficiary.site_id,
    )
    return pregnancy


def soft_delete_pregnancy_tree(
    session: Session,
    *,
    beneficiary_id: uuid.UUID | None = None,
    pregnancy: Pregnancy | None = None,
) -> None:
    """Suppression logique de grossesse(s) et de leurs visites ; rappels annulés."""
    if pregnancy is not None:
        pregnancies = [pregnancy]
    else:
        pregnancies = list(
            session.scalars(select(Pregnancy).where(Pregnancy.beneficiary_id == beneficiary_id))
        )
    for item in pregnancies:
        for visit in session.scalars(select(AncVisit).where(AncVisit.pregnancy_id == item.id)):
            visit.soft_delete()
        cancel_scheduled_reminders(session, anc_visit_ids=_visit_ids(session, item.id))
        item.soft_delete()


def delete_pregnancy(ctx: ActorContext, pregnancy: Pregnancy, beneficiary: Beneficiary) -> None:
    ctx.ensure_role(CARE_ROLES)
    soft_delete_pregnancy_tree(ctx.session, pregnancy=pregnancy)
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.PREGNANCY_DELETE,
        "pregnancy",
        pregnancy.id,
        site_id=beneficiary.site_id,
    )


def get_anc_visit(
    ctx: ActorContext, visit_id: uuid.UUID
) -> tuple[AncVisit, Pregnancy, Beneficiary]:
    visit = ctx.session.get(AncVisit, visit_id)
    if visit is None or visit.deleted_at is not None:
        raise NotFoundError
    pregnancy, beneficiary = get_pregnancy(ctx, visit.pregnancy_id)
    return visit, pregnancy, beneficiary


def update_anc_visit(
    ctx: ActorContext,
    visit: AncVisit,
    beneficiary: Beneficiary,
    data: AncVisitPatch,
) -> AncVisit:
    """Marquer ``done`` / ``missed`` / ``cancelled``, ou replanifier
    (``scheduled_date`` → la visite repasse ``planned``)."""
    ctx.ensure_role(CARE_ROLES)
    session = ctx.session
    if data.version is not None:
        check_version(visit.version, data.version)
    changes = data.model_dump(exclude_unset=True, exclude={"version"})
    for field in ("status", "scheduled_date"):
        if field in changes and changes[field] is None:
            raise InvalidDataError(f"{field} ne peut pas être nul.")
    if changes.get("site_id") is not None and session.get(Site, changes["site_id"]) is None:
        raise InvalidDataError("Site introuvable.")
    rescheduled = "scheduled_date" in changes and changes["scheduled_date"] != visit.scheduled_date
    if rescheduled and "status" not in changes:
        changes["status"] = AncVisitStatus.PLANNED
    new_status = changes.get("status", visit.status)
    today = utcnow().date()
    if new_status is AncVisitStatus.DONE:
        done_date = changes.get("done_date") or visit.done_date or today
        if done_date > today:
            raise InvalidDataError("La date de réalisation ne peut pas être dans le futur.")
        changes["done_date"] = done_date
    else:
        changes["done_date"] = None
    for field, value in changes.items():
        setattr(visit, field, value)
    session.flush()
    if visit.status is AncVisitStatus.PLANNED:
        try:
            schedule = get_schedule(ctx.settings)
        except ScheduleUnavailableError:
            schedule = None
        if schedule is not None:
            reschedule_visit_reminders(session, visit, schedule)
            plan_visit_reminder(session, beneficiary, visit, schedule)
    else:
        cancel_scheduled_reminders(session, anc_visit_ids=[visit.id])
    session.flush()
    record_audit(
        session,
        ctx.actor,
        AuditAction.ANC_VISIT_UPDATE,
        "anc_visit",
        visit.id,
        site_id=beneficiary.site_id,
    )
    return visit


def delete_anc_visit(ctx: ActorContext, visit: AncVisit, beneficiary: Beneficiary) -> None:
    ctx.ensure_role(CARE_ROLES)
    visit.soft_delete()
    cancel_scheduled_reminders(ctx.session, anc_visit_ids=[visit.id])
    ctx.session.flush()
    record_audit(
        ctx.session,
        ctx.actor,
        AuditAction.ANC_VISIT_DELETE,
        "anc_visit",
        visit.id,
        site_id=beneficiary.site_id,
    )
