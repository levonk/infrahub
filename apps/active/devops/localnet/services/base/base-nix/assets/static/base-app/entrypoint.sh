#!/bin/sh
# =============================================================================
# Base Nix Entrypoint Script
# =============================================================================
# Purpose: Initialize and configure the Nix environment for LocalNet services
# Context: Runs as the main entrypoint for base-nix container
# Inheritance: This script is inherited by base-sidecar containers
# =============================================================================

# Exit immediately if any command fails
set -e

# =============================================================================
# Environment Variables Configuration
# =============================================================================
# Default values for user configuration
# - PUID: User ID for the non-root user (default: 1000)
# - PGID: Group ID for the non-root user (default: 1000)
# - USERNAME: Username for the non-root user (default: cuser)
# These can be overridden via environment variables or docker-compose
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

# Configure trusted users for Nix builds
echo "🤖 Base Nix: Configuring trusted users..."
if [ -f /etc/nix/nix.conf ]; then
    # Build trusted-users list - use only shell built-ins (no external commands)
    TRUSTED_USERS="root"

    # Add current USERNAME if set (this is the most common case)
    if [ -n "$USERNAME" ]; then
        TRUSTED_USERS="$TRUSTED_USERS $USERNAME"
    fi

    # Add other common container users that might be used
    # We'll add them statically since we can't check /etc/passwd without external commands
    TRUSTED_USERS="$TRUSTED_USERS cuser devuser debuser nixuser"

    # Simply append to nix.conf - we can't check if it already exists without grep
    echo "trusted-users = $TRUSTED_USERS" >> /etc/nix/nix.conf

    echo "✅ Configured trusted-users dynamically: $TRUSTED_USERS"
else
    echo "❌ nix.conf not found"
fi

echo "🤖 Base Nix: Starting entrypoint..."

# =============================================================================
# Nix Environment Cleanup
# =============================================================================
# Clear any invalid NIX_CONFIG that might cause warnings
# This prevents configuration conflicts from the host environment
unset NIX_CONFIG 2>/dev/null || true

