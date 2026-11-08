"""Tests du schéma YAML et de la politique de chargement."""

from __future__ import annotations

import datetime as dt
from pathlib import Path

import pytest

from fanilo_rules import (
    RuleEngine,
    RulesetPolicyError,
    RulesetValidationError,
    Severity,
    Status,
    load_ruleset,
    load_sign_catalog,
)
from fanilo_rules.schema import Module

from .conftest import DEMO_CATALOG, DEMO_RULESET


def _validate(data: dict) -> dict:
    data["status"] = "validated"
    data["validated_by"] = "Responsable clinique (test)"
    data["validated_at"] = dt.date(2026, 1, 15)
    return data


# --- Fichiers de démonstration --------------------------------------------------------


def test_demo_files_load_with_allow_demo() -> None:
    ruleset = load_ruleset(DEMO_RULESET, allow_demo=True)
    catalog = load_sign_catalog(DEMO_CATALOG, allow_demo=True)
    assert ruleset.status is Status.DEMO
    assert ruleset.is_demo
    assert catalog.is_demo
    assert 3 <= len(ruleset.rules) <= 5


def test_demo_header_is_visible() -> None:
    for path in (DEMO_RULESET, DEMO_CATALOG):
        head = path.read_text(encoding="utf-8")[:400]
        assert "DÉMONSTRATION — NON VALIDÉ CLINIQUEMENT — NE PAS UTILISER EN SOINS" in head


def test_demo_has_no_numeric_delay() -> None:
    ruleset = load_ruleset(DEMO_RULESET, allow_demo=True)
    for rule in ruleset.rules:
        if rule.response_delay is not None:
            assert rule.response_delay.is_placeholder
            assert rule.response_delay.target_minutes is None


@pytest.mark.parametrize("loader", [load_ruleset, load_sign_catalog])
def test_demo_refused_in_production(loader) -> None:
    path = DEMO_RULESET if loader is load_ruleset else DEMO_CATALOG
    with pytest.raises(RulesetPolicyError, match="refusé en production"):
        loader(path, allow_demo=False)


def test_engine_from_files_refuses_demo_in_production() -> None:
    with pytest.raises(RulesetPolicyError):
        RuleEngine.from_files(DEMO_RULESET, DEMO_CATALOG, allow_demo=False)


# --- Politique de chargement ----------------------------------------------------------


def test_validated_documents_load_in_production(ruleset_data, catalog_data, write_yaml) -> None:
    _validate(ruleset_data)
    for rule in ruleset_data["rules"]:
        if "response_delay" in rule:
            rule["response_delay"] = {"is_placeholder": False, "target_minutes": 60}
    rs_path = write_yaml(ruleset_data, "rs.yaml")
    cat_path = write_yaml(_validate(catalog_data), "cat.yaml")
    engine = RuleEngine.from_files(rs_path, cat_path, allow_demo=False)
    assert not engine.is_demo
    assert engine.ruleset.validated_at == dt.date(2026, 1, 15)


@pytest.mark.parametrize("allow_demo", [True, False])
def test_retired_always_refused(ruleset_data, write_yaml, allow_demo) -> None:
    ruleset_data["status"] = "retired"
    with pytest.raises(RulesetPolicyError, match="retired"):
        load_ruleset(write_yaml(ruleset_data), allow_demo=allow_demo)


@pytest.mark.parametrize("status", ["draft", "in_review"])
def test_draft_and_review_only_outside_production(ruleset_data, write_yaml, status) -> None:
    ruleset_data["status"] = status
    path = write_yaml(ruleset_data)
    assert load_ruleset(path, allow_demo=True).status == status
    with pytest.raises(RulesetPolicyError):
        load_ruleset(path, allow_demo=False)


# --- YAML invalide --------------------------------------------------------------------


def test_missing_file(tmp_path: Path) -> None:
    with pytest.raises(RulesetValidationError, match="lecture impossible"):
        load_ruleset(tmp_path / "absent.yaml", allow_demo=True)


