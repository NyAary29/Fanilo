from fastapi.testclient import TestClient

from app.core.config import Environment, Settings
from app.main import create_app


def _client(**overrides) -> TestClient:
    settings = Settings(_env_file=None, environment=Environment.TEST, **overrides)
    return TestClient(create_app(settings))


def test_health_returns_ok_and_version():
    response = _client().get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": "0.1.0"}


def test_response_carries_request_id():
    response = _client().get("/health")
    assert len(response.headers["x-request-id"]) == 32


def test_valid_incoming_request_id_is_propagated():
    response = _client().get("/health", headers={"X-Request-ID": "abc-123_XYZ"})
    assert response.headers["x-request-id"] == "abc-123_XYZ"


def test_malicious_incoming_request_id_is_replaced():
    response = _client().get("/health", headers={"X-Request-ID": "bad id\nwith newline"})
    assert response.headers["x-request-id"] != "bad id\nwith newline"
    assert response.headers["x-request-id"].isalnum()


def test_docs_disabled_when_requested():
    client = _client(enable_docs=False)
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_docs_enabled_by_default_outside_production():
    assert _client().get("/openapi.json").status_code == 200
