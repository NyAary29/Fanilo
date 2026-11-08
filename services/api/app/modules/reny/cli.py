"""Commandes RENY.

Envoi des rappels échus (à planifier par cron, ex. toutes les 15 minutes) ::

    uv run python -m app.modules.reny.cli send-due-reminders
"""

import argparse
import sys

from app.core.config import get_settings
from app.db.session import get_session_factory
from app.modules.reny.reminders import send_due_reminders


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fanilo-reny", description="Tâches RENY de FANILO")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("send-due-reminders", help="Envoyer les rappels échus")
    args = parser.parse_args(argv)
    if args.command == "send-due-reminders":
        factory = get_session_factory(get_settings())
        with factory() as session:
            report = send_due_reminders(session)
        print(
            f"Rappels envoyés : {report.sent}, échecs : {report.failed}, "
            f"annulés : {report.cancelled}."
        )
        return 0
    return 2  # pragma: no cover


if __name__ == "__main__":
    sys.exit(main())
