"""Alertes : création, destinataires, acquittement, résolution, escalade.

Choix du destinataire (aucune alerte n'est perdue silencieusement) :

1. un ``csb_head`` actif rattaché au site de la bénéficiaire ou, à défaut, au
   plus proche site ancêtre (ex. zone communautaire → CSB parent) ;
2. sinon un ``clinical_advisor`` actif dont le périmètre contient ce site
   (même site ou site ancêtre, le plus proche d'abord) ;
3. sinon l'alerte est créée **sans destinataire**, au statut ``escalated``
   d'emblée, et une erreur est journalisée.

Le suppléant est l'utilisateur éligible suivant dans le même ordre (``login``
départage). Un message n'indique jamais une prise en charge tant que
l'acquittement n'est pas enregistré.
"""

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ForbiddenError, NotFoundError, StateConflictError
from app.db.types import utcnow
from app.modules.alerts.models import (
    Alert,
    AlertEvent,
    AlertEventType,
    AlertSeverity,
    AlertStatus,
)
from app.modules.audit.service import AuditAction, record_audit
from app.modules.sites.models import Site
from app.modules.sites.scope import ActorContext
from app.modules.users.models import User
from app.modules.users.roles import Role

logger = logging.getLogger("fanilo.alerts")

READ_ROLES: frozenset[Role] = frozenset(
    {Role.COMMUNITY_AGENT, Role.CSB_HEAD, Role.CLINICAL_ADVISOR, Role.CLINICAL_LEAD}
)
# Ordre de priorité des destinataires.
RECIPIENT_ROLES: tuple[Role, ...] = (Role.CSB_HEAD, Role.CLINICAL_ADVISOR)
ACKNOWLEDGEABLE = (AlertStatus.OPEN, AlertStatus.ESCALATED)
NO_RECIPIENT_NOTE = "Aucun destinataire éligible : alerte escaladée dès sa création."


# --- Destinataires ------------------------------------------------------------


def site_chain(session: Session, site_id: uuid.UUID | None) -> list[uuid.UUID]:
    """Le site puis ses ancêtres, du plus proche au plus lointain (sans cycle)."""
    chain: list[uuid.UUID] = []
    current = site_id
    while current is not None and current not in chain:
        chain.append(current)
        current = session.scalar(select(Site.parent_site_id).where(Site.id == current))
    return chain


