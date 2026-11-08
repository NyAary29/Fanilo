"""Commandes d'administration des comptes.

Création du premier administrateur (aucun mot de passe par défaut) ::

    uv run python -m app.modules.users.cli create-admin --login admin

Le mot de passe est demandé de façon interactive (deux fois), ou lu sur
l'entrée standard avec ``--password-stdin`` (déploiement automatisé).
La base doit déjà être migrée (``uv run alembic upgrade head``).
"""

import argparse
import getpass
import sys

from app.core.config import get_settings
from app.db.session import get_session_factory
from app.modules.users.roles import Role
from app.modules.users.service import UserError, create_user, validate_password


def _read_password(from_stdin: bool) -> str:
    if from_stdin:
        return sys.stdin.readline().rstrip("\r\n")
    first = getpass.getpass("Mot de passe : ")
    second = getpass.getpass("Confirmer le mot de passe : ")
    if first != second:
        raise UserError("Les deux mots de passe ne correspondent pas.")
    return first


def create_admin(login: str, *, password_stdin: bool = False) -> int:
    try:
        password = _read_password(password_stdin)
        validate_password(password)
        factory = get_session_factory(get_settings())
        with factory() as session, session.begin():
            user = create_user(session, login=login, password=password, role=Role.ADMIN)
            user_id = user.id
    except UserError as exc:
        print(f"Erreur : {exc}", file=sys.stderr)
        return 1
    print(f"Administrateur créé (id={user_id}).")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fanilo-users", description="Gestion des comptes FANILO")
    sub = parser.add_subparsers(dest="command", required=True)
    admin = sub.add_parser("create-admin", help="Créer un compte administrateur")
    admin.add_argument("--login", required=True, help="Nom d'utilisateur ou téléphone")
    admin.add_argument(
        "--password-stdin",
        action="store_true",
        help="Lire le mot de passe sur l'entrée standard (une ligne)",
    )
    args = parser.parse_args(argv)
    if args.command == "create-admin":
        return create_admin(args.login, password_stdin=args.password_stdin)
    return 2  # pragma: no cover


if __name__ == "__main__":
    sys.exit(main())
