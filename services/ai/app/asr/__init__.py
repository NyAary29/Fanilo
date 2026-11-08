"""Reconnaissance vocale (ASR) derrière l'interface `AsrBackend`."""

from app.asr.base import AsrBackend, AsrUnavailableError, TranscriptionResult
from app.asr.none_backend import NoneBackend

__all__ = ["AsrBackend", "AsrUnavailableError", "NoneBackend", "TranscriptionResult"]
