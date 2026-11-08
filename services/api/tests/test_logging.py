import json
import logging

from fastapi.testclient import TestClient

from app.core.config import Environment, Settings
from app.core.logging import JsonFormatter
from app.main import create_app


def test_json_formatter_emits_valid_json_with_extras():
    record = logging.makeLogRecord({"msg": "bonjour", "levelname": "INFO", "status": 200})
    payload = json.loads(JsonFormatter().format(record))
    assert payload["msg"] == "bonjour"
    assert payload["status"] == 200
    assert "ts" in payload


def test_request_log_never_contains_query_string(caplog):
    settings = Settings(_env_file=None, environment=Environment.TEST)
    client = TestClient(create_app(settings))
    # create_app reconfigure les handlers racine : on rebranche celui de caplog.
    logging.getLogger().addHandler(caplog.handler)
    with caplog.at_level(logging.INFO, logger="fanilo.request"):
        client.get("/health?telephone=0340000000")
    records = [r for r in caplog.records if r.name == "fanilo.request"]
    assert records, "aucun log de requête émis"
    for record in records:
        serialized = JsonFormatter().format(record)
        assert "0340000000" not in serialized
        assert json.loads(serialized)["route"] == "/health"


def test_httpx_logger_does_not_log_urls_at_info():
    settings = Settings(_env_file=None, environment=Environment.TEST)
    create_app(settings)
    assert not logging.getLogger("httpx").isEnabledFor(logging.INFO)
