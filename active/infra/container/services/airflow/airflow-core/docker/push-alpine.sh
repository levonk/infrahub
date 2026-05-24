#!/usr/bin/env bash
set -euo pipefail

# Push airflow-core (Alpine)
: "${REGISTRY:=http://localhost:8081/repository/docker-localnet}"
: "${NAMESPACE:=localnet}"
: "${IMAGE_PREFIX:=a3i}"
: "${TAG:=dev}"

IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE_PREFIX}-airflow-core-alpine:${TAG}"

echo "[push] ${IMAGE}"
docker push "${IMAGE}"
echo "[push] done: ${IMAGE}"
