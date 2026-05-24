#!/bin/sh

# AdGuard Home Entrypoint Script
# Handles user/group creation, timezone, and port configuration

set -e

# Default values
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
TZ="${TZ:-UTC}"
DNS_ADGUARD_CONTAINER_PORT="${DNS_ADGUARD_CONTAINER_PORT:-5354}"
DNS_ADGUARD_WEB_CONTAINER_PORT="${DNS_ADGUARD_WEB_CONTAINER_PORT:-3000}"

echo "========================================="
echo "Starting AdGuard Home with configuration:"
echo "  PUID: ${PUID}"
echo "  PGID: ${PGID}"
echo "  TZ: ${TZ}"
echo "  DNS Port: ${DNS_ADGUARD_CONTAINER_PORT}"
echo "  Web Port: ${DNS_ADGUARD_WEB_CONTAINER_PORT}"
echo "========================================="

# Set timezone
if [ -f /usr/share/zoneinfo/"${TZ}" ]; then
    echo "Setting timezone to ${TZ}"
    ln -sf /usr/share/zoneinfo/"${TZ}" /etc/localtime
else
    echo "Warning: Timezone ${TZ} not found, using UTC"
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi

# Create adguard user if it doesn't exist or if PUID/PGID are specified
if ! id -u adguard >/dev/null 2>&1 || [ "${PUID}" != "1000" ] || [ "${PGID}" != "1000" ]; then
    echo "Configuring adguard user with PUID=${PUID} and PGID=${PGID}"

    # Remove existing user if it exists
    if id -u adguard >/dev/null 2>&1; then
        deluser adguard 2>/dev/null || true
    fi

    # Create group if it doesn't exist
    if ! getent group adguard >/dev/null 2>&1; then
        addgroup -g "${PGID}" adguard
    fi

    # Create user
    adduser -D -H -u "${PUID}" -G adguard -s /bin/sh adguard
fi

# Ensure proper ownership of AdGuard Home directories
echo "Setting ownership of AdGuard Home directories"
chown -R adguard:adguard /opt/adguardhome

# Generate AdGuardHome configuration with correct ports
CONFIG_FILE="/opt/adguardhome/conf/AdGuardHome.yaml"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Generating default AdGuardHome configuration"
    /opt/adguardhome/AdGuardHome -c "${CONFIG_FILE}" -w /opt/adguardhome/work --check-config
fi

# Update ports in configuration if needed
if [ -f "${CONFIG_FILE}" ]; then
    echo "Updating port configuration in AdGuardHome.yaml"
    sed -i "s/port: 53/port: ${DNS_ADGUARD_CONTAINER_PORT}/g" "${CONFIG_FILE}"
    sed -i "s/bind_port: 80/bind_port: ${DNS_ADGUARD_WEB_CONTAINER_PORT}/g" "${CONFIG_FILE}" || true
fi

# Switch to adguard user and start AdGuard Home
echo "Starting AdGuard Home..."
exec su-exec adguard:adguard /opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work
