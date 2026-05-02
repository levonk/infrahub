#!/usr/bin/env bash
set -euo pipefail

# Build airflow-base-common (Alpine)
: "${REGISTRY:=http://localhost:8081/repository/docker-localnet}"
: "${NAMESPACE:=localnet}"
: "${IMAGE_PREFIX:=a3i}"
: "${TAG:=dev}"

IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_PREFIX}-airflow-base-common-alpine:${TAG}"
CONTEXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[build] image=${IMAGE}"
docker buildx build \
  --platform linux/amd64 \
  --tag "${IMAGE}" \
  --file "${CONTEXT_DIR}/Dockerfile" \
  "${CONTEXT_DIR}" \
  --load

echo "[build] done: ${IMAGE}"
