"""Chiffrement des colonnes nominatives (Fernet : AES-128-CBC + HMAC-SHA256).

Clé : ``FANILO_DATA_ENCRYPTION_KEY`` (obligatoire en production). Plusieurs clés
peuvent être fournies, séparées par des virgules, pour une rotation : la
première chiffre, toutes déchiffrent.

Générer une clé ::

    python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
"""

from functools import lru_cache

from cryptography.fernet import Fernet, InvalidToken, MultiFernet

from app.core.config import Settings


class DecryptionError(Exception):
    """Valeur chiffrée illisible (clé erronée ou donnée altérée)."""


def parse_keys(raw: str) -> list[str]:
    return [k.strip() for k in raw.split(",") if k.strip()]


class FieldCipher:
    def __init__(self, keys: list[str]) -> None:
        if not keys:
            raise ValueError("Aucune clé de chiffrement fournie.")
        self._fernet = MultiFernet([Fernet(k.encode("ascii")) for k in keys])

    def encrypt(self, value: str | None) -> str | None:
        if value is None:
            return None
        return self._fernet.encrypt(value.encode("utf-8")).decode("ascii")

    def decrypt(self, token: str | None) -> str | None:
        if token is None:
            return None
        try:
            return self._fernet.decrypt(token.encode("ascii")).decode("utf-8")
        except InvalidToken as exc:
            raise DecryptionError("Donnée chiffrée illisible.") from exc


@lru_cache(maxsize=8)
def _cipher_for(raw_keys: str) -> FieldCipher:
    return FieldCipher(parse_keys(raw_keys))


def get_cipher(settings: Settings) -> FieldCipher:
    """Chiffreur des colonnes nominatives pour ces settings."""
    if settings.data_encryption_key is None:  # pragma: no cover - garanti par Settings
        raise RuntimeError("FANILO_DATA_ENCRYPTION_KEY absente.")
    return _cipher_for(settings.data_encryption_key.get_secret_value())
