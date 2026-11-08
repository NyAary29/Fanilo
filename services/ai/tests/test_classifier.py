from pathlib import Path

import pytest
import yaml

from app.config import DEFAULT_LEXICON_PATH
from app.nlu.base import OUT_OF_SCOPE, REPORT_DANGER_SIGN
from app.nlu.lexicon import (
    CONFIDENCE_CAP,
    CONFIDENCE_EMPTY,
    CONFIDENCE_NO_MATCH,
    CONFIDENCE_TIE,
    Lexicon,
    LexiconIntentClassifier,
    keyword_confidence,
    load_lexicon,
)
from tests.conftest import RULES_SIGN_CATALOG


@pytest.fixture(scope="module")
def clf() -> LexiconIntentClassifier:
    return LexiconIntentClassifier.from_path(DEFAULT_LEXICON_PATH)


def test_demo_lexicon_is_flagged_as_demo(clf: LexiconIntentClassifier) -> None:
    assert clf.lexicon.status == "demo"
    assert clf.is_demo is True
    assert clf.model_id == "lexicon-baseline:fanilo-intents-demo@0.1.0"
    header = DEFAULT_LEXICON_PATH.read_text(encoding="utf-8")[:600]
    assert "DÉMONSTRATION — NON VALIDÉ" in header


def test_lexicon_sign_codes_exist_in_rules_demo_catalog(clf: LexiconIntentClassifier) -> None:
    assert RULES_SIGN_CATALOG.exists(), f"référentiel introuvable : {RULES_SIGN_CATALOG}"
    catalog = yaml.safe_load(RULES_SIGN_CATALOG.read_text(encoding="utf-8"))
    known = {s["code"] for s in catalog["signs"]}
    lexicon_codes = {s.code for s in clf.lexicon.signs}
    assert lexicon_codes, "le lexique de démo doit contenir des signes"
    assert lexicon_codes <= known, f"codes absents du référentiel : {lexicon_codes - known}"
    assert clf.lexicon.sign_catalog == catalog["catalog_id"]


@pytest.mark.parametrize(
    ("text", "module", "intent"),
    [
        ("Rahoviana ny fizahana vohoka ?", "reny", "ask_anc_schedule"),
        ("Quand est ma prochaine consultation prénatale ?", "reny", "ask_anc_schedule"),
        ("Inona no sakafo tsara ?", "reny", "ask_nutrition"),
        ("Que dois-je manger ?", "tanora", "ask_nutrition"),
        ("Mararin'ny fadimbolana aho", "tanora", "ask_menstruation"),
        ("J'ai mes règles", "tanora", "ask_menstruation"),
    ],
)
def test_intents(clf: LexiconIntentClassifier, text: str, module: str, intent: str) -> None:
    result = clf.classify(text, module)
    assert result.intent == intent
    assert result.sign_codes == []
    assert result.is_demo is True


def test_danger_sign_has_priority_over_other_intents(clf: LexiconIntentClassifier) -> None:
    result = clf.classify("Mandeha ra aho, rahoviana ny fizahana vohoka ?", "reny")
    assert result.intent == REPORT_DANGER_SIGN
    assert result.sign_codes == ["SIGN_DEMO_01"]


def test_multiple_signs_sorted_and_confidence_grows(clf: LexiconIntentClassifier) -> None:
    one = clf.classify("misy tazo", "reny")
    two = clf.classify("misy tazo ary torana", "reny")
    assert one.sign_codes == ["SIGN_DEMO_03"]
    assert two.sign_codes == ["SIGN_DEMO_02", "SIGN_DEMO_03"]
    assert one.confidence == keyword_confidence(1) == 0.6
    assert two.confidence == keyword_confidence(2) == 0.7


def test_signs_not_filtered_by_module(clf: LexiconIntentClassifier) -> None:
    # SIGN_DEMO_01 n'est rattaché qu'à reny : il est quand même proposé, le moteur de
    # règles signalera le code hors module (fallback) au lieu d'un faux négatif silencieux.
    result = clf.classify("misy ra", "tanora")
    assert result.intent == REPORT_DANGER_SIGN
    assert result.sign_codes == ["SIGN_DEMO_01"]


def test_intents_are_filtered_by_module(clf: LexiconIntentClassifier) -> None:
    result = clf.classify("consultation prénatale", "tanora")
    assert result.intent == OUT_OF_SCOPE