def test_malformed_yaml(write_yaml) -> None:
    with pytest.raises(RulesetValidationError, match="YAML invalide"):
        load_ruleset(write_yaml("ruleset_id: [non ferme\n"), allow_demo=True)


def test_duplicate_yaml_key_rejected(write_yaml) -> None:
    text = DEMO_RULESET.read_text(encoding="utf-8") + "status: validated\n"
    with pytest.raises(RulesetValidationError, match="clé dupliquée"):
        load_ruleset(write_yaml(text), allow_demo=True)


@pytest.mark.parametrize("text", ["", "- a\n- b\n", "texte libre\n"])
def test_non_mapping_document(write_yaml, text) -> None:
    with pytest.raises(RulesetValidationError, match="doit être un objet"):
        load_ruleset(write_yaml(text), allow_demo=True)


def test_unsafe_yaml_tag_rejected(write_yaml) -> None:
    with pytest.raises(RulesetValidationError, match="YAML invalide"):
        load_ruleset(write_yaml("a: !!python/object/apply:os.system ['true']\n"), allow_demo=True)


# --- Schéma : rejets ------------------------------------------------------------------


def _expect_schema_error(data, write_yaml, match: str, loader=load_ruleset) -> None:
    with pytest.raises(RulesetValidationError, match=match):
        loader(write_yaml(data), allow_demo=True)


def test_unknown_top_level_field(ruleset_data, write_yaml) -> None:
    ruleset_data["notes"] = "texte libre"
    _expect_schema_error(ruleset_data, write_yaml, "Extra inputs are not permitted")


