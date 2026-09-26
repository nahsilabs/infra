# syntax=docker/dockerfile:1.27
ARG CUDA_DEVEL_IMAGE=nvidia/cuda:13.4.1-devel-ubuntu24.04@sha256:a3f014424ccc86cf66c84d700d2896491424205dd9457e3116ed4f0e96381311
ARG CUDA_RUNTIME_IMAGE=nvidia/cuda:13.4.1-runtime-ubuntu24.04@sha256:cdfca8f2adfd99287ebbd4a86b3ad6470425c731aea023ca1d4c653a0d7fec7b
ARG NINFER_REPO=https://github.com/sergiuszm/ninfer-4090.git
ARG NINFER_REV=1bd56c9a1bdf457c6188391a9385d44d86e953aa
ARG BUILD_JOBS=4
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

FROM ${CUDA_DEVEL_IMAGE} AS build
ARG NINFER_REPO
ARG NINFER_REV
ARG BUILD_JOBS

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      ca-certificates \
      cmake \
      git \
      libavcodec-dev \
      libavformat-dev \
      libavutil-dev \
      libcurl4-openssl-dev \
      libswscale-dev \
      ninja-build \
      pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init ninfer \
 && git -C ninfer remote add origin "${NINFER_REPO}" \
 && git -C ninfer fetch --depth=1 origin "${NINFER_REV}" \
 && git -C ninfer checkout --detach FETCH_HEAD \
 && test "$(git -C ninfer rev-parse HEAD)" = "${NINFER_REV}"

WORKDIR /src/ninfer
RUN test "${BUILD_JOBS}" -ge 1 \
 && cmake -S . -B /build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CUDA_ARCHITECTURES=89 \
      -DNINFER_BUILD_APPS=ON \
      -DBUILD_TESTING=OFF \
      -DNINFER_BUILD_BENCHMARKS=OFF \
 && cmake --build /build --parallel "${BUILD_JOBS}" --target ninfer ninfer-serve \
 && test -x /build/apps/ninfer \
 && test -x /build/apps/ninfer-serve

FROM ${CUDA_RUNTIME_IMAGE} AS runtime
ARG CUDA_RUNTIME_IMAGE
ARG NINFER_REPO
ARG NINFER_REV
ARG BUILD_JOBS
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="NInfer RTX 4090" \
      org.opencontainers.image.description="Pinned NInfer CLI and server built for NVIDIA Ada sm_89" \
      org.opencontainers.image.source="https://github.com/nahsilabs/infra" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${NINFER_REV}" \
      org.opencontainers.image.base.name="${CUDA_RUNTIME_IMAGE}" \
      io.nahsilabs.ninfer.repository="${NINFER_REPO}" \
      io.nahsilabs.ninfer.revision="${NINFER_REV}" \
      io.nahsilabs.ninfer.cuda-architecture="89" \
      io.nahsilabs.ninfer.build-jobs="${BUILD_JOBS}"

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      ca-certificates \
      libavcodec60 \
      libavformat60 \
      libavutil58 \
      libcurl4t64 \
      libswscale7 \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /usr/local/cuda-13.1/compat /usr/local/cuda-13/compat /usr/local/cuda/compat \
 && mkdir -p /app /home/ninfer /models \
 && chown 65532:65532 /home/ninfer \
 && chmod 0555 /app /models

COPY --from=build --chown=65532:65532 --chmod=0555 /build/apps/ninfer /build/apps/ninfer-serve /usr/local/bin/

ENV HOME=/home/ninfer
WORKDIR /app
USER 65532:65532
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["ninfer-serve"]
CMD ["--help"]
