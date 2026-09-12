# syntax=docker/dockerfile:1.27
ARG PYTHON_IMAGE=python:3.12.11-slim-bookworm@sha256:519591d6871b7bc437060736b9f7456b8731f1499a57e22e6c285135ae657bf7
ARG REALTIMESTT_VERSION=1.1.2
ARG SHERPA_ONNX_VERSION=1.13.4
ARG TORCH_VERSION=2.8.0
ARG HTTPX_VERSION=0.28.1
ARG PYTHON_MULTIPART_VERSION=0.0.20

FROM ${PYTHON_IMAGE} AS builder
ARG REALTIMESTT_VERSION
ARG SHERPA_ONNX_VERSION
ARG TORCH_VERSION
ARG HTTPX_VERSION
ARG PYTHON_MULTIPART_VERSION

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential portaudio19-dev \
    && rm -rf /var/lib/apt/lists/* \
    && python -m venv "${VIRTUAL_ENV}" \
    && "${VIRTUAL_ENV}/bin/pip" install \
        --index-url https://download.pytorch.org/whl/cpu \
        "torch==${TORCH_VERSION}" \
        "torchaudio==${TORCH_VERSION}" \
    && "${VIRTUAL_ENV}/bin/pip" install \
        "realtimestt[server,sherpa-onnx]==${REALTIMESTT_VERSION}" \
        "sherpa-onnx==${SHERPA_ONNX_VERSION}" \
        "httpx==${HTTPX_VERSION}" \
        "python-multipart==${PYTHON_MULTIPART_VERSION}"

COPY openai_adapter.py /app/openai_adapter.py
RUN "${VIRTUAL_ENV}/bin/pip" check \
    && "${VIRTUAL_ENV}/bin/stt-server-production" --help >/dev/null \
    && "${VIRTUAL_ENV}/bin/stt-install-sherpa-models" --help >/dev/null \
    && PYTHONPATH=/app "${VIRTUAL_ENV}/bin/python" -c 'import openai_adapter; from example_fastapi_server.protocol import encode_audio_packet'

FROM ${PYTHON_IMAGE} AS runtime
ARG PYTHON_IMAGE
ARG REALTIMESTT_VERSION
ARG SHERPA_ONNX_VERSION
ARG TORCH_VERSION
ARG HTTPX_VERSION
ARG PYTHON_MULTIPART_VERSION
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

LABEL org.opencontainers.image.title="RealtimeSTT OpenAI transcription adapter" \
      org.opencontainers.image.description="CPU RealtimeSTT with a narrow OpenAI-compatible transcription adapter" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="${PYTHON_IMAGE}" \
      io.nahsilabs.realtimestt.version="${REALTIMESTT_VERSION}" \
      io.nahsilabs.realtimestt.sherpa-onnx-version="${SHERPA_ONNX_VERSION}" \
      io.nahsilabs.realtimestt.torch-version="${TORCH_VERSION}+cpu" \
      io.nahsilabs.realtimestt.httpx-version="${HTTPX_VERSION}" \
      io.nahsilabs.realtimestt.python-multipart-version="${PYTHON_MULTIPART_VERSION}"

ENV HOME=/home/realtimestt \
    PATH=/opt/venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    OMP_NUM_THREADS=6 \
    MKL_NUM_THREADS=6

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates ffmpeg libgomp1 libportaudio2 libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 65532 realtimestt \
    && useradd --uid 65532 --gid 65532 --home-dir /home/realtimestt --create-home --shell /usr/sbin/nologin realtimestt \
    && mkdir /app \
    && chown 65532:65532 /app

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder --chown=65532:65532 /app/openai_adapter.py /app/openai_adapter.py

USER 65532:65532
WORKDIR /home/realtimestt
EXPOSE 8000 8010
STOPSIGNAL SIGTERM
ENTRYPOINT ["stt-server-production"]
