import pytest
from cryptography.fernet import Fernet
from pydantic import ValidationError

from app.core.config import Environment, Settings

STRONG_SECRET = "x" * 48
FERNET_KEY = Fernet.generate_key().decode()


def _settings(**kwargs) -> Settings:
    return Settings(_env_file=None, **kwargs)


def test_development_defaults_are_accepted():
    settings = _settings()
    assert settings.environment is Environment.DEVELOPMENT
    assert settings.allow_demo_content is False
    assert settings.docs_enabled is True


@pytest.mark.parametrize("secret", ["", "change-me-dev-only", "short-secret"])
def test_production_rejects_weak_secret(secret):
    with pytest.raises(ValidationError, match="FANILO_SECRET_KEY"):
        _settings(environment="production", secret_key=secret)


def test_production_rejects_demo_content():
    with pytest.raises(ValidationError, match="FANILO_ALLOW_DEMO_CONTENT"):
        _settings(environment="production", secret_key=STRONG_SECRET, allow_demo_content=True)


def test_production_rejects_wildcard_cors():
    with pytest.raises(ValidationError, match="CORS"):
        _settings(environment="production", secret_key=STRONG_SECRET, cors_origins="*")


def test_production_disables_docs_by_default():
    settings = _settings(
        environment="production", secret_key=STRONG_SECRET, data_encryption_key=FERNET_KEY
    )
    assert settings.docs_enabled is False


def test_cors_origins_parsed_from_comma_separated_env(monkeypatch):
    monkeypatch.setenv("FANILO_CORS_ORIGINS", "http://a.test, http://b.test,")
    assert _settings().cors_origins == ["http://a.test", "http://b.test"]


def test_production_requires_data_encryption_key():
    with pytest.raises(ValidationError, match="FANILO_DATA_ENCRYPTION_KEY"):
        _settings(environment="production", secret_key=STRONG_SECRET)


def test_invalid_data_encryption_key_rejected():
    with pytest.raises(ValidationError, match="FANILO_DATA_ENCRYPTION_KEY invalide"):
        _settings(data_encryption_key="pas-une-cle-fernet")


def test_ephemeral_key_generated_outside_production(caplog):
    with caplog.at_level("WARNING", logger="fanilo.config"):
        settings = _settings(environment="test")
    assert settings.data_encryption_key is not None
    Fernet(settings.data_encryption_key.get_secret_value().encode())
    assert "ÉPHÉMÈRE" in caplog.text


def test_key_rotation_accepts_several_keys():
    old, new = Fernet.generate_key().decode(), Fernet.generate_key().decode()
    settings = _settings(data_encryption_key=f"{new},{old}")
    assert settings.data_encryption_key is not None