def test_whole_word_matching(clf: LexiconIntentClassifier) -> None:
    # « ra » (sang) ne doit pas correspondre dans « rano » (eau).
    assert clf.classify("misy rano", "reny").intent == OUT_OF_SCOPE


def test_accents_and_apostrophes_are_normalized(clf: LexiconIntentClassifier) -> None:
    assert clf.classify("FIÈVRE", "reny").sign_codes == ["SIGN_DEMO_03"]
    assert clf.classify("mandehan’dra", "reny").sign_codes == ["SIGN_DEMO_01"]


def test_negation_is_not_handled_and_biases_to_false_positive(
    clf: LexiconIntentClassifier,
) -> None:
    assert clf.classify("tsy misy ra", "reny").intent == REPORT_DANGER_SIGN


def test_out_of_scope_low_confidence(clf: LexiconIntentClassifier) -> None:
    result = clf.classify("Manao ahoana ianao", "reny")
    assert result.intent == OUT_OF_SCOPE
    assert result.confidence == CONFIDENCE_NO_MATCH
    assert result.sign_codes == []


def test_empty_text(clf: LexiconIntentClassifier) -> None:
    result = clf.classify("  ?! ", "reny")
    assert result.intent == OUT_OF_SCOPE
    assert result.confidence == CONFIDENCE_EMPTY


def test_confidence_formula_is_capped() -> None:
    assert keyword_confidence(1) == 0.6
    assert keyword_confidence(3) == 0.8
    assert keyword_confidence(4) == CONFIDENCE_CAP
    assert keyword_confidence(50) == CONFIDENCE_CAP


def _lexicon(**overrides: object) -> dict:
    base = {
        "lexicon_id": "t",
        "version": "1",
        "status": "demo",
        "sign_catalog": "fanilo-demo-signs",
        "intents": [
            {"name": "intent_a", "modules": ["reny"], "keywords": {"fr": ["pomme"]}},
            {"name": "intent_b", "modules": ["reny"], "keywords": {"mg": ["poire"]}},
        ],
        "signs": [],
    }
    base.update(overrides)
    return base


def test_tie_gives_low_confidence_and_declaration_order() -> None:
    clf = LexiconIntentClassifier(Lexicon.model_validate(_lexicon()))
    result = clf.classify("pomme poire", "reny")
    assert result.intent == "intent_a"
    assert result.confidence == CONFIDENCE_TIE


@pytest.mark.parametrize(
    "overrides",
    [
        {"status": "retired"},
        {"status": "validated"},  # sans validated_by / validated_at
        {"status": "unknown"},
        {"intents": [{"name": "out_of_scope", "modules": ["reny"], "keywords": {"fr": ["x"]}}]},
        {"intents": [{"name": "Bad-Name", "modules": ["reny"], "keywords": {"fr": ["x"]}}]},
        {"intents": [{"name": "a", "modules": ["reny"], "keywords": {}}]},
        {"intents": [{"name": "a", "modules": ["reny"], "keywords": {"fr": ["?!"]}}]},
        {"intents": [{"name": "a", "modules": ["other"], "keywords": {"fr": ["x"]}}]},
        {
            "intents": [
                {"name": "a", "modules": ["reny"], "keywords": {"fr": ["x"]}},
                {"name": "a", "modules": ["reny"], "keywords": {"fr": ["y"]}},
            ]
        },
        {"signs": [{"code": "BAD_01", "keywords": {"fr": ["x"]}}]},
        {
            "signs": [
                {"code": "SIGN_X", "keywords": {"fr": ["x"]}},
                {"code": "SIGN_X", "keywords": {"fr": ["y"]}},
            ]
        },
        {"unexpected_field": True},
    ],
)
def test_invalid_lexicons_are_rejected(overrides: dict) -> None:
    with pytest.raises(ValueError):
        Lexicon.model_validate(_lexicon(**overrides))


def test_validated_lexicon_is_not_demo(tmp_path: Path) -> None:
    path = tmp_path / "lex.yaml"
    path.write_text(
        yaml.safe_dump(_lexicon(status="validated", validated_by="x", validated_at="2026-01-01")),
        encoding="utf-8",
    )
    assert LexiconIntentClassifier(load_lexicon(path)).is_demo is False
