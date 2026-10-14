# syntax=docker/dockerfile:1.27
# Build from the repository root:
# docker build --platform linux/amd64 -t docker.io/nahsilabs/hindsight:1.0.0-hindclaw-0.5.0 containers/hindsight
FROM ghcr.io/vectorize-io/hindsight-api:1.0.0-slim@sha256:1e889b5f44a3546a40765d084162cf0807c0b08c97fb29f64d0705597f1ef3b6

LABEL org.opencontainers.image.title="Hindsight with HindClaw" \
      org.opencontainers.image.description="Hindsight API 1.0.0 with upstream HindClaw extension 0.5.0" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.version="1.0.0-hindclaw-0.5.0" \
      org.opencontainers.image.base.name="ghcr.io/vectorize-io/hindsight-api:1.0.0-slim@sha256:1e889b5f44a3546a40765d084162cf0807c0b08c97fb29f64d0705597f1ef3b6"

# Upstream owns /app/api/.venv as hindsight, UID/GID 1000, and ships uv.
# Keep its PATH and /app/start-all.sh startup command unchanged.
USER 1000:1000

# HindClaw's runtime dependencies are already required by Hindsight 1.0.0:
# aiohttp>=3.14.3, asyncpg>=0.30.0, pydantic>=2.0.0, pyjwt>=2.12.0.
# --no-deps adds only the extension and leaves the API and its dependencies intact.
RUN uv pip install --python /app/api/.venv/bin/python \
      --no-cache --no-deps hindclaw-extension==0.5.0