def eligible_users(session: Session, site_id: uuid.UUID | None) -> list[User]:
    """Destinataires possibles, par ordre de priorité (voir l'en-tête du module)."""
    chain = site_chain(session, site_id)
    if not chain:
        return []
    users = session.scalars(
        select(User).where(
            User.role.in_(RECIPIENT_ROLES),
            User.site_id.in_(chain),
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
    ).all()
    return sorted(
        users,
        key=lambda u: (RECIPIENT_ROLES.index(u.role), chain.index(u.site_id), u.login),
    )


def choose_recipients(
    session: Session, site_id: uuid.UUID | None, *, exclude: frozenset[uuid.UUID] = frozenset()
) -> tuple[User | None, User | None]:
    candidates = [u for u in eligible_users(session, site_id) if u.id not in exclude]
    recipient = candidates[0] if candidates else None
    backup = candidates[1] if len(candidates) > 1 else None
    return recipient, backup


def _event(
    session: Session,
    alert: Alert,
    type_: AlertEventType,
    actor: User | None,
    note: str | None = None,
    at: datetime | None = None,
) -> AlertEvent:
    event = AlertEvent(
        alert_id=alert.id,
        type=type_,
        actor_user_id=actor.id if actor is not None else None,
        note=note,
        at=at or utcnow(),
    )
    session.add(event)
    return event


# --- Création -----------------------------------------------------------------


@dataclass(frozen=True)
class AlertRequest:
    beneficiary_id: uuid.UUID | None
    site_id: uuid.UUID | None
    interaction_id: uuid.UUID | None
    rule_id: str
    ruleset_version: str
    severity: AlertSeverity
    response_minutes: int
    response_is_demo: bool
    is_demo: bool


def create_alert(session: Session, actor: User | None, request: AlertRequest) -> Alert:
    """Crée l'alerte et son journal (sans valider la transaction)."""
    now = utcnow()
    recipient, backup = choose_recipients(session, request.site_id)
    alert = Alert(
        id=uuid.uuid4(),
        beneficiary_id=request.beneficiary_id,
        site_id=request.site_id,
        interaction_id=request.interaction_id,
        rule_id=request.rule_id,
        ruleset_version=request.ruleset_version,
        severity=request.severity,
        status=AlertStatus.OPEN if recipient is not None else AlertStatus.ESCALATED,
        recipient_user_id=recipient.id if recipient is not None else None,
        backup_user_id=backup.id if backup is not None else None,
        due_at=now + timedelta(minutes=request.response_minutes),
        due_at_is_demo=request.response_is_demo,
        escalated_at=None if recipient is not None else now,
        is_demo=request.is_demo,
    )
    session.add(alert)
    session.flush()
    _event(session, alert, AlertEventType.CREATED, actor, at=now)
    if recipient is None:
        _event(session, alert, AlertEventType.ESCALATED, None, NO_RECIPIENT_NOTE, at=now)
        logger.error(
            "alert_without_recipient",
            extra={"alert_id": str(alert.id), "site_id": str(request.site_id)},
        )
    record_audit(session, actor, AuditAction.ALERT_CREATE, "alert", alert.id, site_id=alert.site_id)
    return alert


# --- Lecture et actions -------------------------------------------------------


def get_alert(ctx: ActorContext, alert_id: uuid.UUID) -> Alert:
    ctx.ensure_role(READ_ROLES)
    alert = ctx.session.get(Alert, alert_id)
    if alert is None or alert.deleted_at is not None:
        raise NotFoundError
    ctx.scope.ensure_contains(alert.site_id)
    return alert


def list_events(session: Session, alert: Alert) -> list[AlertEvent]:
    return list(
        session.scalars(
            select(AlertEvent).where(AlertEvent.alert_id == alert.id).order_by(AlertEvent.at)
        )
    )


def can_acknowledge(ctx: ActorContext, alert: Alert) -> bool:
    """Destinataire, suppléant, ou ``csb_head`` dont le périmètre contient le site."""
    user = ctx.actor
    if user.id in (alert.recipient_user_id, alert.backup_user_id):
        return True
    return user.role is Role.CSB_HEAD and ctx.scope.contains(alert.site_id)


def acknowledge(ctx: ActorContext, alert: Alert) -> Alert:
    if not can_acknowledge(ctx, alert):
        raise ForbiddenError("Seuls le destinataire, le suppléant ou le chef CSB acquittent.")
    if alert.status not in ACKNOWLEDGEABLE:
        raise StateConflictError(f"Alerte au statut « {alert.status} » : acquittement impossible.")
    now = utcnow()
    alert.status = AlertStatus.ACKNOWLEDGED
    alert.acknowledged_at = now
    alert.acknowledged_by_user_id = ctx.actor.id
    _event(ctx.session, alert, AlertEventType.ACKNOWLEDGED, ctx.actor, at=now)
    ctx.session.flush()
    record_audit(
        ctx.session, ctx.actor, AuditAction.ALERT_ACKNOWLEDGE, "alert", alert.id, alert.site_id
    )
    return alert


def resolve(ctx: ActorContext, alert: Alert, note: str) -> Alert:
    """Résolution : uniquement après acquittement (prise en charge enregistrée)."""
    if not (can_acknowledge(ctx, alert) or ctx.actor.role is Role.CLINICAL_LEAD):
        raise ForbiddenError
    if alert.status is not AlertStatus.ACKNOWLEDGED:
        raise StateConflictError("Une alerte doit être acquittée avant d'être résolue.")
    now = utcnow()
    alert.status = AlertStatus.RESOLVED
    alert.resolved_at = now
    _event(ctx.session, alert, AlertEventType.RESOLVED, ctx.actor, note.strip(), at=now)
    ctx.session.flush()
    record_audit(
        ctx.session, ctx.actor, AuditAction.ALERT_RESOLVE, "alert", alert.id, alert.site_id
    )
    return alert


def add_note(ctx: ActorContext, alert: Alert, note: str) -> AlertEvent:
    event = _event(ctx.session, alert, AlertEventType.NOTE, ctx.actor, note.strip())
    ctx.session.flush()
    record_audit(ctx.session, ctx.actor, AuditAction.ALERT_NOTE, "alert", alert.id, alert.site_id)
    return event


# --- Escalade (tâche planifiée) -----------------------------------------------


@dataclass
class EscalationReport:
    escalated: int = 0
    reassigned: int = 0
    without_recipient: int = 0


def escalate_overdue(session: Session, *, now: datetime | None = None) -> EscalationReport:
    """Escalade les alertes non acquittées après ``due_at`` et valide.

    - ``open`` et échue : statut ``escalated``, réassignée au suppléant (l'ancien
      destinataire devient suppléant et peut toujours acquitter) ; sans
      suppléant, un autre utilisateur éligible est recherché ;
    - ``escalated`` sans destinataire : un destinataire éligible est recherché
      (ex. compte créé depuis) ; sinon l'erreur est de nouveau journalisée.
    """
    now = now or utcnow()
    report = EscalationReport()
    overdue = session.scalars(
        select(Alert).where(
            Alert.status == AlertStatus.OPEN, Alert.due_at <= now, Alert.deleted_at.is_(None)
        )
    ).all()
    for alert in overdue:
        previous = alert.recipient_user_id
        new_recipient = alert.backup_user_id
        if new_recipient is None:
            exclude = frozenset({previous}) if previous else frozenset()
            candidate, _ = choose_recipients(session, alert.site_id, exclude=exclude)
            new_recipient = candidate.id if candidate is not None else None
        alert.status = AlertStatus.ESCALATED
        alert.escalated_at = now
        if new_recipient is not None:
            alert.recipient_user_id = new_recipient
            alert.backup_user_id = previous
            note = "Non acquittée à l'échéance : réassignée au suppléant."
            report.reassigned += 1
        else:
            note = "Non acquittée à l'échéance : aucun suppléant disponible."
            logger.error("alert_escalated_without_backup", extra={"alert_id": str(alert.id)})
        _event(session, alert, AlertEventType.ESCALATED, None, note, at=now)
        record_audit(session, None, AuditAction.ALERT_ESCALATE, "alert", alert.id, alert.site_id)
        report.escalated += 1

    orphans = session.scalars(
        select(Alert).where(
            Alert.status == AlertStatus.ESCALATED,
            Alert.recipient_user_id.is_(None),
            Alert.deleted_at.is_(None),
        )
    ).all()
    for alert in orphans:
        recipient, backup = choose_recipients(session, alert.site_id)
        if recipient is None:
            report.without_recipient += 1
            logger.error("alert_without_recipient", extra={"alert_id": str(alert.id)})
            continue
        alert.recipient_user_id = recipient.id
        alert.backup_user_id = backup.id if backup is not None else None
        _event(session, alert, AlertEventType.ESCALATED, None, "Destinataire attribué.", at=now)
        record_audit(session, None, AuditAction.ALERT_ESCALATE, "alert", alert.id, alert.site_id)
        report.reassigned += 1
    session.commit()
    return report
