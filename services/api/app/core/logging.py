"""Logs structurés (JSON) et middleware de journalisation des requêtes.

Principe de confidentialité : on ne journalise JAMAIS les corps de requête,
les paramètres de requête (query string) ni les en-têtes d'authentification,
car ils peuvent contenir des données de santé ou des identifiants.
"""

import json
import logging
import time
import uuid
from contextvars import ContextVar
from datetime import UTC, datetime

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.config import LogFormat

request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)

REQUEST_ID_HEADER = "x-request-id"
_STD_ATTRS = set(vars(logging.makeLogRecord({}))) | {"message", "asctime"}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, object] = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if (rid := request_id_ctx.get()) is not None:
            payload["request_id"] = rid
        for key, value in vars(record).items():
            if key not in _STD_ATTRS and not key.startswith("_"):
                payload[key] = value
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False, default=str)


def configure_logging(level: str, fmt: LogFormat) -> None:
    handler = logging.StreamHandler()
    if fmt is LogFormat.JSON:
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
    # Uvicorn a son propre access log, qui inclut la query string : on le coupe
    # au profit de notre middleware.
    logging.getLogger("uvicorn.access").disabled = True
    # httpx journalise les URL complètes (query string incluse) au niveau INFO.
    logging.getLogger("httpx").setLevel(logging.WARNING)


class RequestLoggingMiddleware:
    """Attribue un identifiant à chaque requête et journalise méthode/route/statut/durée."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        self.logger = logging.getLogger("fanilo.request")

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        incoming = dict(scope.get("headers") or []).get(REQUEST_ID_HEADER.encode())
        request_id = _sanitize_request_id(incoming) or uuid.uuid4().hex
        token = request_id_ctx.set(request_id)
        start = time.perf_counter()
        status_code = 500

        async def send_wrapper(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                headers = list(message.get("headers", []))
                headers.append((REQUEST_ID_HEADER.encode(), request_id.encode()))
                message["headers"] = headers
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            route = scope.get("route")
            self.logger.info(
                "request",
                extra={
                    "method": scope["method"],
                    # Gabarit de route (ex. /patients/{id}) plutôt que le chemin réel,
                    # pour ne pas exposer d'identifiants dans les logs.
                    "route": getattr(route, "path", None) or "unmatched",
                    "status": status_code,
                    "duration_ms": round((time.perf_counter() - start) * 1000, 2),
                },
            )
            request_id_ctx.reset(token)


def _sanitize_request_id(raw: bytes | None) -> str | None:
    if not raw:
        return None
    value = raw.decode("latin-1")
    if len(value) > 64 or not all(c.isalnum() or c in "-_" for c in value):
        return None
    return value
