#!/usr/bin/env bash
set -euo pipefail

# Push airflow-base-common (Debian)
: "${REGISTRY:=http://localhost:8081/repository/docker-localnet}"
: "${NAMESPACE:=localnet}"
: "${IMAGE_PREFIX:=a3i}"
: "${TAG:=dev}"

IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_PREFIX}-airflow-base-common-debian:${TAG}"

echo "[push] image=${IMAGE}"
docker buildx build \
  --platform linux/amd64 \
  --tag "${IMAGE}" \
  --file "$(cd "$(dirname "$0")/.." && pwd)/Dockerfile" \
  "$(cd "$(dirname "$0")/.." && pwd)" \
  --push

echo "[push] done: ${IMAGE}"
