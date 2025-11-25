# Base image from localnet/services/base/base-alpine
FROM localnet/base-alpine:latest

# Note: On Windows/WSL2, this container must be run in a Linux VM on the network.
# Windows will not share its NIC devices/wifi with Docker in WSL2 in a way that allows promiscuous mode monitoring.

# Install arpwatch
# arpwatch needs to run as root to access network device in promiscuous mode
RUN apk add --no-cache arpwatch

# Create directory for data and ensure correct permissions
RUN mkdir -p /var/lib/arpwatch && \
    touch /var/lib/arpwatch/arp.dat && \
    chmod 644 /var/lib/arpwatch/arp.dat

# Volume for persisting the ARP database
VOLUME /var/lib/arpwatch

# Environment variable for interface, default to wlan0
ENV INTERFACE=wlan0

# Entrypoint to handle interface selection
COPY ../assets/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Arpwatch requires root privileges for network monitoring
USER root

ENTRYPOINT ["/entrypoint.sh"]
