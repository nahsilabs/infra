# syntax=docker/dockerfile:1.27
ARG DLE_IMAGE=intel/deep-learning-essentials:2026.1.4-devel-ubuntu26.04@sha256:7eac4fcd7be2205713d2464267dff117b78e1707f93c42826b1da53e427ed9fa
ARG QWENTTS_REPO=https://github.com/ServeurpersoCom/qwentts.cpp.git
ARG QWENTTS_REV=6fae92914045cd83364d2845ceaa0f7969727319
ARG GGML_REV=40e16e4a814f7fe851a0c486fb9e8c722e957830
ARG ONEDNN_PACKAGE_VERSION=2026.0.2-40
ARG JQ_PACKAGE_VERSION=1.8.1-4ubuntu2
ARG TINI_PACKAGE_VERSION=0.19.0-6
ARG FASTTEXT_PACKAGE_VERSION=0.9.2+ds-9build1
ARG DNNL_DIR=/opt/intel/oneapi/dnnl/2026.0/lib/cmake/dnnl
ARG GGML_NATIVE=OFF

FROM ${DLE_IMAGE} AS build
ARG QWENTTS_REPO
ARG QWENTTS_REV
ARG GGML_REV
ARG ONEDNN_PACKAGE_VERSION
ARG FASTTEXT_PACKAGE_VERSION
ARG DNNL_DIR
ARG GGML_NATIVE

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      intel-oneapi-dnnl-devel-2026.0=${ONEDNN_PACKAGE_VERSION} \
      libfasttext-dev=${FASTTEXT_PACKAGE_VERSION} \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src/qwentts.cpp
RUN git init . \
 && git remote add origin "${QWENTTS_REPO}" \
 && git fetch --depth=1 origin "${QWENTTS_REV}" \
 && git checkout --detach FETCH_HEAD \
 && git submodule update --init --recursive \
 && test "$(git rev-parse HEAD)" = "${QWENTTS_REV}" \
 && test "$(git -C ggml rev-parse HEAD)" = "${GGML_REV}"

RUN --mount=type=bind,source=.,target=/patches \
    git apply /patches/*.patch

RUN cmake -S . -B /build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=icx \
      -DCMAKE_CXX_COMPILER=icpx \
      -DGGML_SYCL=ON \
      -DGGML_SYCL_TARGET=INTEL \
      -DGGML_NATIVE=${GGML_NATIVE} \
      -DDNNL_DIR=${DNNL_DIR} \
      -DQWEN_SHARED=ON \
 && cmake --build /build --parallel "$(nproc)" \
 && /build/test-abi-c

FROM ${DLE_IMAGE} AS runtime
ARG ONEDNN_PACKAGE_VERSION
ARG JQ_PACKAGE_VERSION
ARG TINI_PACKAGE_VERSION
ARG FASTTEXT_PACKAGE_VERSION

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      intel-oneapi-dnnl-2026.0=${ONEDNN_PACKAGE_VERSION} \
      jq=${JQ_PACKAGE_VERSION} \
      tini=${TINI_PACKAGE_VERSION} \
      libfasttext0=${FASTTEXT_PACKAGE_VERSION} \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/tts-server /build/qwen-tts /build/qwen-codec /build/*.so* /app/
COPY --from=build --chmod=0555 /src/qwentts.cpp/docker/entrypoint.sh /app/entrypoint.sh
ADD --checksum=sha256:8f3472cfe8738a7b6099e8e999c3cbfae0dcd15696aac7d7738a8039db603e83 --chmod=0444 \
    https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz /app/lid.176.ftz

RUN mkdir -p /models /voices \
 && chown 65532:65532 /models /voices

ENV MAX_BATCH=2 \
    LD_LIBRARY_PATH=/app:/opt/intel/oneapi/dnnl/2026.0/lib:${LD_LIBRARY_PATH}

ARG DLE_IMAGE
ARG QWENTTS_REPO
ARG QWENTTS_REV
ARG GGML_REV
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
LABEL org.opencontainers.image.title="qwentts.cpp Intel SYCL" \
      org.opencontainers.image.description="Qwen3-TTS with automatic text-language detection" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="${DLE_IMAGE}" \
      io.nahsilabs.qwentts.repository="${QWENTTS_REPO}" \
      io.nahsilabs.qwentts.revision="${QWENTTS_REV}" \
      io.nahsilabs.ggml.revision="${GGML_REV}" \
      io.nahsilabs.fasttext.model="https://fasttext.cc/docs/en/language-identification.html#content" \
      io.nahsilabs.fasttext.model.license="CC-BY-SA-3.0"

WORKDIR /app
USER 65532:65532
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/app/entrypoint.sh"]
