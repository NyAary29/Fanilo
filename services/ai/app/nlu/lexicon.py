"""Classifieur d'intention baseline, déterministe, fondé sur un lexique YAML.

Algorithme
----------
1. Le texte et chaque mot-clé sont normalisés par `normalize_text` (minuscules, accents et
   apostrophes retirés, ponctuation -> espace).
2. Un mot-clé (un ou plusieurs mots) correspond s'il apparaît comme **suite de mots entiers**
   dans le texte : « ra » correspond dans « misy ra » mais pas dans « rano ».
3. **Signes de danger d'abord** : si au moins un mot-clé de signe correspond, l'intention est
   `report_danger_sign`, quels que soient les autres mots-clés reconnus (priorité de
   sécurité), et `sign_codes` liste tous les codes reconnus. Les signes ne sont **pas**
   filtrés par module : un code hors module est signalé par le moteur de règles (fallback
   vers le conseiller) plutôt que d'être silencieusement ignoré ici.
4. Sinon, chaque intention autorisée pour le module reçoit un score = nombre de mots-clés
   distincts reconnus ; la meilleure l'emporte.
5. Sinon : `out_of_scope`.

Confiance (heuristique, NON calibrée)
-------------------------------------
- `n` = nombre de mots-clés distincts reconnus pour la classe retenue ;
- confiance = min(0,9 ; 0,6 + 0,1 × (n − 1)) ;
- égalité de score entre deux intentions (hors signes) : confiance = 0,4, l'intention
  déclarée en premier dans le lexique est retenue ;
- aucune correspondance : `out_of_scope`, confiance = 0,1 ; texte vide : 0,0.

Le plafond à 0,9 rappelle qu'un lexique non validé ne justifie jamais une certitude. Ces
valeurs ne sont pas des probabilités : c'est au moteur de règles d'appliquer son seuil
(`min_detection_confidence`) et de basculer vers le conseiller en dessous.

Limites connues : pas de gestion de la négation (« tsy misy ra » = « pas de sang » déclenche
quand même le signe, ce qui penche volontairement vers les faux positifs), pas de
lemmatisation (les variantes morphologiques du malgache doivent être listées explicitement).
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.nlu.base import OUT_OF_SCOPE, REPORT_DANGER_SIGN, ClassificationResult, IntentClassifier
from app.nlu.normalize import normalize_text

CONFIDENCE_BASE = 0.6
CONFIDENCE_STEP = 0.1
CONFIDENCE_CAP = 0.9
CONFIDENCE_TIE = 0.4
CONFIDENCE_NO_MATCH = 0.1
CONFIDENCE_EMPTY = 0.0

_RESERVED_INTENTS = {OUT_OF_SCOPE, REPORT_DANGER_SIGN}
_SIGN_CODE_RE = re.compile(r"^SIGN_[A-Z0-9_]+$")
_INTENT_RE = re.compile(r"^[a-z][a-z0-9_]*$")

Module = Literal["reny", "tanora"]
LexiconStatus = Literal["demo", "draft", "in_review", "validated", "retired"]


def keyword_confidence(hits: int) -> float:
    """Confiance heuristique pour `hits` mots-clés distincts reconnus (hits >= 1)."""
    return round(min(CONFIDENCE_CAP, CONFIDENCE_BASE + CONFIDENCE_STEP * (hits - 1)), 4)


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class Keywords(_Strict):
    """Mots-clés par langue. Le malgache (`mg`) doit être relu par des locuteurs natifs."""

    fr: list[str] = Field(default_factory=list)
    mg: list[str] = Field(default_factory=list)

    def normalized(self) -> tuple[str, ...]:
        seen: dict[str, None] = {}
        for raw in [*self.fr, *self.mg]:
            norm = normalize_text(raw)
            if not norm:
                raise ValueError(f"mot-clé vide après normalisation : {raw!r}")
            seen.setdefault(norm, None)
        return tuple(seen)

    @model_validator(mode="after")
    def _not_empty(self) -> Keywords:
        if not self.fr and not self.mg:
            raise ValueError("au moins un mot-clé est requis")
        self.normalized()
        return self


class IntentEntry(_Strict):
    name: str
    modules: list[Module] = Field(min_length=1)
    keywords: Keywords

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        if not _INTENT_RE.match(value):
            raise ValueError(f"nom d'intention invalide : {value!r}")
        if value in _RESERVED_INTENTS:
            raise ValueError(f"intention réservée, dérivée automatiquement : {value!r}")
        return value


class SignEntry(_Strict):
    code: str
    keywords: Keywords

    @field_validator("code")
    @classmethod
    def _check_code(cls, value: str) -> str:
        if not _SIGN_CODE_RE.match(value):
            raise ValueError(f"code de signe invalide : {value!r}")
        return value


class Lexicon(_Strict):
    lexicon_id: str
    version: str
    status: LexiconStatus
    validated_by: str | None = None
    validated_at: str | None = None
    sign_catalog: str
    intents: list[IntentEntry] = Field(min_length=1)
    signs: list[SignEntry] = Field(default_factory=list)

    @model_validator(mode="after")
    def _check_consistency(self) -> Lexicon:
        if self.status == "retired":
            raise ValueError("lexique retiré (status: retired) : chargement refusé")
        if self.status == "validated" and not (self.validated_by and self.validated_at):
            raise ValueError("un lexique validé doit porter validated_by et validated_at")
        names = [i.name for i in self.intents]
        if len(names) != len(set(names)):
            raise ValueError("intention dupliquée dans le lexique")
        codes = [s.code for s in self.signs]
        if len(codes) != len(set(codes)):
            raise ValueError("code de signe dupliqué dans le lexique")
        return self


def load_lexicon(path: Path) -> Lexicon:
    with path.open(encoding="utf-8") as fh:
        raw = yaml.safe_load(fh)
    return Lexicon.model_validate(raw)


def _matches(padded_text: str, keywords: tuple[str, ...]) -> list[str]:
    return [kw for kw in keywords if f" {kw} " in padded_text]


class LexiconIntentClassifier(IntentClassifier):
    def __init__(self, lexicon: Lexicon) -> None:
        self._lexicon = lexicon
        self._intents = [(i.name, set(i.modules), i.keywords.normalized()) for i in lexicon.intents]
        self._signs = [(s.code, s.keywords.normalized()) for s in lexicon.signs]

    @classmethod
    def from_path(cls, path: Path) -> LexiconIntentClassifier:
        return cls(load_lexicon(path))

    @property
    def lexicon(self) -> Lexicon:
        return self._lexicon

    @property
    def model_id(self) -> str:
        return f"lexicon-baseline:{self._lexicon.lexicon_id}@{self._lexicon.version}"

    @property
    def is_demo(self) -> bool:
        return self._lexicon.status != "validated"

    def _result(self, intent: str, confidence: float, **kwargs: list[str]) -> ClassificationResult:
        return ClassificationResult(
            intent=intent,
            confidence=confidence,
            model=self.model_id,
            is_demo=self.is_demo,
            **kwargs,
        )

    def classify(self, text: str, module: str) -> ClassificationResult:
        normalized = normalize_text(text)
        if not normalized:
            return self._result(OUT_OF_SCOPE, CONFIDENCE_EMPTY)
        padded = f" {normalized} "

        # 1. Signes de danger : prioritaires, non filtrés par module.
        sign_codes: list[str] = []
        sign_hits: dict[str, None] = {}
        for code, keywords in self._signs:
            hits = _matches(padded, keywords)
            if hits:
                sign_codes.append(code)
                for kw in hits:
                    sign_hits.setdefault(kw, None)
        if sign_codes:
            return self._result(
                REPORT_DANGER_SIGN,
                keyword_confidence(len(sign_hits)),
                sign_codes=sorted(set(sign_codes)),
                matched_keywords=list(sign_hits),
            )

        # 2. Intentions autorisées pour le module.
        scored: list[tuple[str, list[str]]] = []
        for name, modules, keywords in self._intents:
            if module not in modules:
                continue
            hits = _matches(padded, keywords)
            if hits:
                scored.append((name, hits))
        if not scored:
            return self._result(OUT_OF_SCOPE, CONFIDENCE_NO_MATCH)

        best_score = max(len(hits) for _, hits in scored)
        best = [(name, hits) for name, hits in scored if len(hits) == best_score]
        name, hits = best[0]  # ordre de déclaration du lexique en cas d'égalité
        confidence = CONFIDENCE_TIE if len(best) > 1 else keyword_confidence(best_score)
        return self._result(name, confidence, matched_keywords=hits)
