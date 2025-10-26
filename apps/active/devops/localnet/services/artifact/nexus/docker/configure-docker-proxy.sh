#!/bin/bash
# Copyright (c) 2025 the person whose account is https://github.com/levonk.
# Licensed under the GNU AGPL-3.0 License. See LICENSE file in the project root for full license information.

set -euo pipefail

API_BASE="http://localhost:8081/service/rest/v1"
STATUS_ENDPOINT="${API_BASE}/status"
REPO_ENDPOINT="${API_BASE}/repositories"
REALM_ENDPOINT="${API_BASE}/security/realms/active"
MARKER_FILE="/nexus-data/.docker-proxy-configured"
SLEEP_SECONDS=10
MAX_ATTEMPTS=60

log() {
  echo "[nexus-docker-proxy] $(date -Iseconds) $*"
}

resolve_admin_password() {
  if [[ -n "${NEXUS_ADMIN_PASSWORD:-}" ]]; then
    echo -n "${NEXUS_ADMIN_PASSWORD}"
    return 0
  fi

  if [[ -n "${NEXUS_ADMIN_PASSWORD_FILE:-}" && -f "${NEXUS_ADMIN_PASSWORD_FILE}" ]]; then
    cat "${NEXUS_ADMIN_PASSWORD_FILE}"
    return 0
  fi

  local default_password_file="/nexus-data/admin.password"
  if [[ -f "${default_password_file}" ]]; then
    cat "${default_password_file}"
    return 0
  fi

  return 1
}

wait_for_nexus() {
  local attempt=1
  while (( attempt <= MAX_ATTEMPTS )); do
    if curl -sf "${STATUS_ENDPOINT}" >/dev/null; then
      log "Nexus status endpoint reachable"
      return 0
    fi
    log "Waiting for Nexus to start (attempt ${attempt}/${MAX_ATTEMPTS})"
    sleep "${SLEEP_SECONDS}"
    attempt=$((attempt + 1))
  done
  log "ERROR: Nexus did not become ready before timeout"
  return 1
}

repository_exists() {
  local repo_name="$1"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" "${REPO_ENDPOINT}" \
    | jq -er --arg name "${repo_name}" '.[] | select(.name == $name)' >/dev/null 2>&1
}

create_docker_proxy_repository() {
  local repo_name="docker-hub"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating Docker proxy repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/docker/proxy" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_DOCKER_BLOB_STORE}",
    "strictContentTypeValidation": true
  },
  "docker": {
    "v1Enabled": ${NEXUS_DOCKER_V1_ENABLED},
    "forceBasicAuth": ${NEXUS_DOCKER_FORCE_BASIC_AUTH},
    "httpPort": ${NEXUS_DOCKER_PROXY_PORT}
  },
  "cleanup": null,
  "component": {
    "proprietaryComponents": true
  },
  "proxy": {
    "remoteUrl": "${NEXUS_DOCKER_PROXY_REMOTE_URL}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 0,
      "useTrustStore": false,
      "timeout": 60,
      "enableCircularRedirects": false,
      "enableCookies": false
    }
  },
  "dockerProxy": {
    "indexType": "HUB",
    "indexUrl": null,
    "cacheForeignLayers": true
  }
}
JSON
}

create_docker_hosted_repository() {
  local repo_name="docker-private"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating Docker hosted repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/docker/hosted" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_DOCKER_BLOB_STORE}",
    "strictContentTypeValidation": true,
    "writePolicy": "ALLOW_ONCE"
  },
  "docker": {
    "v1Enabled": ${NEXUS_DOCKER_V1_ENABLED},
    "forceBasicAuth": ${NEXUS_DOCKER_FORCE_BASIC_AUTH},
    "httpPort": ${NEXUS_DOCKER_HOSTED_PORT}
  },
  "cleanup": null,
  "component": {
    "proprietaryComponents": true
  }
}
JSON
}

create_docker_group_repository() {
  local repo_name="docker-public"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating Docker group repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/docker/group" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_DOCKER_BLOB_STORE}",
    "strictContentTypeValidation": true
  },
  "docker": {
    "v1Enabled": ${NEXUS_DOCKER_V1_ENABLED},
    "forceBasicAuth": ${NEXUS_DOCKER_FORCE_BASIC_AUTH},
    "httpPort": ${NEXUS_DOCKER_GROUP_PORT}
  },
  "group": {
    "memberNames": [
      "docker-private",
      "docker-hub"
    ]
  }
}
JSON
}

configure_docker_realm() {
  log "Ensuring Docker bearer token realm is active"
  local active_realms
  active_realms=$(curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" "${REALM_ENDPOINT}")
  if echo "${active_realms}" | jq -e '.[] | select(. == "DockerToken")' >/dev/null 2>&1; then
    log "Docker bearer token realm already active"
    return 0
  fi

  local updated_realms
  updated_realms=$(echo "${active_realms}" | jq '. + ["DockerToken"]' | jq 'unique')
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X PUT "${REALM_ENDPOINT}" \
    -d "${updated_realms}"
  log "Docker bearer token realm activated"
}

create_pip_proxy_repository() {
  local repo_name="pypi"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating PyPI proxy repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/pypi/proxy" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_PIP_BLOB_STORE:-default}",
    "strictContentTypeValidation": true
  },
  "proxy": {
    "remoteUrl": "${NEXUS_PIP_PROXY_REMOTE_URL:-https://pypi.org}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 0,
      "useTrustStore": false,
      "timeout": 60,
      "enableCircularRedirects": false,
      "enableCookies": false
    }
  }
}
JSON
}

create_pip_hosted_repository() {
  local repo_name="pip-private"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating pip hosted repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/pypi/hosted" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_PIP_BLOB_STORE:-default}",
    "strictContentTypeValidation": true,
    "writePolicy": "ALLOW_ONCE"
  }
}
JSON
}

create_pip_group_repository() {
  local repo_name="pip-public"
  if repository_exists "${repo_name}"; then
    log "Repository '${repo_name}' already exists; skipping"
    return 0
  fi

  log "Creating pip group repository '${repo_name}'"
  curl -sf -u "${NEXUS_ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${REPO_ENDPOINT}/pypi/group" \
    -d @- <<JSON
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "${NEXUS_PIP_BLOB_STORE:-default}",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": [
      "pip-private",
      "pypi"
    ]
  }
}
JSON
}

main() {
  if [[ -f "${MARKER_FILE}" ]]; then
    log "Docker proxy already configured (marker present)"
    return 0
  fi

  if [[ "${NEXUS_SKIP_DOCKER_SETUP:-false}" == "true" ]]; then
    log "NEXUS_SKIP_DOCKER_SETUP=true; skipping Docker proxy configuration"
    return 0
  fi

  if ! ADMIN_PASSWORD=$(resolve_admin_password); then
    log "ERROR: Unable to determine Nexus admin password"
    return 1
  fi

  if [[ -z "${NEXUS_ADMIN_USERNAME:-}" ]]; then
    log "ERROR: NEXUS_ADMIN_USERNAME is not set"
    return 1
  fi

  if ! wait_for_nexus; then
    return 1
  fi

  create_docker_proxy_repository
  create_docker_hosted_repository
  create_docker_group_repository
  configure_docker_realm

  create_pip_proxy_repository
  create_pip_hosted_repository
  create_pip_group_repository

  echo "configured $(date -Iseconds)" > "${MARKER_FILE}"
  log "Repository configuration complete"
}

main "$@"
