"""Hachage des mots de passe (argon2id via pwdlib)."""

from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

_hasher = PasswordHash((Argon2Hasher(),))

# Hachage factice, vérifié quand l'utilisateur n'existe pas, afin que le temps
# de réponse ne révèle pas l'existence d'un identifiant.
_DUMMY_HASH = _hasher.hash("fanilo-dummy-password-for-timing")


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    if password_hash is None:
        _hasher.verify(password, _DUMMY_HASH)
        return False
    try:
        return _hasher.verify(password, password_hash)
    except Exception:  # hachage illisible ou algorithme inconnu
        return False
