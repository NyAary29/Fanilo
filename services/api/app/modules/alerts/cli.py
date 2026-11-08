"""Commandes des alertes.

Escalade des alertes non acquittées à l'échéance (à planifier par cron, ex.
toutes les 5 minutes) ::

    uv run python -m app.modules.alerts.cli escalate
"""

import argparse
import sys

from app.core.config import get_settings
from app.db.session import get_session_factory
from app.modules.alerts.service import escalate_overdue


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fanilo-alerts", description="Tâches des alertes")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("escalate", help="Escalader les alertes non acquittées à l'échéance")
    args = parser.parse_args(argv)
    if args.command == "escalate":
        factory = get_session_factory(get_settings())
        with factory() as session:
            report = escalate_overdue(session)
        print(
            f"Alertes escaladées : {report.escalated}, réassignées : {report.reassigned}, "
            f"toujours sans destinataire : {report.without_recipient}."
        )
        return 1 if report.without_recipient else 0
    return 2  # pragma: no cover


if __name__ == "__main__":
    sys.exit(main())
