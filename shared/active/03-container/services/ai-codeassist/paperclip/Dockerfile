# Paperclip AI Orchestration Service
# Open-source orchestration for zero-human companies
# See: https://github.com/paperclipai/paperclip
#
# Multi-stage build per AGENTS.md Invariant #2:
#   - builder: clones paperclip from GitHub, installs deps, builds
#   - runtime: alpine with only the built artifacts + production deps
#
# Build platform: linux/arm64 (target is OCI cloud server).
# The source is cloned from GitHub during the build — no local source needed.
# Uses the existing `node` user (UID 1000, GID 1000) from the base image.

# ---------------------------------------------------------------------------
# Builder stage — clone and build paperclip from source
# ---------------------------------------------------------------------------
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Install pnpm globally
RUN npm install -g pnpm@9.15.0

# Clone paperclip from GitHub
# Pin to a stable ref for reproducibility. Update the ref when bumping.
ARG PAPERCLIP_REF=master
WORKDIR /usr/src/paperclip
RUN git clone --depth 1 --branch "${PAPERCLIP_REF}" https://github.com/paperclipai/paperclip.git /usr/src/paperclip

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
RUN pnpm build

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM node:20-alpine AS runtime

# Install pnpm globally
RUN npm install -g pnpm@9.15.0

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    postgresql-client

# Set working directory
WORKDIR /app

# Copy package files from builder
COPY --from=builder --chown=node:node /usr/src/paperclip/package.json ./
COPY --from=builder --chown=node:node /usr/src/paperclip/pnpm-lock.yaml ./

# Install production dependencies only
RUN pnpm install --prod --frozen-lockfile && \
    pnpm cache clean --force

# Copy built application from builder
COPY --from=builder --chown=node:node /usr/src/paperclip/dist ./dist
COPY --from=builder --chown=node:node /usr/src/paperclip/node_modules ./node_modules

# Use the existing node user (UID 1000, GID 1000)
USER node

# Expose Paperclip API port
EXPOSE 3100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://127.0.0.1:3100/health || exit 1

# Set environment variables
ENV NODE_ENV=production \
    PORT=3100

# Start Paperclip
CMD ["pnpm", "start"]
