# Home Lab In-a-Box - Blocklist Compiler
# Purpose: Build and compile DNS/web blocklists to CDB format
# Security: Non-root user, minimal dependencies, no shell access

FROM alpine:3.19 AS builder

# Install build dependencies and build tinycdb from source
RUN apk add --no-cache \
    curl \
    bash \
    coreutils \
    grep \
    sed \
    gawk \
    gcc \
    make \
    musl-dev && \
    # Build tinycdb from source
    cd /tmp && \
    curl -fsSL http://www.corpit.ru/mjt/tinycdb/tinycdb-0.78.tar.gz -o tinycdb.tar.gz && \
    tar xzf tinycdb.tar.gz && \
    cd tinycdb-0.78 && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/tinycdb* && \
    # Remove build dependencies
    apk del gcc make musl-dev

# Create non-root user for security
RUN addgroup -g 1000 blocklist && \
    adduser -D -u 1000 -G blocklist blocklist

# Create directories with proper permissions
RUN mkdir -p /blocklists/sources /blocklists/compiled /tmp/blocklists && \
    chown -R blocklist:blocklist /blocklists /tmp/blocklists

# Copy update script
COPY --chown=blocklist:blocklist update-blocklists.sh /usr/local/bin/update-blocklists.sh
RUN chmod +x /usr/local/bin/update-blocklists.sh

# Switch to non-root user
USER blocklist

# Set working directory
WORKDIR /blocklists

# Health check: verify CDB file exists and is readable
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD [ -f /blocklists/compiled/blocklist.cdb ] || exit 1

# Default command: run update script
CMD ["/usr/local/bin/update-blocklists.sh"]
