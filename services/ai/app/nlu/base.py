"""Interface des classifieurs d'intention.

Un classifieur **propose** une intention et des codes de signes (`SIGN_...`) avec une
confiance. Il ne décide jamais d'une conduite : la décision revient au moteur de règles
(`services/rules`). Une implémentation Transformers pourra remplacer la baseline lexicale
en respectant cette interface.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field

OUT_OF_SCOPE = "out_of_scope"
REPORT_DANGER_SIGN = "report_danger_sign"


@dataclass(frozen=True)
class ClassificationResult:
    intent: str
    sign_codes: list[str] = field(default_factory=list)
    confidence: float = 0.0
    model: str = ""
    is_demo: bool = True
    # Mots-clés reconnus (normalisés), utiles au débogage et à l'évaluation. Non exposés
    # par l'API HTTP pour ne pas recopier le texte de l'usager.
    matched_keywords: list[str] = field(default_factory=list)


class IntentClassifier(ABC):
    @property
    @abstractmethod
    def model_id(self) -> str:
        """Identifiant versionné du modèle, renvoyé dans chaque réponse."""

    @property
    @abstractmethod
    def is_demo(self) -> bool:
        """Vrai si le modèle ou ses ressources ne sont pas validés."""

    @abstractmethod
    def classify(self, text: str, module: str) -> ClassificationResult:
        """Classe un texte pour un module (`reny`, `tanora`)."""
