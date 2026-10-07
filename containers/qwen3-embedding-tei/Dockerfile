# syntax=docker/dockerfile:1.27
ARG PYTHON_IMAGE=python:3.12.11-slim-bookworm@sha256:519591d6871b7bc437060736b9f7456b8731f1499a57e22e6c285135ae657bf7
ARG TEI_IMAGE=ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.3@sha256:ad950d30878eceb72aaf32024d26fa2b1d04a75304fa0b4776b49aa1941fea07
ARG MODEL_REVISION=97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3

FROM ${PYTHON_IMAGE} AS model
ARG MODEL_REVISION
ENV HF_HUB_DISABLE_TELEMETRY=1

RUN python -m pip install --no-cache-dir "huggingface_hub==1.33.0"
RUN hf download Qwen/Qwen3-Embedding-0.6B \
      model.safetensors config.json tokenizer.json tokenizer_config.json \
      config_sentence_transformers.json modules.json 1_Pooling/config.json README.md \
      --revision "${MODEL_REVISION}" --local-dir /model \
 && rm -rf /model/.cache \
 && chmod -R a+rX /model
ADD --chmod=0444 https://www.apache.org/licenses/LICENSE-2.0.txt /model/LICENSE

FROM ${TEI_IMAGE}
ARG TEI_IMAGE
ARG MODEL_REVISION

LABEL org.opencontainers.image.title="Qwen3-Embedding-0.6B TEI CPU" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.version="1.9.3-${MODEL_REVISION}" \
      org.opencontainers.image.base.name="${TEI_IMAGE}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.nahsilabs.model.id="Qwen/Qwen3-Embedding-0.6B" \
      io.nahsilabs.model.revision="${MODEL_REVISION}"

COPY --from=model /model /model

ENV MODEL_ID=/model \
    SERVED_MODEL_NAME=Qwen/Qwen3-Embedding-0.6B \
    HF_HUB_OFFLINE=1 \
    HOME=/tmp \
    PORT=8080 \
    MAX_BATCH_TOKENS=4096

USER 65532:65532
EXPOSE 8080
