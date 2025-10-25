#!/bin/bash
set -euo pipefail

ORIGINAL_ENTRYPOINT="/opt/sonatype/docker-entrypoint-original.sh"
CONFIGURE_SCRIPT="/opt/sonatype/scripts/configure-docker-proxy.sh"

if [ "${NEXUS_SKIP_DOCKER_SETUP:-false}" != "true" ] && [ -x "$CONFIGURE_SCRIPT" ]; then
  "$CONFIGURE_SCRIPT" &
fi

exec "$ORIGINAL_ENTRYPOINT" "$@"
