"""Erreurs métier, indépendantes de HTTP.

Les services lèvent ces erreurs ; les routeurs REST les traduisent en réponses
``{"detail": ...}`` (gestionnaire enregistré dans ``app.main``) et la
synchronisation les traduit en résultats ``rejected`` ou ``conflict``.
"""


class DomainError(Exception):
    """Erreur métier portant un statut HTTP indicatif et un message en français."""

    status_code: int = 400
    default_detail: str = "Requête invalide."
    # Code stable, renvoyé par la synchronisation dans ``error: {code, message}``.
    default_code: str = "error"

    def __init__(self, detail: str | None = None, *, code: str | None = None) -> None:
        self.detail = detail or self.default_detail
        self.code = code or self.default_code
        super().__init__(self.detail)


class NotFoundError(DomainError):
    """Ressource introuvable ou hors périmètre (on ne révèle pas son existence)."""

    status_code = 404
    default_detail = "Ressource introuvable."
    default_code = "not_found"


class ForbiddenError(DomainError):
    status_code = 403
    default_detail = "Accès refusé."
    default_code = "forbidden"


class VersionConflictError(DomainError):
    """Version absente ou périmée : le client doit relire l'état serveur."""

    status_code = 409
    default_detail = "Conflit de version : l'enregistrement a été modifié entre-temps."
    default_code = "version_conflict"


class StateConflictError(DomainError):
    """Opération incompatible avec l'état courant (ex. consentement déjà retiré)."""

    status_code = 409
    default_detail = "Opération incompatible avec l'état actuel."
    default_code = "invalid_transition"


class InvalidDataError(DomainError):
    status_code = 422
    default_detail = "Données invalides."
    default_code = "validation_error"


class ConsentRequiredError(InvalidDataError):
    """Traitement refusé faute de consentement actif."""

    default_code = "consent_required"
    default_detail = "Consentement actif requis."


def check_version(current: int, expected: int | None) -> None:
    """Lève :class:`VersionConflictError` si ``expected`` est absent ou différent."""
    if expected is None or expected != current:
        raise VersionConflictError
