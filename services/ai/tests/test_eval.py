import json
from pathlib import Path

import pytest

from eval.manifest import ManifestError, load_manifest, load_predictions
from eval.metrics import (
    ScoredUtterance,
    danger_sign_rates,
    error_rates,
    normalize_for_wer,
    stratified_report,
)
from eval.report import to_markdown
from eval.run_eval import build_report, main

SAMPLE = Path(__file__).resolve().parent.parent / "eval" / "samples" / "manifest.example.jsonl"


def _utt(utt_id, speaker, ref, hyp, dialect="plt", expected=(), predicted=()):
    return ScoredUtterance(
        utt_id=utt_id,
        speaker_id=speaker,
        strata={
            "dialect": dialect,
            "age_group": "adulte",
            "gender": "f",
            "channel": "tel",
            "speech_type": "lu",
            "speaker_id": speaker,
        },
        reference=ref,
        hypothesis=hyp,
        expected_signs=frozenset(expected),
        predicted_signs=frozenset(predicted),
    )


def test_normalize_for_wer() -> None:
    assert normalize_for_wer("J'ai la Fièvre, <noise> !") == "j ai la fièvre <noise>"
    assert normalize_for_wer("Fièvre", strip_accents=True) == "fievre"


def test_error_rates_corpus_level() -> None:
    # 1 substitution (b->x) + 1 insertion (g) sur 6 mots de référence -> WER = 2/6.
    rates = error_rates([("a b c d", "a x c d"), ("e f", "e f g")])
    assert rates["wer"] == pytest.approx(2 / 6, abs=1e-6)
    assert rates["n_reference_words"] == 6
    assert rates["word_substitutions"] == 1
    assert rates["word_insertions"] == 1
    assert rates["word_deletions"] == 0
    # Caractères (espaces comprises) : "abc" vs "abd" -> 1/3.
    assert error_rates([("abc", "abd")])["cer"] == pytest.approx(1 / 3, abs=1e-6)


def test_error_rates_empty_hypothesis_and_reference() -> None:
    rates = error_rates([("a b", ""), ("", "bruit")])
    assert rates["wer"] == pytest.approx(1.0)
    assert rates["n_utterances"] == 1
    assert rates["n_excluded_empty_reference"] == 1
    assert error_rates([("", "x")])["wer"] is None


def test_danger_sign_rates() -> None:
    rates = danger_sign_rates(
        [
            _utt("1", "s1", "x", "x", expected={"S1", "S2"}, predicted={"S1"}),
            _utt("2", "s1", "x", "x", expected={"S3"}, predicted=set()),
            _utt("3", "s2", "x", "x", expected=set(), predicted={"S4"}),
        ]
    )
    assert rates["expected_mentions"] == 3
    assert rates["false_negatives"] == 2
    assert rates["false_positives"] == 1
    assert rates["false_negative_rate"] == pytest.approx(2 / 3, abs=1e-6)
    assert rates["utterances_with_expected_sign"] == 2
    assert rates["utterances_all_signs_missed"] == 1
    assert danger_sign_rates([])["false_negative_rate"] is None


def test_stratified_report() -> None:
    utts = [
        _utt("1", "s1", "a b", "a b", dialect="plt"),
        _utt("2", "s2", "a b", "a x", dialect="skg"),
        _utt("3", "s3", "c d", "c", dialect="skg"),
    ]
    report = stratified_report(utts, min_speakers=2)
    assert report["overall"]["wer"] == pytest.approx(2 / 6, abs=1e-6)
    assert report["overall"]["n_speakers"] == 3
    plt = report["by_stratum"]["dialect"]["plt"]
    skg = report["by_stratum"]["dialect"]["skg"]
    assert plt["wer"] == 0.0
    assert plt["insufficient_speakers"] is True
    assert skg["wer"] == pytest.approx(2 / 4, abs=1e-6)
    assert skg["n_speakers"] == 2
    assert skg["insufficient_speakers"] is False
    assert set(report["by_stratum"]) == {"dialect", "age_group", "gender", "channel", "speech_type"}


def test_load_manifest_jsonl_sample() -> None:
    rows = load_manifest(SAMPLE)
    assert len(rows) == 8
    assert rows[0].strata["dialect"] == "plt"
    assert rows[3].expected_sign_codes == ("SIGN_DEMO_04",)
    assert rows[0].expected_sign_codes is None


