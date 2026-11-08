import pytest

from app.nlu.normalize import normalize_text, strip_accents, tokenize


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Fièvre", "fievre"),
        ("RÈGLES Douloureuses", "regles douloureuses"),
        ("l'enfant", "l enfant"),
        ("l’enfant", "l enfant"),
        ("anʼny", "an ny"),
        ("mandehan-dra", "mandehan dra"),
        ("  Misy   ra !!! ", "misy ra"),
        ("Fanatôbiana", "fanatobiana"),
        ("", ""),
        ("?!...", ""),
    ],
)
def test_normalize_text(raw: str, expected: str) -> None:
    assert normalize_text(raw) == expected


def test_strip_accents_keeps_base_letters() -> None:
    assert strip_accents("éèêëàôìñ") == "eeeeaoin"


def test_tokenize() -> None:
    assert tokenize("J'ai de la FIÈVRE.") == ["j", "ai", "de", "la", "fievre"]
