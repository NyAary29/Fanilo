"""Aides communes aux tests du lot contenus / interactions / alertes / références.

Toutes les données sont fictives.
"""

import uuid

from sqlalchemy.orm import Session, sessionmaker

from app.core.config import DEFAULT_CONTENTS_DEMO_PATH
from app.modules.contents.catalog import import_catalog, load_catalog
from app.modules.interactions.ai_client import (
    AiServiceError,
    Classification,
    Transcription,
)


def import_demo_contents(session_factory: sessionmaker[Session]) -> None:
    with session_factory() as session:
        import_catalog(session, load_catalog(DEFAULT_CONTENTS_DEMO_PATH))
        session.commit()


def create_beneficiary(client, world, who="ac_a", site=None, consents=("reny",)) -> uuid.UUID:
    body = {"preferred_channel": "none"}
    if site is not None:
        body["site_id"] = str(site.id)
    resp = client.post("/beneficiaries", json=body, headers=world.headers(who))
    assert resp.status_code == 201, resp.text
    bid = uuid.UUID(resp.json()["id"])
    for scope in consents:
        add_consent(client, world, bid, scope, who)
    return bid


def add_consent(client, world, bid, scope, who="ac_a") -> str:
    resp = client.post(
        f"/beneficiaries/{bid}/consents",
        json={"scope": scope, "method": "oral", "information_version": "demo-0.1"},
        headers=world.headers(who),
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


class FakeAi:
    """Service IA factice : réponses ou erreurs programmées, appels enregistrés."""

    def __init__(
        self,
        *,
        text="texte fictif transcrit",
        asr_confidence=None,
        sign_codes=("SIGN_DEMO_01",),
        confidence=0.9,
        transcribe_error=None,
        classify_error=None,
        is_demo=True,
        intent="report_danger_sign",
    ):
        self.text = text
        self.asr_confidence = asr_confidence
        self.sign_codes = list(sign_codes)
        self.confidence = confidence
        self.transcribe_error = transcribe_error
        self.classify_error = classify_error
        self.is_demo = is_demo
        self.intent = intent
        self.calls: list[tuple] = []

    def transcribe(self, audio: bytes, content_type: str, language: str) -> Transcription:
        self.calls.append(("transcribe", audio, content_type, language))
        if self.transcribe_error:
            raise AiServiceError(self.transcribe_error)
        return Transcription(text=self.text, confidence=self.asr_confidence, model="asr-fictif")

    def classify(self, text: str, module: str) -> Classification:
        self.calls.append(("classify", text, module))
        if self.classify_error:
            raise AiServiceError(self.classify_error)
        return Classification(
            intent=self.intent,
            sign_codes=self.sign_codes,
            confidence=self.confidence,
            model="lexique-fictif",
            is_demo=self.is_demo,
        )
