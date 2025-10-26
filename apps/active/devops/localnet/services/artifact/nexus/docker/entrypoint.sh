#!/bin/bash
set -euo pipefail

CONFIGURE_SCRIPT="/opt/sonatype/scripts/configure-docker-proxy.sh"

# Ensure Java preferences directory exists with proper permissions
# This prevents "Couldn't create user preferences directory" warnings
mkdir -p /opt/sonatype/nexus/.java/.userPrefs
chown -R nexus:nexus /opt/sonatype/nexus/.java
chmod -R 0755 /opt/sonatype/nexus/.java

if [ "${NEXUS_SKIP_DOCKER_SETUP:-false}" != "true" ] && [ -x "$CONFIGURE_SCRIPT" ]; then
  "$CONFIGURE_SCRIPT" &
fi

# Start Nexus as the nexus user
cd /opt/sonatype/nexus
exec su-exec nexus ./bin/nexus run "$@"
