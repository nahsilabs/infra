#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  '') push=false ;;
  --push) push=true ;;
  --help|-h)
    printf '%s\n' \
      'Usage: nix develop --command ./containers/agent-substrate/build.sh [--push]' \
      'Builds the pinned upstream revision for linux/amd64 using upstream .ko.yaml.' \
      'Without --push, writes local OCI layouts only. --push publishes to Docker Hub nahsilabs.' \
      'Authenticate first with docker login docker.io. OUTPUT_DIR optionally selects the artifact directory.'
    exit 0 ;;
  *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || { printf 'Expected at most one argument\n' >&2; exit 1; }

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
revision=$(<"$root/version")
tag=$revision
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] && tag=${revision:0:7}
work=$(mktemp -d)
output=${OUTPUT_DIR:-$(mktemp -d -t ate-images.XXXXXXXX)}
mkdir -p "$output"
output=$(realpath "$output")
worker_base="ko.local/ate-worker-base:$tag"
cleanup() {
  docker image rm "$worker_base" >/dev/null 2>&1 || true
  rm -rf -- "$work"
}
trap cleanup EXIT

for tool in git go ko crane docker; do command -v "$tool" >/dev/null; done
git init --quiet "$work/source"
git -C "$work/source" remote add origin https://github.com/agent-substrate/substrate.git
git -C "$work/source" fetch --quiet --depth 1 origin "$revision"
git -C "$work/source" checkout --quiet --detach FETCH_HEAD
cd "$work/source"
git rev-parse HEAD > "$output/revision"

base=
while read -r key value rest; do
  if [[ "$key" == defaultBaseImage: ]]; then base=$value; break; fi
done < .ko.yaml
[[ -n "$base" ]] || { printf 'Upstream defaultBaseImage is missing\n' >&2; exit 1; }

# WorkerPool cannot set these runtime environment variables at this revision.
crane mutate --platform linux/amd64 "$base" \
  --env OTEL_TRACES_EXPORTER=none \
  --env OTEL_METRICS_EXPORTER=none \
  --env OTEL_LOGS_EXPORTER=none \
  --tag "$worker_base" --output "$work/worker-base.tar"
docker load --input "$work/worker-base.tar"

while read -r binary image; do
  (
    if [[ "$binary" == ateom-gvisor ]]; then export KO_DEFAULTBASEIMAGE="$worker_base"; fi
    KO_DOCKER_REPO="docker.io/nahsilabs/$image" GOFLAGS=-mod=vendor \
      ko build "./cmd/$binary" --bare --platform linux/amd64 \
      --tags "$tag" --push="$push" \
      --ldflags "-X github.com/agent-substrate/substrate/internal/version.Version=$tag" \
      --oci-layout-path "$output/$image" --image-refs "$output/$image.ref"
  )
done <<'IMAGES'
ateapi ate-api
atecontroller ate-controller
atelet ate-node
ateom-gvisor ate-worker-gvisor
podcertcontroller ate-certs
snapshot-plugin ate-snapshot
IMAGES

printf 'Image layouts and references: %s\n' "$output"
