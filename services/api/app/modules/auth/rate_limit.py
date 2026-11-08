"""Limitation simple des tentatives de connexion échouées.

LIMITE CONNUE : l'état est conservé en mémoire, dans le processus. Avec
plusieurs instances (ou plusieurs workers uvicorn), chaque processus a son
propre compteur et un redémarrage les remet à zéro. C'est INSUFFISANT en
production multi-instance : il faudra un stockage partagé (Redis, base) ou une
limitation au niveau du reverse proxy.
"""

import threading
import time
from collections import defaultdict, deque
from collections.abc import Callable


class LoginRateLimiter:
    """Bloque une clé après ``max_attempts`` échecs dans une fenêtre glissante."""

    def __init__(
        self,
        max_attempts: int,
        window_seconds: int,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def _prune(self, key: str, now: float) -> deque[float]:
        attempts = self._failures[key]
        while attempts and now - attempts[0] >= self.window_seconds:
            attempts.popleft()
        if not attempts:
            del self._failures[key]
            return deque()
        return attempts

    def retry_after(self, key: str) -> int:
        """Secondes avant nouvelle tentative possible (0 si la clé n'est pas bloquée)."""
        with self._lock:
            now = self._clock()
            attempts = self._prune(key, now)
            if len(attempts) < self.max_attempts:
                return 0
            return max(1, int(self.window_seconds - (now - attempts[0])) + 1)

    def record_failure(self, key: str) -> None:
        with self._lock:
            self._failures[key].append(self._clock())

    def reset(self, key: str) -> None:
        with self._lock:
            self._failures.pop(key, None)
