#!/bin/bash
# Nuxt Tweet Organizer Entrypoint Script

set -euo pipefail

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [nuxt-tweet-org] $*"
}

# Function to handle graceful shutdown
cleanup() {
    log "Received shutdown signal, stopping gracefully..."
    if [ -n "${NUXT_PID:-}" ]; then
        kill -TERM "$NUXT_PID" 2>/dev/null || true
        wait "$NUXT_PID" 2>/dev/null || true
    fi
    log "Shutdown complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

log "Starting Nuxt Tweet Organizer service..."

# Change to app directory
cd /app

# Check if we need to clone or update the repository
if [ ! -d ".git" ]; then
    log "Cloning nuxt-tweet-organizer repository..."
    git clone https://github.com/leszekkrol/nuxt-tweet-organizer.git .
else
    log "Updating existing repository..."
    git pull origin main
fi

# Set Node.js environment
export NODE_ENV=production

# Install dependencies using pnpm (NOT npm)
log "Installing dependencies with pnpm..."
if [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile --prod
else
    pnpm install --prod
fi

# Build the application using pnpm
log "Building application with pnpm..."
pnpm build

# Start the production server using pnpm
log "Starting production server..."
pnpm start &
NUXT_PID=$!

log "Nuxt Tweet Organizer started with PID: $NUXT_PID"

# Wait for the process
wait "$NUXT_PID"
