"""Tests de la couche base de données et de la migration initiale."""

import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import inspect
from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import StaleDataError

from app.db.base import SyncMixin
from app.db.models import Base
from app.db.session import make_engine
from app.modules.users.models import User
from app.modules.users.roles import Role

API_DIR = Path(__file__).resolve().parents[1]


def _user(**kwargs) -> User:
    defaults = {"login": "ac.fictif", "password_hash": "x", "role": Role.COMMUNITY_AGENT}
    return User(**(defaults | kwargs))


def test_insert_sets_sync_columns(db: Session):
    user = _user()
    db.add(user)
    db.commit()
    assert isinstance(user.id, uuid.UUID)
    assert user.version == 1
    assert user.created_at.tzinfo is not None
    assert user.updated_at.tzinfo is not None
    assert user.deleted_at is None


def test_update_increments_version_and_updated_at(db: Session, make_site):
    user = _user()
    db.add(user)
    db.commit()
    first_updated = user.updated_at

    user.is_active = False
    db.commit()
    assert user.version == 2

    user.site_id = make_site().id
    db.commit()
    db.refresh(user)
    assert user.version == 3
    assert user.updated_at >= first_updated


def test_client_generated_id_is_kept(db: Session):
    client_id = uuid.uuid4()
    db.add(_user(id=client_id))
    db.commit()
    assert db.get(User, client_id) is not None


def test_concurrent_update_raises_conflict(session_factory):
    with session_factory() as s1:
        user = _user()
        s1.add(user)
        s1.commit()
        user_id = user.id

    with session_factory() as s1, session_factory() as s2:
        a = s1.get(User, user_id)
        b = s2.get(User, user_id)
        a.is_active = False
        s1.commit()
        b.site_id = uuid.uuid4()
        with pytest.raises(StaleDataError):
            s2.commit()


def test_soft_delete(db: Session):
    user = _user()
    db.add(user)
    db.commit()
    user.soft_delete()
    db.commit()
    assert user.is_deleted
    assert user.version == 2
    assert db.get(User, user.id) is not None  # pas de suppression physique


def test_user_model_uses_sync_mixin():
    assert issubclass(User, SyncMixin)


def _alembic_config(url: str) -> Config:
    cfg = Config(str(API_DIR / "alembic.ini"))
    cfg.attributes["database_url"] = url
    cfg.attributes["configure_logger"] = False
    return cfg


def test_migration_matches_models_on_sqlite(tmp_path: Path):
    url = f"sqlite:///{tmp_path / 'migration.db'}"
    cfg = _alembic_config(url)
    command.upgrade(cfg, "head")

    engine = make_engine(url)
    try:
        with engine.connect() as conn:
            assert set(Base.metadata.tables) <= set(inspect(conn).get_table_names())
            ctx = MigrationContext.configure(conn, opts={"compare_type": True})
            assert compare_metadata(ctx, Base.metadata) == []
    finally:
        engine.dispose()

    command.downgrade(cfg, "base")
    engine = make_engine(url)
    try:
        with engine.connect() as conn:
            assert "users" not in inspect(conn).get_table_names()
    finally:
        engine.dispose()


def test_migration_renders_postgresql_sql(capsys):
    """Mode hors ligne : génère le DDL PostgreSQL sans serveur."""
    cfg = _alembic_config("postgresql+psycopg://fictif@localhost:5432/fictif")
    command.upgrade(cfg, "head", sql=True)
    sql = capsys.readouterr().out
    assert "CREATE TABLE users" in sql
    assert "id UUID NOT NULL" in sql
    assert "TIMESTAMP WITH TIME ZONE" in sql
    assert "ck_users_user_role" in sql
    # Lot P0.4 / P0.5 / P0.7 / F-10 (migration 0002).
    for table in ("sites", "audit_events", "beneficiaries", "beneficiary_identities",
                  "consents", "pregnancies", "anc_visits", "reminders", "sync_changes"):
        assert f"CREATE TABLE {table}" in sql
    assert "fk_users_site_id_sites" in sql
    assert "ck_consents_consent_scope" in sql
    assert "UPDATE alembic_version SET version_num='0002'" in sql


def test_migration_0003_backfills_sync_seq(tmp_path: Path):
    """Lignes existantes avant 0003 : sync_seq attribué dans l'ordre (updated_at,
    id), compteur positionné après, et les écritures suivantes continuent."""
    from datetime import UTC, datetime, timedelta

    from sqlalchemy import text

    url = f"sqlite:///{tmp_path / 'backfill.db'}"
    cfg = _alembic_config(url)
    command.upgrade(cfg, "0002")
    engine = make_engine(url)
    t0 = datetime(2026, 1, 1, tzinfo=UTC)
    ids = [uuid.uuid4() for _ in range(3)]
    try:
        with engine.begin() as conn:
            for index, (site_id, offset) in enumerate(zip(ids, (2, 0, 1), strict=True)):
                conn.execute(
                    text(
                        "INSERT INTO sites (id, name, kind, code, district, region, is_active,"
                        " created_at, updated_at, version) VALUES (:id, 'S', 'csb', :code,"
                        " 'D', 'R', 1, :t, :t, 1)"
                    ),
                    {
                        "id": site_id.hex,
                        "code": f"CSB-{index}",
                        "t": (t0 + timedelta(hours=offset)).isoformat(sep=" "),
                    },
                )
    finally:
        engine.dispose()

    command.upgrade(cfg, "head")
    engine = make_engine(url)
    try:
        with engine.connect() as conn:
            rows = dict(conn.execute(text("SELECT id, sync_seq FROM sites")).all())
            counter = conn.execute(text("SELECT value FROM sync_counter WHERE id = 1")).scalar()
        by_id = {uuid.UUID(k): v for k, v in rows.items()}
        # Ordre des updated_at : ids[1] (t0), ids[2] (t0+1h), ids[0] (t0+2h).
        assert [by_id[ids[1]], by_id[ids[2]], by_id[ids[0]]] == [1, 2, 3]
        assert counter == 3
        with Session(engine) as session:
            from app.modules.sites.models import Site

            site = session.get(Site, ids[0])
            site.name = "Renommé"
            session.commit()
            assert site.sync_seq == 4
    finally:
        engine.dispose()


def test_migration_0003_renders_postgresql_sql(capsys):
    cfg = _alembic_config("postgresql+psycopg://fictif@localhost:5432/fictif")
    command.upgrade(cfg, "0002:0003", sql=True)
    sql = capsys.readouterr().out
    for table in ("sync_counter", "content_items", "interactions", "alerts", "alert_events",
                  "referrals"):
        assert f"CREATE TABLE {table}" in sql
    assert "INSERT INTO sync_counter (id, value) VALUES (1, 0)" in sql
    assert "ALTER TABLE sites ALTER COLUMN sync_seq DROP DEFAULT" in sql
    assert "CREATE UNIQUE INDEX ix_alerts_sync_seq ON alerts (sync_seq)" in sql
    assert "ck_alerts_alert_status" in sql
    assert "UPDATE alembic_version SET version_num='0003'" in sql
