# NordVPN Service - VPN Gateway Container
# Uses gluetun for container-friendly NordVPN support
FROM qmcgaw/gluetun:latest

# Labels for metadata and security scanning
LABEL org.opencontainers.image.title="NordVPN Service" \
      org.opencontainers.image.description="NordVPN gateway container using gluetun" \
      org.opencontainers.image.version="2.0.0" \
      org.opencontainers.image.vendor="LocalNet" \
      maintainer="devops@localnet"

# Default NordVPN configuration
ENV VPN_SERVICE_PROVIDER=nordvpn \
    VPN_TYPE=wireguard \
    OPENVPN_VERSION=nordlynx \
    SERVER_COUNTRIES=United_States \
    FIREWALL=on \
    DOT=on

# Expose common ports
EXPOSE 1080 51820/udp