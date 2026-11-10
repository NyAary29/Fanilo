"""Client minimal de l'API OpenAI (transcription et réponses structurées).

Aucun texte ni audio n'est journalisé. Toute erreur réseau, HTTP ou de format lève
`OpenAiError` : l'appelant bascule alors sur le secours local ou sur un transfert humain.
"""

from __future__ import annotations

import json
from typing import Any

import httpx


class OpenAiError(Exception):
    """Échec d'appel à OpenAI (code court, sans donnée de l'usager)."""


class OpenAiClient:
    def __init__(
        self,
        api_key: str,
        *,
        base_url: str = "https://api.openai.com/v1",
        timeout_s: float = 15.0,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._client = httpx.Client(
            base_url=base_url.rstrip("/"),
            timeout=timeout_s,
            headers={"Authorization": f"Bearer {api_key}"},
            transport=transport,
        )
        self._no_language_models: set[str] = set()

    def _post(self, path: str, **kwargs: Any) -> dict[str, Any]:
        try:
            response = self._client.post(path, **kwargs)
        except httpx.HTTPError as exc:
            raise OpenAiError(f"network_{type(exc).__name__}") from exc
        if response.status_code >= 400:
            # Code d'erreur OpenAI (ex. invalid_api_key, unsupported_language) : jamais de
            # donnée de l'usager dans ce message.
            code = ""
            try:
                err = response.json().get("error") or {}
                code = str(err.get("code") or err.get("type") or "")[:60]
                param = str(err.get("param") or "")[:30]
                code = f"{code}:{param}" if param else code
            except (ValueError, AttributeError):
                pass
            raise OpenAiError(
                f"http_{response.status_code}_{code}" if code else f"http_{response.status_code}"
            )
        try:
            data = response.json()
        except ValueError as exc:
            raise OpenAiError("invalid_json") from exc
        if not isinstance(data, dict):
            raise OpenAiError("invalid_json")
        return data


    def transcribe(
        self, *, audio: bytes, filename: str, content_type: str, model: str, language: str
    ) -> str:
        # Aucune consigne (« prompt ») : le modèle la recopie ou s'en inspire pour inventer
        # une phrase quand l'audio ne contient pas de parole.
        form = {"model": model, "response_format": "json"}
        if language and model not in self._no_language_models:
            form["language"] = language
        files = {"file": (filename, audio, content_type)}
        try:
            data = self._post("/audio/transcriptions", files=files, data=form)
        except OpenAiError as exc:
            if "language" not in form or "language" not in str(exc):
                raise
            self._no_language_models.add(model)  # mémorisé : plus de tentative inutile
            form.pop("language")
            data = self._post("/audio/transcriptions", files=files, data=form)
        text = data.get("text")
        if not isinstance(text, str):
            raise OpenAiError("invalid_response")
        return text

    def structured(
        self, *, model: str, system: str, user: str, schema_name: str, schema: dict[str, Any]
    ) -> dict[str, Any]:
        data = self._post(
            "/chat/completions",
            json={
                "model": model,
                "temperature": 0,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {"name": schema_name, "strict": True, "schema": schema},
                },
            },
        )
        try:
            content = data["choices"][0]["message"]["content"]
            parsed = json.loads(content)
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise OpenAiError("invalid_response") from exc
        if not isinstance(parsed, dict):
            raise OpenAiError("invalid_response")
        return parsed


def build_openai_client(settings: Any) -> OpenAiClient:
    key = settings.openai_api_key.get_secret_value() if settings.openai_api_key else ""
    if not key:
        raise RuntimeError(
            "FANILO_AI_OPENAI_API_KEY manquante : ajoutez-la dans .env pour utiliser OpenAI."
        )
    return OpenAiClient(
        key, base_url=settings.openai_base_url, timeout_s=settings.openai_timeout_seconds
    )
