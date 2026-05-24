#!/usr/bin/env bash
set -euo pipefail

# Build airflow-core (Alpine)
: "${REGISTRY:=http://localhost:8081/repository/docker-localnet}"
: "${NAMESPACE:=localnet}"
: "${IMAGE_PREFIX:=a3i}"
: "${TAG:=dev}"

BASE_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_PREFIX}-base-python-alpine:${TAG}"
IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_PREFIX}-airflow-core-alpine:${TAG}"
CONTEXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[build] image=${IMAGE} (BASE_IMAGE=${BASE_IMAGE})"
docker buildx build \
  --platform linux/amd64 \
  --tag "${IMAGE}" \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --file "${CONTEXT_DIR}/Dockerfile" \
  "${CONTEXT_DIR}" \
  --load

echo "[build] done: ${IMAGE}"
