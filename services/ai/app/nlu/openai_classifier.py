"""Classifieur d'intention par GPT (OpenAI), contraint à une LISTE FERMÉE.

GPT ne rédige rien et ne répond pas à la question : il choisit une intention parmi celles
du lexique (plus `out_of_scope` / `report_danger_sign`) et des codes de signes parmi ceux
du lexique, via une sortie JSON à schéma strict. La décision reste au moteur de règles.

Confiance FIXE et volontairement prudente (`LLM_CONFIDENCE` = 0,7) : sous le seuil de
détection des signes du jeu de règles de démonstration (0,8), un signe proposé par GPT ne
déclenche JAMAIS d'alerte automatique ; il part chez un conseiller (et l'application
anonyme affiche la consigne d'urgence). « Aucune alerte critique ne doit dépendre
uniquement d'un modèle probabiliste » (cahier des charges, §7.2).

En cas d'échec d'OpenAI, le classifieur lexical de secours répond.
"""

from __future__ import annotations

import logging

from app.nlu.base import OUT_OF_SCOPE, REPORT_DANGER_SIGN, ClassificationResult, IntentClassifier
from app.nlu.lexicon import Lexicon, LexiconIntentClassifier
from app.openai_client import OpenAiClient, OpenAiError

logger = logging.getLogger("fanilo.ai.nlu.openai")

LLM_CONFIDENCE = 0.7

SYSTEM_PROMPT = (
    "Tu es un module de classification pour FANILO, un service d'information sur la santé "
    "maternelle et adolescente à Madagascar. Tu reçois une question en malgache ou en "
    "français (parfois mal transcrite depuis la voix). Tu NE réponds PAS à la question et tu "
    "ne donnes aucun conseil médical. Tu choisis uniquement :\n"
    "- `intent` : le thème parmi la liste fournie, `report_danger_sign` si la personne décrit "
    "un signe de la liste chez elle, sinon `out_of_scope` ;\n"
    "- `sign_codes` : les codes des signes de la liste que la personne décrit (liste vide "
    "sinon). En cas de doute sur un signe de danger, inclus-le : un humain vérifiera."
)


def _describe(words_fr: list[str], words_mg: list[str]) -> str:
    return "; ".join([*words_fr, *words_mg])


class OpenAiIntentClassifier(IntentClassifier):
    def __init__(self, client: OpenAiClient, model: str, lexicon: Lexicon) -> None:
        self._client = client
        self._model = model
        self._lexicon = lexicon
        self._fallback = LexiconIntentClassifier(lexicon)

    @property
    def model_id(self) -> str:
        return f"openai:{self._model}+lexique:{self._lexicon.lexicon_id}@{self._lexicon.version}"

    @property
    def is_demo(self) -> bool:
        return self._lexicon.status != "validated"

    def classify(self, text: str, module: str) -> ClassificationResult:
        if not text.strip():
            return self._fallback.classify(text, module)
        intents = [i for i in self._lexicon.intents if module in i.modules]
        names = [i.name for i in intents]
        codes = [s.code for s in self._lexicon.signs]
        catalog = "\n".join(
            [f"Thème `{i.name}` : {_describe(i.keywords.fr, i.keywords.mg)}" for i in intents]
            + [
                f"Signe `{s.code}` : {_describe(s.keywords.fr, s.keywords.mg)}"
                for s in self._lexicon.signs
            ]
        )
        schema = {
            "type": "object",
            "additionalProperties": False,
            "required": ["intent", "sign_codes"],
            "properties": {
                "intent": {"type": "string", "enum": [*names, REPORT_DANGER_SIGN, OUT_OF_SCOPE]},
                "sign_codes": {"type": "array", "items": {"type": "string", "enum": codes}}
                if codes
                else {"type": "array", "items": {"type": "string"}, "maxItems": 0},
            },
        }
        try:
            data = self._client.structured(
                model=self._model,
                system=SYSTEM_PROMPT,
                user=f"Module : {module}\nListe :\n{catalog}\n\nQuestion : {text}",
                schema_name="fanilo_classification",
                schema=schema,
            )
        except OpenAiError as exc:
            logger.warning("openai_nlu_failed reason=%s", exc)
            return self._fallback.classify(text, module)
        intent = data.get("intent")
        signs = sorted({c for c in data.get("sign_codes", []) if c in codes})
        if intent not in (*names, REPORT_DANGER_SIGN, OUT_OF_SCOPE):
            return self._fallback.classify(text, module)
        if signs:
            intent = REPORT_DANGER_SIGN
        elif intent == REPORT_DANGER_SIGN:
            intent = OUT_OF_SCOPE  # aucun code reconnu : rien à évaluer
        return ClassificationResult(
            intent=intent,
            sign_codes=signs,
            confidence=LLM_CONFIDENCE,
            model=self.model_id,
            is_demo=self.is_demo,
        )
