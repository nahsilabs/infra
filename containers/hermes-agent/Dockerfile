# syntax=docker/dockerfile:1.27
FROM scratch AS hindsight
ADD https://github.com/vectorize-io/hindsight.git#f843f173bb41f001e322cc83c917371639e47fbf /src/

FROM scratch AS mnemosyne
ADD https://github.com/mnemosyne-oss/mnemosyne.git#d73848735a2a48471a62d2c8fb96cd7183c97491 /src/

FROM scratch AS langfuse
ADD https://github.com/NousResearch/hermes-official-plugins.git#c2a95963c442f3f23e4bc6fe0da898e1dd1fb63d /src/

FROM scratch AS snapcompact
ADD https://github.com/vimona3ds/hermes-snapcompact.git#83f6e2b0bedcaddf6e9c528825791ee688ecfdc9 /src/

FROM scratch AS humanizer
ADD https://github.com/ilyautov/humanizer-ru.git#ba8d50c1210b52f572c33b2b890805b68aeda33c /src/

FROM nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf

ARG TARGETARCH
RUN test "$TARGETARCH" = amd64

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*

COPY --from=hindsight /src/hindsight-integrations/hermes/ /opt/hermes/plugins/memory/hindsight/
COPY --from=mnemosyne /src/integrations/hermes/src/mnemosyne_hermes/ /opt/hermes/plugins/memory/mnemosyne/
COPY --from=langfuse /src/langfuse/ /opt/hermes/plugins/langfuse/
COPY --from=snapcompact /src/ /opt/hermes/plugins/context_engine/hermes-snapcompact/
COPY --from=humanizer /src/skills/humanizer-ru/ /opt/managed-skills/humanizer-ru/
COPY skills/ /opt/managed-skills/
COPY install-dependencies.py snapcompact.patch requirements.txt /opt/hermes/

RUN --mount=type=cache,target=/tmp/hermes-build-cache \
    git apply snapcompact.patch && \
    /opt/hermes/.venv/bin/python install-dependencies.py && \
    rm install-dependencies.py snapcompact.patch requirements.txt

RUN npm install --prefix /opt/hermes/bun --save-exact --ignore-scripts --no-audit --no-fund \
        @oven/bun-linux-x64-baseline@1.3.14 && \
    ln -s /opt/hermes/bun/node_modules/@oven/bun-linux-x64-baseline/bin/bun /usr/local/bin/bun

WORKDIR /opt/hermes/plugins/context_engine/hermes-snapcompact/bridge
RUN bun add --exact @oh-my-pi/snapcompact@18.0.0 && \
    npm cache clean --force && \
    rm -rf /root/.bun/install/cache

WORKDIR /opt/hermes
