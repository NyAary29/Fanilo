"""Garde-fous contre les transcriptions inventées (sans dépendance lourde)."""

from __future__ import annotations

from typing import Any

# --- Garde-fous contre les transcriptions inventées -----------------------------------

# Amplitude RMS sous laquelle l'audio est considéré comme silencieux (échantillons
# flottants dans [-1, 1]). Valeur technique prudente, à ajuster sur corpus réel.
SILENCE_RMS = 0.003


def is_near_silent(samples: Any) -> bool:
    total = 0.0
    count = 0
    for value in samples:
        total += float(value) * float(value)
        count += 1
    return count == 0 or (total / count) ** 0.5 < SILENCE_RMS


def looks_hallucinated(text: str, ngram: int = 3, max_repeats: int = 3) -> bool:
    """Vrai si une même suite de ``ngram`` mots revient plus de ``max_repeats`` fois :
    signature des boucles de génération de Whisper sur un audio peu clair."""
    words = text.lower().split()
    if len(words) < ngram * (max_repeats + 1):
        return False
    counts: dict[tuple[str, ...], int] = {}
    for i in range(len(words) - ngram + 1):
        key = tuple(words[i : i + ngram])
        counts[key] = counts.get(key, 0) + 1
        if counts[key] > max_repeats:
            return True
    return False


def foreign_script(text: str) -> bool:
    """Vrai si le texte contient des lettres hors alphabet latin : le malgache et le
    français s'écrivent en latin ; c'est la signature d'une transcription au hasard."""
    for char in text:
        if char.isalpha() and not ("a" <= char.lower() <= "z" or "À" <= char <= "ɏ"):
            return True
    return False