def test_unknown_rule_field(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["dosage"] = "interdit"
    _expect_schema_error(ruleset_data, write_yaml, "Extra inputs are not permitted")


@pytest.mark.parametrize("action", ["prescribe_drug", "administer_medication", "", "REFER_CSB"])
def test_action_outside_enum(ruleset_data, write_yaml, action) -> None:
    ruleset_data["rules"][0]["action"] = action
    _expect_schema_error(ruleset_data, write_yaml, "action")


def test_unknown_status(ruleset_data, write_yaml) -> None:
    ruleset_data["status"] = "approved"
    _expect_schema_error(ruleset_data, write_yaml, "status")


def test_duplicate_rule_id(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][1]["id"] = ruleset_data["rules"][0]["id"]
    _expect_schema_error(ruleset_data, write_yaml, "identifiants de règles dupliqués")


@pytest.mark.parametrize("missing", ["validated_by", "validated_at"])
def test_validated_requires_metadata(ruleset_data, write_yaml, missing) -> None:
    _validate(ruleset_data)
    ruleset_data[missing] = None
    _expect_schema_error(ruleset_data, write_yaml, "validated_by' et 'validated_at")


def test_validated_rejects_placeholder_delay(ruleset_data, write_yaml) -> None:
    _validate(ruleset_data)
    _expect_schema_error(ruleset_data, write_yaml, "délai placeholder")


def test_placeholder_with_value_rejected(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["response_delay"] = {"is_placeholder": True, "target_minutes": 30}
    _expect_schema_error(ruleset_data, write_yaml, "placeholder ne doit pas")


def test_real_delay_requires_value(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["response_delay"] = {"is_placeholder": False}
    _expect_schema_error(ruleset_data, write_yaml, "exige 'target_minutes'")


@pytest.mark.parametrize("severity", ["critical", "urgent"])
def test_delay_required_for_non_routine(ruleset_data, write_yaml, severity) -> None:
    rule = ruleset_data["rules"][0]
    rule["severity"] = severity
    del rule["response_delay"]
    _expect_schema_error(ruleset_data, write_yaml, "exige un 'response_delay'")


@pytest.mark.parametrize("sign", ["saignement abondant", "sign_demo_01", "DEMO_01"])
def test_free_text_sign_rejected(ruleset_data, write_yaml, sign) -> None:
    ruleset_data["rules"][0]["conditions"]["signs"] = [sign]
    _expect_schema_error(ruleset_data, write_yaml, "signs")


def test_duplicate_sign_in_conditions(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["conditions"]["signs"] = ["SIGN_DEMO_01", "SIGN_DEMO_01"]
    _expect_schema_error(ruleset_data, write_yaml, "dupliqués dans les conditions")


def test_free_text_message_rejected(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["message_code"] = "Allez vite au CSB"
    _expect_schema_error(ruleset_data, write_yaml, "message_code")


@pytest.mark.parametrize("version", ["1.0", "v1.0.0", "01.0.0"])
def test_invalid_semver(ruleset_data, write_yaml, version) -> None:
    ruleset_data["version"] = version
    _expect_schema_error(ruleset_data, write_yaml, "version")


@pytest.mark.parametrize("value", [-0.1, 1.5])
def test_confidence_threshold_bounds(ruleset_data, write_yaml, value) -> None:
    ruleset_data["min_detection_confidence"] = value
    _expect_schema_error(ruleset_data, write_yaml, "min_detection_confidence")


def test_empty_rules_rejected(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"] = []
    _expect_schema_error(ruleset_data, write_yaml, "rules")


def test_non_boolean_context_rejected(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][2]["conditions"]["context"]["pregnant"] = "oui"
    _expect_schema_error(ruleset_data, write_yaml, "pregnant")


def test_catalog_duplicate_code(catalog_data, write_yaml) -> None:
    catalog_data["signs"].append(dict(catalog_data["signs"][0]))
    _expect_schema_error(catalog_data, write_yaml, "codes de signes dupliqués", load_sign_catalog)


def test_catalog_duplicate_module(catalog_data, write_yaml) -> None:
    catalog_data["signs"][0]["modules"] = ["reny", "reny"]
    _expect_schema_error(catalog_data, write_yaml, "modules dupliqués", load_sign_catalog)


def test_catalog_unknown_field(catalog_data, write_yaml) -> None:
    catalog_data["signs"][0]["threshold"] = 38.5
    _expect_schema_error(catalog_data, write_yaml, "Extra inputs", load_sign_catalog)


# --- Contrôles croisés jeu de règles / référentiel -------------------------------------


def test_engine_rejects_catalog_version_mismatch(ruleset_data, write_yaml) -> None:
    ruleset_data["sign_catalog"]["version"] = "9.9.9"
    with pytest.raises(RulesetValidationError, match="référence le référentiel"):
        RuleEngine.from_files(write_yaml(ruleset_data), DEMO_CATALOG, allow_demo=True)


def test_engine_rejects_rule_code_absent_from_catalog(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["conditions"]["signs"] = ["SIGN_DEMO_99"]
    with pytest.raises(RulesetValidationError, match="SIGN_DEMO_99"):
        RuleEngine.from_files(write_yaml(ruleset_data), DEMO_CATALOG, allow_demo=True)


def test_engine_rejects_code_from_other_module(ruleset_data, write_yaml) -> None:
    ruleset_data["rules"][0]["conditions"]["signs"] = ["SIGN_DEMO_06"]  # tanora uniquement
    with pytest.raises(RulesetValidationError, match="module reny"):
        RuleEngine.from_files(write_yaml(ruleset_data), DEMO_CATALOG, allow_demo=True)


# --- Utilitaires du schéma ------------------------------------------------------------


def test_severity_rank_order() -> None:
    assert Severity.ROUTINE.rank < Severity.URGENT.rank < Severity.CRITICAL.rank


def test_rules_for_module_sorted() -> None:
    ruleset = load_ruleset(DEMO_RULESET, allow_demo=True)
    ids = [r.id for r in ruleset.rules_for(Module.RENY)]
    assert ids == sorted(ids)
    assert ruleset.rules_for(Module.TANORA) == ()
