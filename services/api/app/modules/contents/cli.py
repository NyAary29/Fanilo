"""Commandes des contenus.

Import du catalogue de contenus de DÉMONSTRATION (non validés cliniquement) ::

    uv run python -m app.modules.contents.cli import-demo
    uv run python -m app.modules.contents.cli import-demo --path config/contents.demo.yaml

Refusé en production. La base doit être migrée (``uv run alembic upgrade head``).
"""

import argparse
import sys
from pathlib import Path

from app.core.config import DEFAULT_CONTENTS_DEMO_PATH, Environment, Settings, get_settings
from app.db.session import get_session_factory
from app.modules.contents.catalog import CatalogError, import_catalog, load_catalog


def import_demo(path: Path, settings: Settings | None = None) -> int:
    settings = settings or get_settings()
    if settings.environment is Environment.PRODUCTION:
        print("Erreur : import de contenus de démonstration refusé en production.", file=sys.stderr)
        return 1
    try:
        catalog = load_catalog(path)
    except CatalogError as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 1
    factory = get_session_factory(settings)
    with factory() as session, session.begin():
        report = import_catalog(session, catalog)
    print(
        f"Contenus de DÉMONSTRATION importés : {report.created}, déjà présents : "
        f"{report.skipped}. Servis seulement si FANILO_ALLOW_DEMO_CONTENT=true."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fanilo-contents", description="Contenus FANILO")
    sub = parser.add_subparsers(dest="command", required=True)
    demo = sub.add_parser("import-demo", help="Importer le catalogue de démonstration")
    demo.add_argument("--path", type=Path, default=DEFAULT_CONTENTS_DEMO_PATH)
    args = parser.parse_args(argv)
    if args.command == "import-demo":
        return import_demo(args.path)
    return 2  # pragma: no cover


if __name__ == "__main__":
    sys.exit(main())
