"""Mise en forme du rapport d'évaluation en Markdown."""

from __future__ import annotations

from typing import Any


def _pct(value: Any) -> str:
    return "—" if value is None else f"{100 * float(value):.2f} %"


def _row(label: str, m: dict[str, Any]) -> str:
    d = m["danger_signs"]
    flag = " ⚠" if m.get("insufficient_speakers") else ""
    return (
        f"| {label}{flag} | {m['n_speakers']} | {m['n_utterances_total']} "
        f"({m['n_excluded_empty_reference']}) | {_pct(m['wer'])} | "
        f"{_pct(m['cer'])} | {d['expected_mentions']} | {d['false_negatives']} | "
        f"{_pct(d['false_negative_rate'])} | {d['false_positives']} |"
    )


_HEADER = (
    "| Strate | Locuteurs | Énoncés (exclus du WER) | WER | CER | Mentions de signes | "
    "Faux négatifs | Taux FN | Faux positifs |\n|---|---|---|---|---|---|---|---|---|"
)


def to_markdown(report: dict[str, Any]) -> str:
    meta = report["meta"]
    lines = [
        "# Rapport d'évaluation ASR et signes de danger",
        "",
        f"> {meta['warning']}",
        "",
        f"- Manifeste : `{meta['manifest']}` (sha256 `{meta['manifest_sha256'][:16]}…`)",
        f"- Source des hypothèses : {meta['hypothesis_source']}",
        f"- Système ASR : {meta['asr_system']}",
        f"- Détecteur de signes : {meta['sign_detector']} (démo : {meta['sign_detector_is_demo']})",
        f"- Source des signes attendus : {meta['expected_signs_source']}",
        f"- Normalisation : {meta['normalization']}",
        "- Énoncés exclus du WER/CER : référence vide après normalisation "
        "(ils restent comptés pour les signes de danger).",
        f"- Seuil de locuteurs par strate : {meta['min_speakers']} "
        "(⚠ = en dessous, chiffres non interprétables)",
        "",
        "## Global",
        "",
        _HEADER,
        _row("global", report["overall"]),
    ]
    for axis, values in report["by_stratum"].items():
        lines += ["", f"## Par {axis}", "", _HEADER]
        lines += [_row(value, metrics) for value, metrics in values.items()]
    lines.append("")
    return "\n".join(lines)
