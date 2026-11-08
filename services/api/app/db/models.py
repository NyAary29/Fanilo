"""Registre des modèles : importer ce module charge toutes les tables.

Utilisé par Alembic (autogénération) et par les tests (``create_all``).
"""

from app.db.base import Base, SyncCounter
from app.modules.alerts.models import Alert, AlertEvent
from app.modules.audit.models import AuditEvent
from app.modules.auth.models import RefreshToken
from app.modules.beneficiaries.models import Beneficiary, BeneficiaryIdentity, Consent
from app.modules.contents.models import ContentItem
from app.modules.interactions.models import Interaction
from app.modules.referrals.models import Referral
from app.modules.reny.models import AncVisit, Pregnancy, Reminder
from app.modules.sites.models import Site
from app.modules.sync.models import SyncChange
from app.modules.users.models import User

__all__ = [
    "Alert",
    "AlertEvent",
    "AncVisit",
    "AuditEvent",
    "Base",
    "Beneficiary",
    "BeneficiaryIdentity",
    "Consent",
    "ContentItem",
    "Interaction",
    "Pregnancy",
    "Referral",
    "RefreshToken",
    "Reminder",
    "Site",
    "SyncChange",
    "SyncCounter",
    "User",
]
