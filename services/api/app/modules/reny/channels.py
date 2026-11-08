"""Adaptateurs de canal pour l'envoi des rappels.

En P0, seul l'adaptateur ``log`` existe : il n'appelle aucun opérateur et
journalise uniquement des identifiants techniques (jamais de nom ni de
téléphone). Un futur adaptateur (RapidPro, SMS, IVR — à confirmer) implémente
:class:`ChannelAdapter` et s'enregistre dans :data:`ADAPTERS`.
"""

import logging
from typing import Protocol

from app.modules.beneficiaries.models import PreferredChannel
from app.modules.reny.models import Reminder


class ChannelError(Exception):
    """Échec d'envoi ; le message doit rester technique (pas de donnée personnelle)."""


class ChannelAdapter(Protocol):
    name: str

    def send(self, reminder: Reminder, channel: PreferredChannel) -> None:
        """Envoie le rappel sur ``channel`` ; lève :class:`ChannelError` en cas d'échec."""
        ...


class LogChannelAdapter:
    """Adaptateur de démonstration : écrit une ligne de log, n'envoie rien."""

    name = "log"

    def __init__(self) -> None:
        self.logger = logging.getLogger("fanilo.reminders.log_channel")

    def send(self, reminder: Reminder, channel: PreferredChannel) -> None:
        self.logger.info(
            "reminder_sent",
            extra={
                "reminder_id": str(reminder.id),
                "channel": str(channel),
                "message_code": reminder.message_code,
                "adapter": self.name,
            },
        )


ADAPTERS: dict[str, ChannelAdapter] = {"log": LogChannelAdapter()}

# Canal préféré → adaptateur. En P0, tout passe par ``log`` (aucun opérateur).
CHANNEL_ROUTING: dict[PreferredChannel, str] = {
    PreferredChannel.SMS: "log",
    PreferredChannel.IVR: "log",
    PreferredChannel.AC_VISIT: "log",
}


def adapter_for(channel: PreferredChannel) -> ChannelAdapter | None:
    """Adaptateur du canal, ou ``None`` si le canal ne permet aucun envoi (``none``)."""
    name = CHANNEL_ROUTING.get(channel)
    return ADAPTERS[name] if name else None