# =============================================================================
# Nix Environment Verification Function
# =============================================================================
# Purpose: Verify that Nix is properly installed and configured
# Checks: Binary availability, /nix/store existence, version information
# Usage: Called later in the script to validate setup
verify_nix() {
    echo "🤖 Base Nix: Verifying Nix environment..."

    # Check for nix binary in multiple possible locations
    if [ -x /bin/nix ] || [ -x /usr/local/bin/nix ] || command -v nix >/dev/null 2>&1; then
        echo "✅ nix binary found"
        # Source Nix environment if available
        [ -f /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
        # Display version (with error handling)
        nix --version || echo "⚠️ nix --version failed"
    else
        echo "❌ nix binary missing"
    fi

    # Check if Nix store directory exists and has content
    if [ -d /nix/store ]; then
        echo "✅ /nix/store exists ($(ls -A /nix/store 2>/dev/null | wc -l) items)"
    else
        echo "❌ /nix/store missing"
    fi
}

# =============================================================================
# Nix Environment Bootstrap
# =============================================================================
# Problem: When Docker volumes are mounted, they can overwrite /nix directory
# Solution: Restore Nix environment from bootstrap tarball if needed
# The tarball was created during Docker build in Dockerfile.base-nix
# =============================================================================
# Check if Nix environment needs initialization
# - If /nix/store doesn't exist OR is empty, we need to bootstrap
if [ ! -d "/nix/store" ] || [ -z "$(ls -A /nix/store 2>/dev/null)" ]; then
    echo "🤖 Base Nix: Initializing Nix environment from backup tarball..."

    # Check if bootstrap tarball exists (created during Docker build)
    if [ -f "/base-app/tmp/bootstrap-slash-nix.tar" ]; then
        echo "🤖 Base Nix: Restoring from /base-app/tmp/bootstrap-slash-nix.tar..."
        # Extract tarball to root (/) to restore nix/, bin/, etc/
        tar -C / -xf /base-app/tmp/bootstrap-slash-nix.tar
        echo "🤖 Base Nix: Nix environment initialized."
    else
        echo "❌ Base Nix: Error: /base-app/tmp/bootstrap-slash-nix.tar is missing. Cannot initialize Nix."
        exit 1
    fi
fi

# =============================================================================
# PATH Configuration
# =============================================================================
# Ensure Nix binaries are in the PATH with proper precedence
# - Nix profiles come first for user-installed packages
# - System binaries follow for base utilities
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# =============================================================================
# Nix Profiles and Channels Setup
# =============================================================================
# Set up profiles and channels if missing (required for Nix package management)
# Profiles are where Nix stores user-specific packages and environments
mkdir -p /nix/var/nix/profiles/per-user/root

# Create root user's Nix profile symlink if it doesn't exist
if [ ! -L "/root/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/root/profile /root/.nix-profile
fi

# Ensure default profile link exists in the shared volume if it was lost
# This is important when volumes are mounted and can overwrite symlinks
if [ ! -L "/nix/var/nix/profiles/default" ]; then
    ln -sf /nix/var/nix/profiles/per-user/root/profile /nix/var/nix/profiles/default
fi

# =============================================================================
# Nix Build Users Setup
# =============================================================================
# Purpose: Create nixbld group and build users for multi-user Nix builds
# Security: Build users are isolated and cannot login (nologin shell)
# Compliance: Required for multi-user Nix sandboxed builds
# =============================================================================
echo "🤖 Base Nix: Setting up Nix build users..."
nix develop /base-app --command bash -c "
# Create nixbld group with GID 30000 (standard Nix convention)
if ! getent group nixbld > /dev/null 2>&1; then
    echo \"🤖 Base Nix: Creating nixbld group (GID: 30000)\"
    groupadd -g 30000 nixbld || echo \"⚠️ nixbld group creation failed\"
else
    echo \"✅ nixbld group already exists\"
fi

# Create nixbld build users (nixbld1 through nixbld32)
# These users perform sandboxed builds with minimal privileges
for i in \$(seq 1 32); do
    if ! getent passwd \"nixbld\$i\" > /dev/null 2>&1; then
        echo \"🤖 Base Nix: Creating nixbld\$i user\"
        useradd -M -g nixbld -G nixbld -s /usr/sbin/nologin \"nixbld\$i\" || echo \"⚠️ nixbld\$i user creation failed\"
    else
        echo \"✅ nixbld\$i user already exists\"
    fi
done
echo \"✅ Nix build users (nixbld1-32) setup complete\"
"

# =============================================================================
# User Management Setup
# =============================================================================
# Purpose: Create and configure non-root user with proper UID/GID
# Context: Run within flake environment to have access to shadow tools (groupadd, useradd)
# Security: Containers should run as non-root users following security best practices
# =============================================================================
# User management (run within flake environment to have access to shadow tools)
echo "🤖 Base Nix: Setting up user management..."
nix develop /base-app --command bash -c "
# Check if user already exists
if ! id \"$USERNAME\" >/dev/null 2>&1; then
    echo \"🤖 Base Nix: Creating user $USERNAME (UID: $PUID, GID: $PGID)\"
    # Create group first
    groupadd -g \"$PGID\" \"$USERNAME\" || true
    # Create home directory
    mkdir -p \"/home/$USERNAME\"
    # Create user with specified UID/GID and home directory
    useradd -u \"$PUID\" -g \"$PGID\" -d \"/home/$USERNAME\" -s /bin/bash \"$USERNAME\"
    # Set ownership of home directory
    chown -R \"$PUID:$PGID\" \"/home/$USERNAME\"
else
    echo \"🤖 Base Nix: Configuring user $USERNAME (UID: $PUID, GID: $PGID)\"
    # Get current UID/GID for existing user
    CUR_UID=\$(id -u \"$USERNAME\")
    CUR_GID=\$(id -g \"$USERNAME\")

    # Update GID if different (allow existing GID with -o flag)
    if [ \"\$CUR_GID\" != \"$PGID\" ]; then
        groupmod -o -g \"$PGID\" \"$USERNAME\" || echo \"⚠️ groupmod failed\"
    fi
    # Update UID if different (allow existing UID with -o flag)
    if [ \"\$CUR_UID\" != \"$PUID\" ]; then
        usermod -o -u \"$PUID\" \"$USERNAME\" || echo \"⚠️ usermod failed\"
    fi

    # Ensure home directory has correct ownership
    if [ -d \"/home/$USERNAME\" ]; then
        chown -R \"$PUID:$PGID\" \"/home/$USERNAME\"
    fi
fi
"

# =============================================================================
# User Nix Profile Setup
# =============================================================================
# Purpose: Create and configure Nix profile for the non-root user
# This allows the user to install their own Nix packages independently
# =============================================================================
# Set up user Nix profile
mkdir -p /nix/var/nix/profiles/per-user/"$USERNAME"
# Ensure parent directory has correct permissions for user access
chmod 755 /nix/var/nix/profiles/per-user
# Set ownership of user's profile directory
chown "$PUID:$PGID" /nix/var/nix/profiles/per-user
chown -R "$PUID:$PGID" /nix/var/nix/profiles/per-user/"$USERNAME"
# Create symlink in user's home directory to their Nix profile
if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/"$USERNAME"/profile "/home/$USERNAME/.nix-profile"
    # Set ownership of the symlink itself (-h flag affects symlink, not target)
    chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
fi

# =============================================================================
# Final Verification
# =============================================================================
# Run verification to ensure Nix environment is properly set up
# This validates that all components are working before proceeding
verify_nix

# =============================================================================
# User Execution Function
# =============================================================================
# Purpose: Execute commands as the non-root user with proper environment
# Security: Ensures commands run with reduced privileges
# Environment: Runs within nix develop for consistent PATH and dependencies
exec_as_user() {
    local cmd="$*"
    echo "🤖 Base Nix: Executing as user $USERNAME: $cmd"
    # Always run within nix develop environment for consistent PATH and dependencies
    nix develop /base-app --command bash -c "
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
    "
}

echo "🤖 Base Nix: Ready."

# =============================================================================
# Main Execution Logic
# =============================================================================
# Purpose: Execute provided command or default to sleep loop
# Behavior:
# - --init-only: Run setup only, then exit (for inheritance cases)
# - With other arguments: Execute the command as the non-root user
# - Without arguments: Enter sleep loop to keep container running
# =============================================================================

# Check for --init-only flag
if [ "$1" = "--init-only" ]; then
    echo "🤖 Base Nix: Initialization mode - running setup only"
    echo "🤖 Base Nix: Setup completed successfully - exiting"
    exit 0
fi

# Execute command or sleep
if [ "$#" -gt 0 ]; then
    echo "🤖 Base Nix: Executing command: $@"
    exec_as_user "$@"
else
    echo "🤖 Base Nix: Entering wait loop."
    # Default sleep command when no arguments provided
    # This keeps the container running for health checks and debugging
    exec_as_user "sleep 30"
fi
