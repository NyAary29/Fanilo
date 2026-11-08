"""Enregistrement des événements d'audit.

Usage (lot suivant : alertes, références, contenus, exports) ::

    from app.modules.audit.service import AuditAction, record_audit

    record_audit(session, user, AuditAction.REFERRAL_TRANSITION, "referral", referral.id,
                 site_id=beneficiary.site_id)
    session.commit()

``record_audit`` ajoute l'événement à la session **sans valider** : il est écrit
dans la même transaction que l'action tracée (tout ou rien). Ne jamais y
passer de texte libre, de nom, de téléphone ni de contenu médical.
"""

import hashlib
import hmac
import uuid
from enum import StrEnum

from sqlalchemy.orm import Session

from app.core.logging import request_id_ctx
from app.modules.audit.models import AuditEvent
from app.modules.users.models import User, normalize_login


class AuditAction(StrEnum):
    """Actions tracées. Les valeurs sont libres (``str``) : le lot suivant peut en
    ajouter, en gardant la forme ``<entité>.<verbe>``."""

    LOGIN_SUCCEEDED = "auth.login_succeeded"
    LOGIN_FAILED = "auth.login_failed"
    LOGIN_RATE_LIMITED = "auth.login_rate_limited"
    SITE_CREATE = "site.create"
    SITE_UPDATE = "site.update"
    USER_CREATE = "user.create"
    USER_UPDATE = "user.update"
    USER_ROLE_CHANGE = "user.role_change"
    USER_DEACTIVATE = "user.deactivate"
    BENEFICIARY_CREATE = "beneficiary.create"
    BENEFICIARY_UPDATE = "beneficiary.update"
    BENEFICIARY_DELETE = "beneficiary.delete"
    IDENTITY_READ = "identity.read"
    IDENTITY_WRITE = "identity.write"
    IDENTITY_DELETE = "identity.delete"
    CONSENT_CREATE = "consent.create"
    CONSENT_WITHDRAW = "consent.withdraw"
    CONSENT_DELETE = "consent.delete"
    PREGNANCY_CREATE = "pregnancy.create"
    PREGNANCY_UPDATE = "pregnancy.update"
    PREGNANCY_DELETE = "pregnancy.delete"
    ANC_VISIT_UPDATE = "anc_visit.update"
    ANC_VISIT_DELETE = "anc_visit.delete"
    CONTENT_SUBMIT = "content.submit"
    CONTENT_REJECT = "content.reject"
    CONTENT_VALIDATE = "content.validate"
    CONTENT_RETIRE = "content.retire"
    INTERACTION_ASK = "interaction.ask"
    INTERACTION_REVIEW = "interaction.review"
    ALERT_CREATE = "alert.create"
    ALERT_ACKNOWLEDGE = "alert.acknowledge"
    ALERT_RESOLVE = "alert.resolve"
    ALERT_NOTE = "alert.note"
    ALERT_ESCALATE = "alert.escalate"
    REFERRAL_CREATE = "referral.create"
    REFERRAL_UPDATE = "referral.update"
    REFERRAL_TRANSITION = "referral.transition"
    REFERRAL_DELETE = "referral.delete"


def record_audit(
    session: Session,
    actor: User | None,
    action: str,
    entity_type: str | None,
    entity_id: uuid.UUID | str | None,
    site_id: uuid.UUID | None = None,
    *,
    login_fingerprint: str | None = None,
) -> AuditEvent:
    """Ajoute un événement d'audit à la session (sans commit).

    ``request_id`` est lu dans le contexte de la requête HTTP courante (nul hors
    requête, ex. commande CLI).
    """
    event = AuditEvent(
        actor_user_id=actor.id if actor is not None else None,
        actor_role=str(actor.role) if actor is not None else None,
        action=str(action),
        entity_type=entity_type,
        entity_id=str(entity_id) if entity_id is not None else None,
        request_id=request_id_ctx.get(),
        site_id=site_id,
        login_fingerprint=login_fingerprint,
    )
    session.add(event)
    return event


def login_fingerprint(login: str, secret_key: str) -> str:
    """Empreinte HMAC-SHA256 d'un identifiant tenté : permet de corréler des
    tentatives sans stocker l'identifiant en clair."""
    digest = hmac.new(
        secret_key.encode("utf-8"), normalize_login(login).encode("utf-8"), hashlib.sha256
    )
    return digest.hexdigest()
