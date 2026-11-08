"""Planification, annulation et envoi des rappels de CPN.

Règles :
- sans consentement ``reminders`` actif, aucun rappel n'est planifié ni envoyé ;
- un canal préféré ``none`` ne planifie rien ;
- le retrait du consentement annule les rappels encore planifiés ;
- à l'envoi, tout est revérifié (consentement, visite toujours planifiée,
  canal préféré courant).
"""

import uuid
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.db.types import utcnow
from app.modules.beneficiaries.models import Beneficiary, Consent, ConsentScope, PreferredChannel
from app.modules.reny.channels import ChannelError, adapter_for
from app.modules.reny.models import (
    AncVisit,
    AncVisitStatus,
    Pregnancy,
    PregnancyStatus,
    Reminder,
    ReminderStatus,
)
from app.modules.reny.schedule import AncSchedule


def has_active_consent(session: Session, beneficiary_id: uuid.UUID, scope: ConsentScope) -> bool:
    stmt = select(Consent.id).where(
        Consent.beneficiary_id == beneficiary_id,
        Consent.scope == scope,
        Consent.withdrawn_at.is_(None),
        Consent.deleted_at.is_(None),
    )
    return session.scalar(stmt.limit(1)) is not None


def _reminder_time(visit_date: date, schedule: AncSchedule) -> datetime:
    policy = schedule.reminders
    target = datetime.combine(
        visit_date - timedelta(days=policy.days_before),
        time(hour=policy.send_hour_utc),
        tzinfo=UTC,
    )
    return max(target, utcnow())


def plan_visit_reminder(
    session: Session, beneficiary: Beneficiary, visit: AncVisit, schedule: AncSchedule
) -> Reminder | None:
    """Planifie le rappel d'une visite si le consentement et le canal le permettent.

    Idempotent : ne crée rien si un rappel est déjà planifié pour cette visite.
    """
    if (
        beneficiary.preferred_channel is PreferredChannel.NONE
        or visit.status is not AncVisitStatus.PLANNED
        or visit.deleted_at is not None
        or visit.scheduled_date < utcnow().date()
        or not has_active_consent(session, beneficiary.id, ConsentScope.REMINDERS)
    ):
        return None
    existing = session.scalar(
        select(Reminder).where(
            Reminder.anc_visit_id == visit.id, Reminder.status == ReminderStatus.SCHEDULED
        )
    )
    if existing is not None:
        return None
    reminder = Reminder(
        beneficiary_id=beneficiary.id,
        anc_visit_id=visit.id,
        channel=beneficiary.preferred_channel,
        scheduled_at=_reminder_time(visit.scheduled_date, schedule),
        status=ReminderStatus.SCHEDULED,
        message_code=schedule.reminders.message_code,
    )
    session.add(reminder)
    return reminder


def plan_reminders_for_beneficiary(
    session: Session, beneficiary: Beneficiary, schedule: AncSchedule
) -> int:
    """Planifie les rappels des visites à venir (ex. après un nouveau consentement)."""
    visits = session.scalars(
        select(AncVisit)
        .join(Pregnancy, AncVisit.pregnancy_id == Pregnancy.id)
        .where(
            Pregnancy.beneficiary_id == beneficiary.id,
            Pregnancy.status == PregnancyStatus.ACTIVE,
            Pregnancy.deleted_at.is_(None),
            AncVisit.status == AncVisitStatus.PLANNED,
            AncVisit.deleted_at.is_(None),
        )
    )
    return sum(1 for visit in visits if plan_visit_reminder(session, beneficiary, visit, schedule))


def cancel_scheduled_reminders(
    session: Session,
    *,
    beneficiary_id: uuid.UUID | None = None,
    anc_visit_ids: Iterable[uuid.UUID] | None = None,
) -> int:
    """Annule les rappels encore planifiés (d'une bénéficiaire ou de visites)."""
    stmt = update(Reminder).where(Reminder.status == ReminderStatus.SCHEDULED)
    if beneficiary_id is not None:
        stmt = stmt.where(Reminder.beneficiary_id == beneficiary_id)
    if anc_visit_ids is not None:
        ids = list(anc_visit_ids)
        if not ids:
            return 0
        stmt = stmt.where(Reminder.anc_visit_id.in_(ids))
    if beneficiary_id is None and anc_visit_ids is None:
        raise ValueError("Préciser beneficiary_id ou anc_visit_ids.")
    result = session.execute(
        stmt.values(status=ReminderStatus.CANCELLED, updated_at=utcnow()).execution_options(
            synchronize_session="fetch"
        )
    )
    return result.rowcount or 0


def reschedule_visit_reminders(session: Session, visit: AncVisit, schedule: AncSchedule) -> None:
    """Recale les rappels planifiés d'une visite replanifiée."""
    for reminder in session.scalars(
        select(Reminder).where(
            Reminder.anc_visit_id == visit.id, Reminder.status == ReminderStatus.SCHEDULED
        )
    ):
        reminder.scheduled_at = _reminder_time(visit.scheduled_date, schedule)


@dataclass
class SendReport:
    sent: int = 0
    failed: int = 0
    cancelled: int = 0


def _cancel(reminder: Reminder, reason: str) -> None:
    reminder.status = ReminderStatus.CANCELLED
    reminder.last_error = reason


def send_due_reminders(session: Session, *, now: datetime | None = None) -> SendReport:
    """Envoie les rappels échus. Valide la transaction en fin de traitement."""
    now = now or utcnow()
    report = SendReport()
    due = session.scalars(
        select(Reminder)
        .where(Reminder.status == ReminderStatus.SCHEDULED, Reminder.scheduled_at <= now)
        .order_by(Reminder.scheduled_at)
    ).all()
    for reminder in due:
        beneficiary = session.get(Beneficiary, reminder.beneficiary_id)
        visit = session.get(AncVisit, reminder.anc_visit_id) if reminder.anc_visit_id else None
        if beneficiary is None or beneficiary.deleted_at is not None:
            _cancel(reminder, "beneficiary_deleted")
        elif not has_active_consent(session, beneficiary.id, ConsentScope.REMINDERS):
            _cancel(reminder, "no_reminders_consent")
        elif visit is not None and (
            visit.status is not AncVisitStatus.PLANNED or visit.deleted_at is not None
        ):
            _cancel(reminder, "visit_not_planned")
        elif (adapter := adapter_for(beneficiary.preferred_channel)) is None:
            _cancel(reminder, "no_channel")
        else:
            channel = beneficiary.preferred_channel
            try:
                adapter.send(reminder, channel)
            except ChannelError as exc:
                reminder.status = ReminderStatus.FAILED
                reminder.last_error = str(exc)[:200]
                report.failed += 1
            else:
                reminder.status = ReminderStatus.SENT
                reminder.channel = channel
                reminder.sent_at = utcnow()
                reminder.last_error = None
                report.sent += 1
            continue
        report.cancelled += 1
    session.commit()
    return report
