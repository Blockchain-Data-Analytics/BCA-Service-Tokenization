#!/bin/sh
# Build the CI image (tla+/Dockerfile) per architecture, then combine into one multi-arch tag.
# Run each arch step on a host of that arch (no emulation), then the manifest step anywhere.
#   ci-image.sh amd64      build + push $IMAGE:$TAG-amd64
#   ci-image.sh arm64      build + push $IMAGE:$TAG-arm64
#   ci-image.sh manifest   combine both into $IMAGE:$TAG
# Needs `docker login` for the registry. TAG must match the tag in .forgejo/workflows/tla.yml.
set -eu
IMAGE=${IMAGE:-code.blockchain-applied.com/bca/tla-ci}
TAG=${TAG:-1}
cd "$(dirname "$0")"
case "${1:-}" in
  amd64|arm64)
    docker build --platform "linux/$1" -t "$IMAGE:$TAG-$1" .
    docker push "$IMAGE:$TAG-$1"
    ;;
  manifest)
    docker buildx imagetools create -t "$IMAGE:$TAG" "$IMAGE:$TAG-amd64" "$IMAGE:$TAG-arm64"
    docker buildx imagetools inspect "$IMAGE:$TAG"
    ;;
  *) echo "usage: $0 amd64|arm64|manifest" >&2; exit 2 ;;
esac
