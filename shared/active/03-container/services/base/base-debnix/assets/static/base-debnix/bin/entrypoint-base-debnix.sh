#!/bin/bash
set -e

# Get username from environment or default to ansible
USERNAME=${USERNAME:-ansible}

# Ensure Nix binaries are in the PATH, searching multiple profile locations
# Include user's nix profile in PATH
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/home/${USERNAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Find and set SSL certificate paths for HTTPS to work with Nix
echo "🤖 base-debnix: Setting up SSL certificates..."
CACERT_PATH=$(find /nix/store -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1)
if [ -n "$CACERT_PATH" ] && [ -f "$CACERT_PATH" ]; then
    echo "🤖 base-debnix: Found CA certificates at $CACERT_PATH"
    export NIX_SSL_CERT_FILE="$CACERT_PATH"
    export SSL_CERT_FILE="$CACERT_PATH"
    export CURL_CA_BUNDLE="$CACERT_PATH"
    export GIT_SSL_CAINFO="$CACERT_PATH"
    echo "✅ SSL certificate environment variables set"
else
    echo "⚠️ Warning: Could not find CA certificates, HTTPS may not work properly"
fi

# Configure trusted users for Nix builds (if we have write access)
echo "🤖 base-debnix: Configuring trusted users..."
if [ -f /etc/nix/nix.conf ] && [ -w /etc/nix/nix.conf ]; then
    # Build trusted-users list - use only shell built-ins (no external commands)
    TRUSTED_USERS="root"

    # Add current USERNAME if set (this is the most common case)
    if [ -n "$USERNAME" ]; then
        TRUSTED_USERS="$TRUSTED_USERS $USERNAME"
    fi

    # Add other common container users that might be used
    # We'll add them statically since we can't check /etc/passwd without external commands
    TRUSTED_USERS="$TRUSTED_USERS ansible cuser devuser debuser nixuser"

    # Simply append to nix.conf - we can't check if it already exists without grep
    echo "trusted-users = $TRUSTED_USERS" >> /etc/nix/nix.conf

    echo "✅ Configured trusted-users dynamically: $TRUSTED_USERS"
else
    echo "⚠️ nix.conf not found or not writable - Nix provided by nix-sidecar, skipping local configuration"
fi

echo "🤖 base-debnix: Starting entrypoint..."

# Execute command directly (already running as target user)
echo "🤖 base-debnix: Executing as $USERNAME: $@"
exec "$@"
