# 9Router - AI Router & Token Saver
# Alpine-based container following LocalNet standards
# Base: localnet-base-alpine

FROM localnet-base-alpine AS builder

# Install build dependencies for Node.js
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    python3 \
    make \
    g++ \
    linux-headers

WORKDIR /build

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Runtime stage
FROM localnet-base-alpine AS runtime

# Labels for metadata
LABEL org.opencontainers.image.title="9Router" \
      org.opencontainers.image.description="AI router and token saver for LLM providers" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="LocalNet" \
      org.opencontainers.image.base_os="alpine" \
      maintainer="devops@localnet"

ARG PUID=1000
ARG PGID=1000

# Environment variables
ENV NODE_ENV=production \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    NEXT_TELEMETRY_DISABLED=1 \
    DATA_DIR=/app/data

# Create application directory
RUN mkdir -p /app/data && \
    chown -R ${PUID}:${PGID} /app

# Copy built artifacts from builder
COPY --from=builder --chown=${PUID}:${PGID} /build/public ./public
COPY --from=builder --chown=${PUID}:${PGID} /build/.next/static ./.next/static
COPY --from=builder --chown=${PUID}:${PGID} /build/.next/standalone ./
COPY --from=builder --chown=${PUID}:${PGID} /build/open-sse ./open-sse
COPY --from=builder --chown=${PUID}:${PGID} /build/src/mitm ./src/mitm
COPY --from=builder --chown=${PUID}:${PGID} /build/node_modules/node-forge ./node_modules/node-forge
COPY --from=builder --chown=${PUID}:${PGID} /build/node_modules/next ./node_modules/next

# Switch to non-root user
USER ${PUID}

WORKDIR /app

# Expose service port
EXPOSE 20128

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:20128/health || exit 1

# Start the application
CMD ["node", "server.js"]
