# syntax=docker/dockerfile:1.27
FROM nvidia/cuda:12.9.2-runtime-ubuntu24.04@sha256:6d2a0dabc50c3bf14d27fc66822b6b1f94a325807ace17bd1997762307790587

ARG PRISM_VERSION=prism-b10743-adfffbe
ARG PRISM_SHA256=43b73a24d5cd83c4482750ee52e59afac497c669c008a319e44e43a0033757e2

LABEL org.opencontainers.image.title="PrismML llama.cpp CUDA" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.version="${PRISM_VERSION}"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      ca-certificates curl libgomp1 libcurl4t64 libssl3t64 \
 && rm -rf /var/lib/apt/lists/* \
 && curl --fail --location --output /tmp/llama.tar.gz \
      "https://github.com/PrismML-Eng/llama.cpp/releases/download/${PRISM_VERSION}/llama-${PRISM_VERSION}-bin-linux-cuda-12.8-x64.tar.gz" \
 && echo "${PRISM_SHA256}  /tmp/llama.tar.gz" | sha256sum --check --strict \
 && mkdir -p /app /models \
 && tar -xzf /tmp/llama.tar.gz --strip-components=1 -C /app \
 && rm /tmp/llama.tar.gz \
 && test -x /app/llama-server \
 && chown 65532:65532 /models

ENV LD_LIBRARY_PATH=/app
ENV LLAMA_CACHE=/models
ENV HOME=/models
WORKDIR /app
USER 65532:65532
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/app/llama-server"]
CMD ["--help"]
