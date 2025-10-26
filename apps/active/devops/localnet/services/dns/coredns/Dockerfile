# Builder stage: prepare Corefile with environment variable expansion
FROM base-alpine:latest AS builder
RUN apk add --no-cache gettext
COPY Corefile.template /Corefile.template
# Expand environment variables in template at build time
RUN mkdir -p /rootfs/etc/coredns && \
    envsubst < /Corefile.template > /rootfs/etc/coredns/Corefile

# Final stage: CoreDNS with expanded Corefile
FROM base-alpine:latest

# Switch to root for package installation
USER root

# Install CoreDNS, gettext (for envsubst in entrypoint), and curl (for healthcheck)
RUN apk add --no-cache coredns gettext curl

# Copy Corefile template for runtime expansion
COPY Corefile.template /etc/coredns/Corefile.template

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint to expand env vars and start CoreDNS
ENTRYPOINT ["/entrypoint.sh"]
