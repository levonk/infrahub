FROM alpine:latest

# Install iptables and basic networking tools
RUN apk add --no-cache \
    iptables \
    ip6tables \
    iproute2 \
    bind-tools \
    curl

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD iptables -t nat -L -n | grep -q DNAT || exit 1

ENTRYPOINT ["/entrypoint.sh"]
