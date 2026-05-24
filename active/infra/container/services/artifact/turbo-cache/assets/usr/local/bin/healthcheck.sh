#!/bin/bash
# Lightweight healthcheck for Nix containers
# Heavy verification runs via supercronic, not this script
# See: /internal-docs/adr/adr-20260109001-nix-container-architecture.md

set -euo pipefail

# Logging functions
info() {
  if [ "${VERBOSE:-}" = "true" ]; then
    echo "[INFO] 🔍 $1"
  fi
}

warn() {
  echo "[WARN] ⚠️ $1"
}

error() {
  echo "[ERROR] ❌ $1"
}

# Test macros
test() {
  info "Testing: $1"
}

success() {
  info "✅ Success: $1"
}

not_applicable() {
  info "⚪️ Not applicable: $1"
}

# Check for verbose flag
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  VERBOSE=true
  shift
fi

# Basic Nix environment check
test "nix binary availability..."
if ! command -v nix-env >/dev/null 2>&1; then
    error "Nix not available"
    exit 1
fi
success "nix binary found"

# Check if nix store is accessible
test "nix store accessibility..."
if ! nix-env --version >/dev/null 2>&1; then
    error "Nix store not accessible"
    exit 1
fi
success "nix store accessible"

# Service-specific health check (customize as needed)
SERVICE_NAME=""
SERVICE_PORT=""


# Traditional service health check
test "service endpoint on port ${SERVICE_PORT}..."
if curl -f "http://127.0.0.1:${SERVICE_PORT}" >/dev/null 2>&1; then
    success "Service responding on port ${SERVICE_PORT}"
else
    error "Service not responding on port ${SERVICE_PORT}"
    exit 1
fi


# Final success message
success "All health checks passed"
exit 0
