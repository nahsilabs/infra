# syntax=docker/dockerfile:1.27
# Build from the repository root:
# docker build --platform linux/amd64 -t docker.io/nahsilabs/hindsight:1.0.0-static-keys containers/hindsight
FROM scratch AS extension-source

# Upstream v1.0.0, pinned to its immutable release commit.
ADD https://github.com/vectorize-io/hindsight.git#39c65ffe2f140d0c84cee58566cad8900c5b9908 /src/

FROM ghcr.io/vectorize-io/hindsight-api:1.0.0-slim@sha256:1e889b5f44a3546a40765d084162cf0807c0b08c97fb29f64d0705597f1ef3b6

LABEL org.opencontainers.image.title="Hindsight with static-keys tenancy" \
      org.opencontainers.image.description="Hindsight API 1.0.0 with upstream static-keys tenant extension" \
      org.opencontainers.image.source="https://github.com/nahsi/infra" \
      org.opencontainers.image.version="1.0.0-static-keys" \
      org.opencontainers.image.base.name="ghcr.io/vectorize-io/hindsight-api:1.0.0-slim@sha256:1e889b5f44a3546a40765d084162cf0807c0b08c97fb29f64d0705597f1ef3b6"

# Upstream owns /app/api/.venv as hindsight, UID/GID 1000, and ships uv.
# Keep its PATH and /app/start-all.sh startup command unchanged.
USER 1000:1000

# Upstream's extension uses only the server's existing dependencies.
COPY --from=extension-source --chown=1000:1000 \
     /src/hindsight-extensions/static-keys-tenant/hindsight_ext_static_keys_tenant \
     /app/extensions/hindsight_ext_static_keys_tenant
ENV PYTHONPATH=/app/extensions

# Fail the build if the server's interpreter cannot import the tenant entrypoint.
RUN /app/api/.venv/bin/python -c "from hindsight_ext_static_keys_tenant import StaticKeysTenantExtension"
