#!/bin/sh

# Docker entrypoint script for Claude Code Intercept
# Starts both the Go proxy server and Remix frontend

set -e

log() {
  printf '%s %s\n' "[claude-code-intercept]" "$1"
}

cleanup() {
  log "Stopping services..."
  kill "$PROXY_PID" "$WEB_PID" 2>/dev/null || true
  exit 0
}

trap cleanup SIGTERM SIGINT

API_PORT=${CLAUDE_CODE_INTERCEPT_API_PORT:-3001}
UI_PORT=${CLAUDE_CODE_INTERCEPT_UI_PORT:-5173}
API_READ_TIMEOUT=${CLAUDE_CODE_INTERCEPT_READ_TIMEOUT:-600s}
API_WRITE_TIMEOUT=${CLAUDE_CODE_INTERCEPT_WRITE_TIMEOUT:-600s}
API_IDLE_TIMEOUT=${CLAUDE_CODE_INTERCEPT_IDLE_TIMEOUT:-600s}
API_DB_PATH=${CLAUDE_CODE_INTERCEPT_DB_PATH:-/app/data/requests.db}

export PORT=${PORT:-$API_PORT}
export WEB_PORT=${WEB_PORT:-$UI_PORT}
export READ_TIMEOUT=${READ_TIMEOUT:-$API_READ_TIMEOUT}
export WRITE_TIMEOUT=${WRITE_TIMEOUT:-$API_WRITE_TIMEOUT}
export IDLE_TIMEOUT=${IDLE_TIMEOUT:-$API_IDLE_TIMEOUT}
export DB_PATH=${DB_PATH:-$API_DB_PATH}

log "Launching Claude Code Intercept"
log "Proxy: http://0.0.0.0:${PORT}"
log "UI:    http://0.0.0.0:${WEB_PORT}"
log "DB:    ${DB_PATH}"
log "Router URL: ${ANTHROPIC_FORWARD_URL}"

log "Starting proxy service"
PORT=${PORT} \
READ_TIMEOUT=${READ_TIMEOUT} \
WRITE_TIMEOUT=${WRITE_TIMEOUT} \
IDLE_TIMEOUT=${IDLE_TIMEOUT} \
ANTHROPIC_FORWARD_URL=${CLAUDE_CODE_INTERCEPT_TO_ROUTER_URL} \
ANTHROPIC_VERSION=${CLAUDE_CODE_INTERCEPT_TO_ROUTER_VERSION} \
ANTHROPIC_MAX_RETRIES=${CLAUDE_CODE_INTERCEPT_TO_ROUTER_MAX_RETRIES} \
DB_PATH=${DB_PATH} \
/app/bin/proxy &
PROXY_PID=$!

sleep 3

log "Starting Remix UI"
cd /app/web
PORT=${WEB_PORT} HOST=0.0.0.0 NODE_ENV=production npx remix-serve build/server/index.js &
WEB_PID=$!
cd /app

wait
