# Home Lab In-a-Box - Custom Chronyd Container
# Purpose: NTP time synchronization with full configuration control
#
# Why custom image:
# - cturra/ntp overwrites chrony.conf at startup, ignoring custom configs
# - Need full control over chronyd configuration for NTS, leap smearing, and access control
# - Need to ensure chronyd listens on UDP port 123 for NTP queries

FROM alpine:3.19

# Install chronyd and required tools
RUN apk add --no-cache \
    chrony \
    tzdata \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create chrony directories (user already created by chrony package)
# /var/run is a symlink to /run on Alpine, but create both to be safe
# Note: /run/chrony must be owned by root so chronyd (running as root initially) can write PID file
# before dropping privileges. After privilege drop, chronyd runs as chrony user.
RUN mkdir -p /var/lib/chrony /var/log/chrony /run/chrony /var/run/chrony && \
    chown -R chrony:chrony /var/lib/chrony /var/log/chrony && \
    chmod 750 /var/lib/chrony /var/log/chrony && \
    chmod 755 /run/chrony /var/run/chrony

# Copy custom chrony configuration
# This will be mounted from the host at runtime
VOLUME ["/etc/chrony"]
VOLUME ["/var/lib/chrony"]

# Expose NTP ports
# UDP 123 - NTP protocol (standard)
# TCP 123 - NTP protocol (for large responses)
# TCP 4460 - NTS-KE (Network Time Security Key Exchange)
EXPOSE 123/udp 123/tcp 4460/tcp

# Health check using chronyc
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD chronyc tracking || exit 1

# Run chronyd in foreground
# -d: Don't daemonize (run in foreground for Docker)
# -x: Don't step the system clock (slew only)
# -s: Set system time from RTC if available (enables clock control)
# Note: Running as root but with minimal capabilities (SYS_TIME, NET_BIND_SERVICE, SETUID, SETGID)
# The -s flag is needed to enable NTP server functionality even though we can't actually
# adjust the container's clock (it will still serve NTP queries)
CMD ["/usr/sbin/chronyd", "-d", "-x", "-s"]
