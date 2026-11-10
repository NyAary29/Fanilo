"""Compare les modèles de transcription disponibles sur UN enregistrement.

    uv run --extra asr python -m eval.compare_live chemin/vers/audio.wav

Modèles essayés : OpenAI gpt-4o-transcribe (si FANILO_AI_OPENAI_API_KEY est définie),
Whisper malgache local, w2v-BERT malgache local (CTC). Rien n'est conservé.
"""

import sys
import time
from pathlib import Path

from app.asr.factory import build_asr_backend
from app.audio import AudioInput
from app.config import AsrBackendName, Settings


def main(path: str) -> int:
    data = Path(path).read_bytes()
    mime = "audio/wav" if path.endswith(".wav") else "audio/mp4"
    base = Settings()
    candidates = [AsrBackendName.WHISPER, AsrBackendName.CTC]
    if base.openai_api_key:
        candidates.insert(0, AsrBackendName.OPENAI)
    for name in candidates:
        settings = base.model_copy(
            update={
                "asr_backend": name,
                "asr_model": "",
                "openai_asr_fallback": AsrBackendName.NONE,
            }
        )
        print(f"\n▶ {name.value} : chargement…", flush=True)
        try:
            backend = build_asr_backend(settings)
            start = time.time()
            result = backend.transcribe(AudioInput(data=data, mime_type=mime, language="mg"), 60)
            print(f"  « {result.text or '(rien compris)'} »  [{time.time() - start:.1f} s]")
        except Exception as exc:  # noqa: BLE001 - on veut comparer, pas s'arrêter
            print(f"  échec : {type(exc).__name__}: {exc}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
