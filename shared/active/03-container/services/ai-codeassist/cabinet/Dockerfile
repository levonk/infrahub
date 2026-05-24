# Multi-stage Dockerfile for Cabinet - AI-first knowledge base and startup OS
# Base: Alpine Linux (minimal, secure)
# Tech stack: Next.js 16, TypeScript, Node.js

# Build stage - compile Next.js application
FROM node:20-alpine AS build

# Install build dependencies
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install pnpm
RUN npm install -g pnpm@latest

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build Next.js application
RUN pnpm build

# Runtime stage - minimal Alpine image
FROM node:20-alpine AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    dumb-init \
    sqlite

# Create non-root user for security
RUN addgroup -g 1000 -S cabinet && \
    adduser -u 1000 -S cabinet -G cabinet

# Set working directory
WORKDIR /app

# Copy built application from build stage
COPY --from=build --chown=cabinet:cabinet /app/node_modules ./node_modules
COPY --from=build --chown=cabinet:cabinet /app/.next ./.next
COPY --from=build --chown=cabinet:cabinet /app/package.json ./package.json
COPY --from=build --chown=cabinet:cabinet /app/public ./public
COPY --from=build --chown=cabinet:cabinet /app/server ./server
COPY --from=build --chown=cabinet:cabinet /app/src ./src

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    NEXT_TELEMETRY_DISABLED=1

# Switch to non-root user
USER cabinet

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start Cabinet (Next.js + daemon)
CMD ["sh", "-c", "node server/cabinet-daemon.ts & next start"]
