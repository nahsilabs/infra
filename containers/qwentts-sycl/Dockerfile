# syntax=docker/dockerfile:1.27
ARG DLE_IMAGE=intel/deep-learning-essentials:2026.1.3-devel-ubuntu26.04@sha256:efb6678acec8e743e41e3679f70dd0454fc8f2f2bfa7a4c10ec9c55bc77556e9
ARG QWENTTS_REPO=https://github.com/ServeurpersoCom/qwentts.cpp.git
ARG QWENTTS_REV=a69194fc87226874ea0c20256a4dbac2269380d3
ARG GGML_REV=c044c6f03892f9d5e98213b05f8afea1f8b0d3c9
ARG ONEDNN_PACKAGE_VERSION=2026.0.2-40
ARG JQ_PACKAGE_VERSION=1.8.1-4ubuntu2
ARG TINI_PACKAGE_VERSION=0.19.0-6
ARG DNNL_DIR=/opt/intel/oneapi/dnnl/2026.0/lib/cmake/dnnl
ARG GGML_NATIVE=OFF
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

FROM ${DLE_IMAGE} AS build
ARG QWENTTS_REPO
ARG QWENTTS_REV
ARG GGML_REV
ARG ONEDNN_PACKAGE_VERSION
ARG DNNL_DIR
ARG GGML_NATIVE

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends intel-oneapi-dnnl-devel-2026.0=${ONEDNN_PACKAGE_VERSION} \
 && rm -rf /var/lib/apt/lists/* \
 && command -v git \
 && command -v cmake \
 && command -v icx \
 && command -v icpx \
 && test -f "${DNNL_DIR}/dnnl-config.cmake"

WORKDIR /src
RUN git init qwentts.cpp \
 && git -C qwentts.cpp remote add origin "${QWENTTS_REPO}" \
 && git -C qwentts.cpp fetch --depth=1 origin "${QWENTTS_REV}" \
 && git -C qwentts.cpp checkout --detach FETCH_HEAD \
 && git -C qwentts.cpp submodule update --init --recursive \
 && test "$(git -C qwentts.cpp rev-parse HEAD)" = "${QWENTTS_REV}" \
 && test "$(git -C qwentts.cpp/ggml rev-parse HEAD)" = "${GGML_REV}"

WORKDIR /src/qwentts.cpp
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
 && /build/test-abi-c \
 && test -x /build/tts-server \
 && test -x /build/qwen-tts \
 && test -x /build/qwen-codec \
 && test -n "$(find /build -maxdepth 1 -type f -name '*.so*' -print -quit)"

FROM ${DLE_IMAGE} AS runtime
ARG DLE_IMAGE
ARG QWENTTS_REPO
ARG QWENTTS_REV
ARG GGML_REV
ARG ONEDNN_PACKAGE_VERSION
ARG JQ_PACKAGE_VERSION
ARG TINI_PACKAGE_VERSION
ARG DNNL_DIR
ARG GGML_NATIVE
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="qwentts.cpp Intel SYCL" \
      org.opencontainers.image.description="Pinned qwentts.cpp server built for Intel SYCL" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="${DLE_IMAGE}" \
      io.nahsilabs.qwentts.repository="${QWENTTS_REPO}" \
      io.nahsilabs.qwentts.revision="${QWENTTS_REV}" \
      io.nahsilabs.ggml.revision="${GGML_REV}" \
      io.nahsilabs.dle.image="${DLE_IMAGE}" \
      io.nahsilabs.onednn.package="${ONEDNN_PACKAGE_VERSION}" \
      io.nahsilabs.jq.package="${JQ_PACKAGE_VERSION}" \
      io.nahsilabs.tini.package="${TINI_PACKAGE_VERSION}" \
      io.nahsilabs.dnnl.cmake-dir="${DNNL_DIR}" \
      io.nahsilabs.compiler.c="icx" \
      io.nahsilabs.compiler.cxx="icpx" \
      io.nahsilabs.ggml.sycl="ON" \
      io.nahsilabs.ggml.sycl-target="INTEL" \
      io.nahsilabs.ggml.native="${GGML_NATIVE}"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      intel-oneapi-dnnl-2026.0=${ONEDNN_PACKAGE_VERSION} \
      jq=${JQ_PACKAGE_VERSION} \
      tini=${TINI_PACKAGE_VERSION} \
 && rm -rf /var/lib/apt/lists/* \
 && command -v curl

COPY --from=build --chown=65532:65532 /build/tts-server /build/qwen-tts /build/qwen-codec /app/
COPY --from=build --chown=65532:65532 /build/*.so* /app/
COPY --from=build --chown=65532:65532 --chmod=0555 /src/qwentts.cpp/docker/entrypoint.sh /app/entrypoint.sh

RUN mkdir -p /models /voices \
 && chown 65532:65532 /app /models /voices

ENV MAX_BATCH=2 \
    LD_LIBRARY_PATH=/app:/opt/intel/oneapi/dnnl/2026.0/lib:${LD_LIBRARY_PATH}

WORKDIR /app
USER 65532:65532
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/app/entrypoint.sh"]
