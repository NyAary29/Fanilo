"""Fixtures communes : base SQLite en mémoire, application et comptes fictifs.

Les tests tournent sur SQLite (pas de PostgreSQL requis) grâce aux types
portables (Uuid, UTCDateTime). Toutes les données sont fictives.
"""

import uuid
from collections.abc import Callable, Iterator

import pytest
from cryptography.fernet import Fernet
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db.models import Base
from app.db.session import get_db, make_engine
from app.main import create_app
from app.modules.auth.tokens import create_access_token
from app.modules.sites.models import Site, SiteKind
from app.modules.users.models import User
from app.modules.users.roles import Role
from app.modules.users.service import create_user

TEST_PASSWORD = "mot-de-passe-fictif-123"


@pytest.fixture
def settings() -> Settings:
    return Settings(
        _env_file=None,
        environment="test",
        secret_key="cle-de-test-fictive-" + "x" * 32,
        database_url="sqlite://",
        log_format="text",
        login_max_attempts=3,
        login_window_seconds=60,
        data_encryption_key=Fernet.generate_key().decode(),
    )


@pytest.fixture
def engine(settings: Settings) -> Iterator[Engine]:
    engine = make_engine(settings.database_url, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture
def session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, expire_on_commit=False)


@pytest.fixture
def db(session_factory: sessionmaker[Session]) -> Iterator[Session]:
    with session_factory() as session:
        yield session


@pytest.fixture
def app(settings: Settings, session_factory: sessionmaker[Session]) -> FastAPI:
    app = create_app(settings)

    def _get_db() -> Iterator[Session]:
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = _get_db
    return app


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def make_user(session_factory: sessionmaker[Session]) -> Callable[..., User]:
    def _make(
        login: str = "agent.test",
        role: Role = Role.COMMUNITY_AGENT,
        password: str = TEST_PASSWORD,
        is_active: bool = True,
        site_id: uuid.UUID | None = None,
    ) -> User:
        with session_factory() as session:
            user = create_user(session, login=login, password=password, role=role, site_id=site_id)
            user.is_active = is_active
            session.commit()
            return user

    return _make


@pytest.fixture
def make_site(session_factory: sessionmaker[Session]) -> Callable[..., Site]:
    """Crée un site fictif."""

    def _make(
        code: str = "CSB-FICTIF",
        kind: SiteKind = SiteKind.CSB,
        parent_site_id: uuid.UUID | None = None,
        name: str | None = None,
    ) -> Site:
        with session_factory() as session:
            site = Site(
                name=name or f"Site fictif {code}",
                kind=kind,
                code=code,
                district="District fictif",
                region="Région fictive",
                parent_site_id=parent_site_id,
            )
            session.add(site)
            session.commit()
            return site

    return _make


class World:
    """Jeu de données fictif : site A (avec une zone enfant A1) et site B, et un
    compte par rôle. ``headers(nom)`` renvoie un en-tête Bearer prêt à l'emploi."""

    def __init__(self, settings: Settings, make_site, make_user) -> None:
        self.settings = settings
        self.site_a = make_site("CSB-A")
        self.zone_a1 = make_site(
            "ZONE-A1", kind=SiteKind.COMMUNITY_ZONE, parent_site_id=self.site_a.id
        )
        self.site_b = make_site("CSB-B")
        self.users: dict[str, User] = {
            "ac_a": make_user("ac.a", Role.COMMUNITY_AGENT, site_id=self.site_a.id),
            "ac_a1": make_user("ac.a1", Role.COMMUNITY_AGENT, site_id=self.zone_a1.id),
            "ac_b": make_user("ac.b", Role.COMMUNITY_AGENT, site_id=self.site_b.id),
            "head_a": make_user("chef.a", Role.CSB_HEAD, site_id=self.site_a.id),
            "advisor_a": make_user("conseil.a", Role.CLINICAL_ADVISOR, site_id=self.site_a.id),
            "lead": make_user("resp.clinique", Role.CLINICAL_LEAD),
            "admin": make_user("admin.fictif", Role.ADMIN),
            "data": make_user("donnees.fictif", Role.DATA_OFFICER),
            "tech": make_user("tech.fictif", Role.TECHNICAL, site_id=self.site_a.id),
        }

    def headers(self, name: str) -> dict[str, str]:
        token, _ = create_access_token(self.users[name], self.settings)
        return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def world(settings: Settings, make_site, make_user) -> World:
    return World(settings, make_site, make_user)
