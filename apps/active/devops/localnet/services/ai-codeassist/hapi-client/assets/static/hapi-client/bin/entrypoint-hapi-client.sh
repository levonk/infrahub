#!/bin/bash
set -e

# HAPI Client Entrypoint - Calls base-dev entrypoint first, then HAPI setup
echo "🤖 HAPI Client: Starting entrypoint..."

# First, execute the base-dev entrypoint to set up the development environment
if [ -f "/home/${USERNAME}/.local/bin/entrypoint-base-dev.sh" ]; then
    echo "🤖 HAPI Client: Running base-dev entrypoint setup..."
    # Execute base-dev entrypoint but don't let it exec (we need to continue)
    /home/${USERNAME}/.local/bin/entrypoint-base-dev.sh /bin/true || {
        echo "⚠️ HAPI Client: Base-dev entrypoint had issues, continuing..."
    }
elif [ -f "/base-dev/bin/entrypoint-base-dev.sh" ]; then
    echo "🤖 HAPI Client: Running base-dev entrypoint setup..."
    /base-dev/bin/entrypoint-base-dev.sh /bin/true || {
        echo "⚠️ HAPI Client: Base-dev entrypoint had issues, continuing..."
    }
else
    echo "⚠️ HAPI Client: Base-dev entrypoint not found, proceeding with minimal setup"
fi

# Now proceed with HAPI-specific setup
echo "🤖 HAPI Client: Starting HAPI-specific setup..."

# Ensure Nix binaries are in the PATH, searching multiple profile locations
# Include user's nix profile in PATH
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/home/${USERNAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Find and set SSL certificate paths for HTTPS to work with Nix
echo "🤖 HAPI Client: Setting up SSL certificates..."
CACERT_PATH=$(find /nix/store -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1)
if [ -n "$CACERT_PATH" ] && [ -f "$CACERT_PATH" ]; then
    echo "🤖 HAPI Client: Found CA certificates at $CACERT_PATH"
    export NIX_SSL_CERT_FILE="$CACERT_PATH"
    export SSL_CERT_FILE="$CACERT_PATH"
    export CURL_CA_BUNDLE="$CACERT_PATH"
    export GIT_SSL_CAINFO="$CACERT_PATH"
    echo "✅ SSL certificate environment variables set"
else
    echo "⚠️ Warning: Could not find CA certificates, HTTPS may not work properly"
fi

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

# Function to execute command as user (for setup commands)
execute_as_user_setup() {
    echo "🤖 HAPI Client: Executing as $USERNAME: $@"
    echo "🤖 HAPI Client: PATH is $PATH"
    if command -v gosu >/dev/null 2>&1; then
        # Verify command availability for user
        if ! gosu "$USERNAME" which "$(echo "$@" | awk '{print $1}')" 2>/dev/null; then
            echo "⚠️ Command not found in user PATH, skipping..."
            return 0
        fi
        # Use shell -c to properly handle pipes and shell syntax
        # Pass SSL certificate environment variables to the user environment
        gosu "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    elif command -v su-exec >/dev/null 2>&1; then
        su-exec "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    else
        echo "❌ HAPI Client: Error: No gosu or su-exec found. Cannot drop privileges."
        exit 1
    fi
}

# Function to execute final command as user (uses exec)
execute_as_user() {
    echo "🤖 HAPI Client: Executing as $USERNAME: $@"
    echo "🤖 HAPI Client: PATH is $PATH"
    if command -v gosu >/dev/null 2>&1; then
        # Verify command availability for user
        if ! gosu "$USERNAME" which "$(echo "$@" | awk '{print $1}')" 2>/dev/null; then
            echo "⚠️ Command not found in user PATH, skipping..."
            return 0
        fi
        # Use shell -c to properly handle pipes and shell syntax
        # Pass SSL certificate environment variables to the user environment
        exec gosu "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    elif command -v su-exec >/dev/null 2>&1; then
        exec su-exec "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    else
        echo "❌ HAPI Client: Error: No gosu or su-exec found. Cannot drop privileges."
        exit 1
    fi
}

# Activate Nix development environment if available
if [ -f "/home/$USERNAME/project/flake.nix" ] && command -v nix >/dev/null 2>&1; then
    echo "🤖 HAPI Client: Activating Nix development environment..."
    cd "/home/$USERNAME/project"

    # Source the Nix profile to make nix command available
    if [ -f "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Use nix print-dev-env to activate the environment with all packages
    echo "🤖 HAPI Client: Activating nix develop environment..."
    # Ensure SSL certificate variables are passed to nix develop
    eval "$(NIX_SSL_CERT_FILE="$NIX_SSL_CERT_FILE" SSL_CERT_FILE="$SSL_CERT_FILE" CURL_CA_BUNDLE="$CURL_CA_BUNDLE" GIT_SSL_CAINFO="$GIT_SSL_CAINFO" NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features nix-command --extra-experimental-features flakes print-dev-env --impure)"

    # Update PATH to include nix environment
    export PATH="/home/$USERNAME/.nix-profile/bin:$PATH"
fi

# HAPI-specific setup
echo "🤖 HAPI Client: Setting up HAPI environment..."

# Set HAPI environment variables
export NODE_ENV=production
export HAPI_API_URL=${HAPI_API_URL:-http://hapi-server:3006}

echo "🤖 HAPI Client starting..."
echo "Server URL: ${HAPI_API_URL:-http://hapi-server:3006}"
echo "CLI API Token: ${CLI_API_TOKEN:+(set)}"

# Wait for server to be ready if server URL is provided
if [ -n "${HAPI_API_URL}" ]; then
    echo "⏳ Waiting for HAPI server at ${HAPI_API_URL}..."

    # Wait for server to be ready (with timeout)
    timeout=60
    while [ $timeout -gt 0 ]; do
        if curl -f -s "${HAPI_API_URL}/health" > /dev/null 2>&1; then
            echo "✅ HAPI server is ready!"
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done

    if [ $timeout -le 0 ]; then
        echo "❌ Timeout waiting for HAPI server at ${HAPI_API_URL}"
        echo "⚠️  Starting client anyway - you may need to start the server first"
    fi
fi

# Check if CLI API token is set
if [ -z "${CLI_API_TOKEN}" ]; then
    echo "⚠️  Warning: CLI_API_TOKEN not set"
    echo "   Set this environment variable to authenticate with the server"
fi

# Install HAPI CLI if not already available
if ! command -v hapi >/dev/null 2>&1; then
    echo "🤖 HAPI Client: Installing HAPI CLI..."
    if command -v pnpm >/dev/null 2>&1; then
        execute_as_user_setup "pnpm install -g @twsxtd/hapi" || echo "⚠️ Failed to install HAPI CLI via npm"
    else
        echo "⚠️ No pnpm found, HAPI CLI may not be available"
    fi
fi

echo "🚀 Starting HAPI client..."

# If no arguments provided, start HAPI interactive session
if [ $# -eq 0 ]; then
    set -- "hapi"
fi

# Execute command as user
execute_as_user "$@"
