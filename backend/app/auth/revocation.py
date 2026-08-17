"""JWT revocation blocklist.

Two backends behind the same interface:
- **memory** (default): thread-safe dict. Fine for single-process dev or a
  small Gunicorn worker set on one host. Entries are forgotten past their
  expiry.
- **redis**: durable across restarts and shared across every backend
  worker. Selected by setting `JWT_REVOCATION_URI=redis://host:6379/1`.

Uses SETEX so Redis auto-expires keys — no cleanup thread needed.
"""
from __future__ import annotations

from threading import Lock
from time import time
from typing import Protocol


class Revocation(Protocol):
    def revoke(self, jti: str, expires_at: float) -> None: ...
    def is_revoked(self, jti: str) -> bool: ...
    def clear(self) -> None: ...


# ── in-memory ─────────────────────────────────────────────────────────

class MemoryRevocation:
    def __init__(self) -> None:
        self._entries: dict[str, float] = {}
        self._lock = Lock()

    def revoke(self, jti: str, expires_at: float) -> None:
        with self._lock:
            self._entries[jti] = expires_at
            self._maybe_cleanup()

    def is_revoked(self, jti: str) -> bool:
        with self._lock:
            exp = self._entries.get(jti)
            if exp is None:
                return False
            if exp < time():
                del self._entries[jti]
                return False
            return True

    def _maybe_cleanup(self) -> None:
        if len(self._entries) < 256:
            return
        now = time()
        dead = [jti for jti, exp in self._entries.items() if exp < now]
        for jti in dead:
            del self._entries[jti]

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()


# ── redis ─────────────────────────────────────────────────────────────

class RedisRevocation:
    """SETEX-based revocation. Each JTI is a key whose value is unused;
    presence-in-Redis == revoked. Redis expires the key automatically
    once the token's own exp passes."""

    _PREFIX = "jwt:revoked:"

    def __init__(self, url: str):
        import redis
        self._client = redis.Redis.from_url(url, decode_responses=True)

    def revoke(self, jti: str, expires_at: float) -> None:
        ttl = max(1, int(expires_at - time()))
        self._client.setex(f"{self._PREFIX}{jti}", ttl, "1")

    def is_revoked(self, jti: str) -> bool:
        return self._client.exists(f"{self._PREFIX}{jti}") > 0

    def clear(self) -> None:
        # Test-only. Delete every JTI key under our prefix.
        keys = self._client.keys(f"{self._PREFIX}*")
        if keys:
            self._client.delete(*keys)


# ── factory + singleton ───────────────────────────────────────────────

_backend: Revocation | None = None


def get_revocation() -> Revocation:
    """Lazy — inspects env at first access so tests can swap it."""
    global _backend
    if _backend is None:
        import os
        url = os.getenv("JWT_REVOCATION_URI", "")
        _backend = RedisRevocation(url) if url.startswith("redis://") else MemoryRevocation()
    return _backend


def reset_revocation_for_tests() -> None:
    """Force the next `get_revocation()` call to re-read env — only used
    by tests that swap the backend mid-run."""
    global _backend
    _backend = None


# Backwards-compat alias: earlier code imported `revocation_list`. Keep
# it working with a lazy proxy so nothing breaks.
class _Proxy:
    def revoke(self, jti: str, expires_at: float) -> None:
        get_revocation().revoke(jti, expires_at)

    def is_revoked(self, jti: str) -> bool:
        return get_revocation().is_revoked(jti)

    def clear(self) -> None:
        get_revocation().clear()


revocation_list = _Proxy()
