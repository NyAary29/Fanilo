"""Normalisation de texte partagée par le classifieur et son lexique.

Étapes (dans l'ordre) :
1. minuscules (`casefold`) ;
2. accents retirés (décomposition NFKD puis suppression des diacritiques) ;
3. apostrophes typographiques (’ ‘ ʼ ` ´) et apostrophe droite remplacées par une espace,
   ce qui sépare « l'enfant » en « l enfant » et « an'ny » en « an ny » ;
4. tirets et toute ponctuation remplacés par une espace (« mandehan-dra » -> « mandehan dra ») ;
5. espaces multiples réduites à une seule.

Le lexique est normalisé avec la même fonction, ce qui rend la correspondance insensible à
ces variations d'écriture.
"""

from __future__ import annotations

import re
import unicodedata

_APOSTROPHES = "'’‘ʼ`´′"
_APOSTROPHE_RE = re.compile(f"[{re.escape(_APOSTROPHES)}]")
_NON_WORD_RE = re.compile(r"[^0-9a-z]+")


def strip_accents(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch))


def normalize_text(text: str) -> str:
    lowered = text.casefold()
    no_accents = strip_accents(lowered)
    no_apostrophes = _APOSTROPHE_RE.sub(" ", no_accents)
    words_only = _NON_WORD_RE.sub(" ", no_apostrophes)
    return " ".join(words_only.split())


def tokenize(text: str) -> list[str]:
    return normalize_text(text).split()