def test_load_manifest_csv(tmp_path: Path) -> None:
    path = tmp_path / "m.csv"
    path.write_text(
        "audio_path,reference,speaker_id,dialect,age_group,gender,channel,speech_type,"
        "expected_sign_codes\n"
        "a.wav,misy ra,s1,,adulte,f,tel,lu,SIGN_DEMO_01;SIGN_DEMO_03\n",
        encoding="utf-8",
    )
    (row,) = load_manifest(path)
    assert row.strata["dialect"] == "inconnu"
    assert row.expected_sign_codes == ("SIGN_DEMO_01", "SIGN_DEMO_03")
    assert row.hypothesis is None


@pytest.mark.parametrize(
    "content",
    [
        '{"audio_path": "a.wav", "reference": "x"}\n',  # strates manquantes
        "[1, 2]\n",
    ],
)
def test_invalid_manifest(tmp_path: Path, content: str) -> None:
    path = tmp_path / "bad.jsonl"
    path.write_text(content, encoding="utf-8")
    with pytest.raises(ManifestError):
        load_manifest(path)


def test_unsupported_manifest_format(tmp_path: Path) -> None:
    path = tmp_path / "m.txt"
    path.write_text("x", encoding="utf-8")
    with pytest.raises(ManifestError):
        load_manifest(path)


def test_build_report_on_sample() -> None:
    report = build_report(SAMPLE, min_speakers=1)
    overall = report["overall"]
    assert overall["n_utterances_total"] == 8
    assert overall["n_excluded_empty_reference"] == 1
    assert overall["n_speakers"] == 4
    # Signes attendus : 01 (0001), 03 (0003), 04 (0004, annoté), 02 et 05 (0007).
    # Manqués par les hypothèses factices : 03 (« tazy ») et 05 (« mafy » omis).
    danger = overall["danger_signs"]
    assert danger["expected_mentions"] == 5
    assert danger["false_negatives"] == 2
    assert danger["false_negative_rate"] == pytest.approx(0.4)
    assert report["meta"]["expected_signs_source"] == "mixed"
    assert report["meta"]["sign_detector_is_demo"] is True
    assert report["by_stratum"]["channel"]["telephone_8k"]["danger_signs"]["false_negatives"] == 2


def test_cli_writes_json_and_markdown(tmp_path: Path) -> None:
    out_json, out_md = tmp_path / "r.json", tmp_path / "r.md"
    assert (
        main(["--manifest", str(SAMPLE), "--out-json", str(out_json), "--out-md", str(out_md)]) == 0
    )
    data = json.loads(out_json.read_text(encoding="utf-8"))
    assert data["overall"]["insufficient_speakers"] is True  # 4 locuteurs < 20
    md = out_md.read_text(encoding="utf-8")
    assert md.startswith("# Rapport d'évaluation")
    assert "## Par dialect" in md
    assert "revendication de performance" in md


def test_predictions_file(tmp_path: Path) -> None:
    manifest = tmp_path / "m.jsonl"
    manifest.write_text(
        json.dumps(
            {
                "utt_id": "u1",
                "audio_path": "a.wav",
                "reference": "misy ra",
                "speaker_id": "s",
                "dialect": "plt",
                "age_group": "a",
                "gender": "f",
                "channel": "c",
                "speech_type": "lu",
            }
        )
        + "\n",
        encoding="utf-8",
    )
    preds = tmp_path / "p.jsonl"
    preds.write_text(
        json.dumps({"utt_id": "u1", "hypothesis": "misy rano"}) + "\n", encoding="utf-8"
    )
    assert load_predictions(preds) == {"u1": "misy rano"}
    report = build_report(manifest, predictions_path=preds, asr_system="systeme-x")
    assert report["overall"]["wer"] == pytest.approx(0.5)
    assert report["overall"]["danger_signs"]["false_negatives"] == 1
    assert report["meta"]["expected_signs_source"] == "classifier_on_reference"
    assert report["meta"]["asr_system"] == "systeme-x"
    assert "global" in to_markdown(report)


def test_missing_hypotheses_is_an_error(tmp_path: Path) -> None:
    manifest = tmp_path / "m.jsonl"
    manifest.write_text(
        json.dumps(
            {
                "audio_path": "a.wav",
                "reference": "x",
                "speaker_id": "s",
                "dialect": "d",
                "age_group": "a",
                "gender": "f",
                "channel": "c",
                "speech_type": "lu",
            }
        )
        + "\n",
        encoding="utf-8",
    )
    with pytest.raises(SystemExit):
        build_report(manifest)
