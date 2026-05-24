#!/usr/bin/env bash
#
# LocalNet base image quality gates.
# Runs lint + security scanners for docker-compose.base.yml, README, and all base Dockerfiles.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.base.yml}"
README_FILE="README.md"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
MARKDOWN_LINT_TARGETS="${MARKDOWN_LINT_TARGETS:-README.md}"

YAMLLINT_IMAGE="docker.io/cytopia/yamllint:1.35"
MARKDOWNLINT_IMAGE="ghcr.io/igorshubovych/markdownlint-cli:0.42.0"
HADOLINT_IMAGE="docker.io/hadolint/hadolint:2.12.0"
CHECKOV_IMAGE="docker.io/bridgecrew/checkov:3.2.334"
TRIVY_IMAGE="docker.io/aquasec/trivy:0.53.0"

CACHE_DIR="${ROOT_DIR}/.cache"
CHECKOV_CACHE_DIR="${CACHE_DIR}/checkov"
TRIVY_CACHE_DIR="${CACHE_DIR}/trivy"

mkdir -p "${CHECKOV_CACHE_DIR}" "${TRIVY_CACHE_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker CLI is required to run quality checks" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "error: docker compose plugin is required" >&2
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "error: ${COMPOSE_FILE} not found. Run from services/base root." >&2
  exit 1
fi

run_container() {
  docker run --rm \
    -v "${ROOT_DIR}:/workspace" \
    -w /workspace \
    --security-opt=no-new-privileges \
    "$@"
}

echo "➡️  Rendering docker compose config"
docker compose -f "${COMPOSE_FILE}" config >/dev/null

echo "➡️  Running yamllint on ${COMPOSE_FILE}"
run_container "${YAMLLINT_IMAGE}" "${COMPOSE_FILE}"

echo "➡️  Running markdownlint on ${MARKDOWN_LINT_TARGETS}"
run_container "${MARKDOWNLINT_IMAGE}" ${MARKDOWN_LINT_TARGETS}

BASE_DOCKERFILES=(
  "base-alpine/docker/Dockerfile.base-alpine"
  "base-debian/docker/Dockerfile.base-debian"
)

for dockerfile in "${BASE_DOCKERFILES[@]}"; do
  if [[ -f "${dockerfile}" ]]; then
    echo "➡️  Running hadolint on ${dockerfile}"
    run_container "${HADOLINT_IMAGE}" "${dockerfile}"
  else
    echo "ℹ️  Skipping hadolint (missing ${dockerfile})"
  fi
done

echo "➡️  Running Checkov IaC scan"
docker run --rm \
  -v "${ROOT_DIR}:/project" \
  -v "${CHECKOV_CACHE_DIR}:/home/checkov/.cache" \
  -w /project \
  --security-opt=no-new-privileges \
  "${CHECKOV_IMAGE}" -d /project

echo "➡️  Running Trivy config scan (severity: ${TRIVY_SEVERITY})"
docker run --rm \
  -v "${ROOT_DIR}:/workspace" \
  -v "${TRIVY_CACHE_DIR}:/root/.cache/trivy" \
  -w /workspace \
  --security-opt=no-new-privileges \
  "${TRIVY_IMAGE}" config --severity "${TRIVY_SEVERITY}" --quiet .

echo "✅  Quality checks completed successfully"
