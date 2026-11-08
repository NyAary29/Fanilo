"""Rôles définis par le cahier des charges."""

from enum import StrEnum


class Role(StrEnum):
    COMMUNITY_AGENT = "community_agent"  # Agent communautaire (AC)
    CLINICAL_ADVISOR = "clinical_advisor"  # Conseiller / référent clinique
    CSB_HEAD = "csb_head"  # Chef CSB / professionnel de santé
    CLINICAL_LEAD = "clinical_lead"  # Responsable clinique
    ADMIN = "admin"  # Administrateur
    DATA_OFFICER = "data_officer"  # Responsable données / sécurité
    TECHNICAL = "technical"  # Équipe technique : AUCUN accès aux données nominatives


# Rôles autorisés à consulter des données nominatives de bénéficiaires.
# Les futurs modules manipulant de telles données doivent utiliser
# ``require_roles(*NOMINATIVE_DATA_ROLES)`` (ou un sous-ensemble plus strict).
NOMINATIVE_DATA_ROLES: frozenset[Role] = frozenset(
    {
        Role.COMMUNITY_AGENT,
        Role.CLINICAL_ADVISOR,
        Role.CSB_HEAD,
        Role.CLINICAL_LEAD,
    }
)
