FROM scratch AS source
ADD https://github.com/unpod-ai/livekit-console.git#00e6db3af102914db2c65e339c11fcefa0807edb /src/

FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914 AS build
WORKDIR /app
COPY --from=source /src/package.json /src/package-lock.json ./
COPY --from=source /src/server/package.json server/
COPY --from=source /src/web/package.json web/
RUN npm ci
COPY --from=source /src/ ./
RUN npm run build

FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914
WORKDIR /app
ENV NODE_ENV=production
LABEL org.opencontainers.image.source="https://github.com/unpod-ai/livekit-console" \
      org.opencontainers.image.revision="00e6db3af102914db2c65e339c11fcefa0807edb" \
      org.opencontainers.image.version="0.1.0"
COPY --from=source /src/package.json /src/package-lock.json ./
COPY --from=source /src/server/package.json server/
COPY --from=source /src/web/package.json web/
RUN npm ci --omit=dev -w server
COPY --from=build /app/server/dist server/dist
COPY --from=build /app/web/dist web/dist
USER 10000:10000
EXPOSE 8080
CMD ["node", "server/dist/index.js"]
