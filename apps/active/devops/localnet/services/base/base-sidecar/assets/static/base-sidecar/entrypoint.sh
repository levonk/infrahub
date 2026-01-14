#!/bin/sh
# =============================================================================
# Base Sidecar Entrypoint Script
# =============================================================================
# Purpose: Extend base-nix functionality with additional sidecar capabilities
# Context: Runs as the main entrypoint for base-sidecar container
# Inheritance: Inherits /base-app and /base-nix directories from base-nix
# Usage: Base image for services that need both Nix and additional tools
# =============================================================================

# Exit immediately if any command fails
set -e

# =============================================================================
# Environment Variables Configuration
# =============================================================================
# Default values for user configuration (inherited from base-nix)
# - PUID: User ID for the non-root user (default: 1000)
# - PGID: Group ID for the non-root user (default: 1000)
# - USERNAME: Username for the non-root user (default: cuser)
# These can be overridden via environment variables or docker-compose
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Base Sidecar: Starting entrypoint..."

# =============================================================================
# PATH Configuration
# =============================================================================
# Ensure Nix binaries are in the PATH (simplified since base-nix already setup)
# Note: This is a basic PATH since base-nix already configured the full Nix PATH
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# =============================================================================
# User Execution Function (Sidecar Context)
# =============================================================================
# Purpose: Execute commands as the non-root user with proper environment
# Security: Ensures commands run with reduced privileges
# Environment: Runs within sidecar nix develop for sidecar-specific dependencies
exec_as_user() {
    local cmd="$1"
    echo "🤖 Base Sidecar: Executing as user $USERNAME: $cmd"
    # Try different user switching methods in order of preference:
    # 1. gosu: Modern, secure user switching (preferred)
    # 2. su-exec: Alpine-compatible user switching
    # 3. su: Traditional Unix user switching (fallback)
    if command -v gosu >/dev/null 2>&1; then
        exec gosu \"$USERNAME\" $cmd
    elif command -v su-exec >/dev/null 2>&1; then
        exec su-exec \"$USERNAME\" $cmd
    else
        exec su \"$USERNAME\" -s /bin/sh -c \"$cmd\"
    fi
}

echo "🤖 Base Sidecar: Ready."

# =============================================================================
# Main Execution Logic (Sidecar Context)
# =============================================================================
# Purpose: Execute provided command or default to sleep loop
# Behavior:
# - With arguments: Execute the command as the non-root user
# - Without arguments: Enter sleep loop to keep container running
# Context: Uses sidecar-specific nix develop environment
# =============================================================================
# Execute command or `sleep 30` as main process
if [ "$#" -gt 0 ]; then
	echo "🤖 Base Sidecar: Executing command: $*"
    exec_as_user "$*"
else
	echo "🤖 Base Sidecar: sleeping for 30 seconds then exiting..."
    # Default sleep command when no arguments provided
    # This keeps the container running for health checks and debugging
    exec_as_user "sleep 30"
fi
