# syntax=docker/dockerfile:1
# Service IA interne de FANILO (non exposé publiquement).
#
#   Image légère (par défaut, sans ASR : /transcribe répond 503) :
#     docker build -t fanilo-ai services/ai
#   Image avec backends ASR Transformers (torch, transformers, ffmpeg) :
#     docker build --build-arg INSTALL_ASR=true -t fanilo-ai:asr services/ai
FROM python:3.12-slim AS base
COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /bin/uv
ARG INSTALL_ASR=false
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    HF_HOME=/opt/hf-cache
WORKDIR /app

# ffmpeg n'est nécessaire qu'aux backends ASR (décodage en mémoire par pipe).
RUN if [ "$INSTALL_ASR" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends ffmpeg \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Dépendances d'abord (cache Docker), sans les outils de dev.
COPY pyproject.toml uv.lock ./
RUN if [ "$INSTALL_ASR" = "true" ]; then \
      uv sync --frozen --no-dev --no-install-project --extra asr; \
    else \
      uv sync --frozen --no-dev --no-install-project; \
    fi

COPY app ./app
COPY lexicons ./lexicons

RUN useradd --system --uid 10001 fanilo \
    && mkdir -p /opt/hf-cache && chown -R fanilo /app /opt/hf-cache
USER fanilo
ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 8001
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
