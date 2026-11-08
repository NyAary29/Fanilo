"""Environnement Alembic : URL lue depuis les settings FANILO, jamais codée en dur.

Une URL peut être injectée programmatiquement (tests) via
``config.attributes["database_url"]``.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import Connection

from app.core.config import get_settings
from app.db.models import Base
from app.db.session import make_engine
from app.db.types import UTCDateTime

config = context.config

if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata


def _database_url() -> str:
    return config.attributes.get("database_url") or get_settings().database_url


def _render_item(type_: str, obj: object, autogen_context: object) -> str | bool:
    """Rend UTCDateTime comme un DateTime(timezone=True) standard : les migrations
    ne doivent pas dépendre du code applicatif."""
    if type_ == "type" and isinstance(obj, UTCDateTime):
        return "sa.DateTime(timezone=True)"
    return False


def _configure(connection: Connection | None = None, **kwargs: object) -> None:
    context.configure(
        target_metadata=target_metadata,
        compare_type=True,
        render_item=_render_item,
        # SQLite (tests) ne sait pas modifier une table en place.
        render_as_batch=connection is not None and connection.dialect.name == "sqlite",
        connection=connection,
        **kwargs,
    )


def run_migrations_offline() -> None:
    """Génère le SQL sans connexion (``alembic upgrade head --sql``)."""
    _configure(url=_database_url(), literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connection = config.attributes.get("connection")
    if connection is not None:
        _configure(connection)
        with context.begin_transaction():
            context.run_migrations()
        return

    engine = make_engine(_database_url())
    try:
        with engine.connect() as conn:
            _configure(conn)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
