"""Tests de l'évaluateur déterministe."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from fanilo_rules import (
    Action,
    EvaluationContext,
    EvaluationInput,
    FallbackReason,
    Module,
    RuleEngine,
    Severity,
)


def _eval(engine: RuleEngine, *signs: str, confidence=None, pregnant=None, module=Module.RENY):
    return engine.evaluate(
        EvaluationInput(
            module=module,
            detected_signs=frozenset(signs),
            detection_confidence=confidence,
            context=EvaluationContext(pregnant=pregnant),
        )
    )


def _steps(result) -> list[str]:
    return [t.step for t in result.trace]


def test_single_critical_rule(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01")
    assert not result.fallback
    assert result.max_severity is Severity.CRITICAL
    assert result.actions == (Action.REFER_REFERENCE_FACILITY,)
    assert result.message_codes == ("MSG_DEMO_CRITICAL",)
    assert [t.rule_id for t in result.triggered_rules] == ["DEMO-RENY-001"]
    assert result.triggered_rules[0].matched_signs == ("SIGN_DEMO_01",)
    assert result.triggered_rules[0].response_delay.is_placeholder
    assert result.is_demo
    assert result.ruleset_id == "fanilo-reny-danger-signs-demo"
    assert result.ruleset_version == "0.1.0"
    assert result.sign_catalog_version == "0.1.0"
    assert _steps(result)[0] == "ruleset"
    assert _steps(result)[-1] == "decision"


def test_any_logic_matches_all_listed_signs(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01", "SIGN_DEMO_02")
    assert result.triggered_rules[0].matched_signs == ("SIGN_DEMO_01", "SIGN_DEMO_02")


def test_all_logic_requires_every_sign(engine) -> None:
    partial = _eval(engine, "SIGN_DEMO_04")
    assert partial.triggered_rules == ()
    assert partial.fallback
    assert partial.fallback_reasons == (FallbackReason.NO_RULE_MATCHED,)
    full = _eval(engine, "SIGN_DEMO_03", "SIGN_DEMO_04", pregnant=False)
    assert [t.rule_id for t in full.triggered_rules] == ["DEMO-RENY-002"]
    assert full.max_severity is Severity.URGENT


def test_multiple_rules_max_severity_wins(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_05", "SIGN_DEMO_03", "SIGN_DEMO_04", "SIGN_DEMO_02")
    assert result.max_severity is Severity.CRITICAL
    assert [t.rule_id for t in result.triggered_rules] == [
        "DEMO-RENY-001",
        "DEMO-RENY-002",
        "DEMO-RENY-003",
        "DEMO-RENY-004",
    ]
    assert result.actions == (
        Action.REFER_REFERENCE_FACILITY,
        Action.REFER_CSB,
        Action.REFER_COMMUNITY_AGENT,
    )
    assert not result.fallback


def test_context_restricts_rule(engine) -> None:
    pregnant = _eval(engine, "SIGN_DEMO_03", pregnant=True)
    assert [t.rule_id for t in pregnant.triggered_rules] == ["DEMO-RENY-003"]
    not_pregnant = _eval(engine, "SIGN_DEMO_03", pregnant=False)
    assert not_pregnant.triggered_rules == ()
    assert not_pregnant.fallback_reasons == (FallbackReason.NO_RULE_MATCHED,)


def test_unknown_context_never_suppresses_rule(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_03", pregnant=None)
    assert [t.rule_id for t in result.triggered_rules] == ["DEMO-RENY-003"]


def test_empty_input_is_fallback(engine) -> None:
    result = _eval(engine)
    assert result.fallback
    assert result.fallback_reasons == (FallbackReason.EMPTY_INPUT,)
    assert result.actions == (Action.TRANSFER_COUNSELOR,)
    assert result.message_codes == ("MSG_DEMO_TRANSFER_COUNSELOR",)
    assert result.max_severity is None


def test_unknown_code_only_is_fallback(engine) -> None:
    result = _eval(engine, "SIGN_INCONNU")
    assert result.fallback
    assert result.fallback_reasons == (FallbackReason.UNKNOWN_SIGN_CODE,)
    assert result.unknown_signs == ("SIGN_INCONNU",)
    assert result.actions == (Action.TRANSFER_COUNSELOR,)
    assert result.triggered_rules == ()


def test_free_text_input_is_unknown(engine) -> None:
    result = _eval(engine, "saignement")
    assert result.unknown_signs == ("saignement",)
    assert result.fallback


def test_code_of_other_module_is_unknown(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_06")  # référencé pour tanora uniquement
    assert result.unknown_signs == ("SIGN_DEMO_06",)
    assert FallbackReason.UNKNOWN_SIGN_CODE in result.fallback_reasons


def test_unknown_code_does_not_mask_critical_rule(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01", "SIGN_INCONNU")
    assert result.max_severity is Severity.CRITICAL
    assert result.fallback
    assert result.fallback_reasons == (FallbackReason.UNKNOWN_SIGN_CODE,)
    assert result.actions == (Action.REFER_REFERENCE_FACILITY, Action.TRANSFER_COUNSELOR)
    assert result.message_codes == ("MSG_DEMO_CRITICAL", "MSG_DEMO_TRANSFER_COUNSELOR")


def test_low_confidence_is_fallback_with_candidates(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01", confidence=0.5)
    assert result.fallback
    assert result.fallback_reasons == (FallbackReason.LOW_CONFIDENCE,)
    assert result.triggered_rules == ()
    assert [t.rule_id for t in result.candidate_rules] == ["DEMO-RENY-001"]
    assert result.actions == (Action.TRANSFER_COUNSELOR,)
    assert result.max_severity is None


def test_confidence_at_threshold_is_accepted(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01", confidence=0.8)
    assert not result.fallback
    assert result.max_severity is Severity.CRITICAL
    assert result.candidate_rules == ()


def test_low_confidence_and_empty_input(engine) -> None:
    result = _eval(engine, confidence=0.1)
    assert result.fallback_reasons == (FallbackReason.EMPTY_INPUT, FallbackReason.LOW_CONFIDENCE)
    assert result.actions == (Action.TRANSFER_COUNSELOR,)


def test_module_without_rules_is_fallback(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_05", module=Module.TANORA)
    assert result.fallback_reasons == (FallbackReason.NO_RULE_MATCHED,)
    assert result.unknown_signs == ()
    assert result.actions == (Action.TRANSFER_COUNSELOR,)


def test_no_result_ever_says_nothing_to_report(engine) -> None:
    """Toute sortie contient au moins une orientation."""
    inputs = [(), ("SIGN_DEMO_04",), ("SIGN_X",), ("SIGN_DEMO_01",), ("SIGN_DEMO_05",)]
    for signs in inputs:
        for confidence in (None, 0.0, 0.99):
            result = _eval(engine, *signs, confidence=confidence)
            assert result.actions
            assert result.fallback or result.triggered_rules


def test_determinism(engine) -> None:
    signs = ("SIGN_DEMO_05", "SIGN_X", "SIGN_DEMO_03", "SIGN_DEMO_04", "SIGN_DEMO_02")
    first = _eval(engine, *signs, confidence=0.9, pregnant=True)
    for permutation in (signs, tuple(reversed(signs))):
        again = _eval(engine, *permutation, confidence=0.9, pregnant=True)
        assert again == first
        assert again.model_dump_json() == first.model_dump_json()


@pytest.mark.parametrize("confidence", [-0.01, 1.01])
def test_confidence_out_of_bounds_rejected(confidence) -> None:
    with pytest.raises(ValidationError):
        EvaluationInput(module=Module.RENY, detection_confidence=confidence)


def test_input_rejects_unknown_field() -> None:
    with pytest.raises(ValidationError):
        EvaluationInput(module=Module.RENY, free_text="j'ai mal")


def test_result_is_immutable(engine) -> None:
    result = _eval(engine, "SIGN_DEMO_01")
    with pytest.raises(ValidationError):
        result.fallback = True
