"""Engine et sessions SQLAlchemy, construits à partir des settings."""

from collections.abc import Iterator
from functools import lru_cache
from typing import Any

from fastapi import Depends
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import Settings, get_settings


def make_engine(url: str, *, echo: bool = False, **kwargs: Any) -> Engine:
    """Crée un engine ; active les clés étrangères pour SQLite (tests)."""
    if url.startswith("sqlite"):
        kwargs.setdefault("connect_args", {"check_same_thread": False})
    else:
        kwargs.setdefault("pool_pre_ping", True)
    engine = create_engine(url, echo=echo, **kwargs)

    if engine.dialect.name == "sqlite":

        @event.listens_for(engine, "connect")
        def _enable_sqlite_fk(dbapi_conn: Any, _record: Any) -> None:
            cursor = dbapi_conn.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return engine


@lru_cache(maxsize=4)
def _session_factory(url: str, echo: bool) -> sessionmaker[Session]:
    return sessionmaker(bind=make_engine(url, echo=echo), expire_on_commit=False)


def get_session_factory(settings: Settings) -> sessionmaker[Session]:
    return _session_factory(settings.database_url, settings.database_echo)


def get_db(settings: Settings = Depends(get_settings)) -> Iterator[Session]:  # noqa: B008
    """Dépendance FastAPI : une session par requête, annulée en cas d'erreur."""
    session = get_session_factory(settings)()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
