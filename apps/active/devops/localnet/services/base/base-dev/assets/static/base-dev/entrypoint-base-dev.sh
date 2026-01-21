#!/bin/bash
set -e

# Ensure Nix binaries are in the PATH, searching multiple profile locations
# Include user's nix profile in PATH
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/home/${USERNAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Find and set SSL certificate paths for HTTPS to work with Nix
echo "🤖 Dev Base: Setting up SSL certificates..."
CACERT_PATH=$(find /nix/store -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1)
if [ -n "$CACERT_PATH" ] && [ -f "$CACERT_PATH" ]; then
    echo "🤖 Dev Base: Found CA certificates at $CACERT_PATH"
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

# Align git committer identity with author if committer overrides are absent
if [ -z "${GIT_COMMITTER_NAME:-}" ] && [ -n "${GIT_AUTHOR_NAME:-}" ]; then
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
fi
if [ -z "${GIT_COMMITTER_EMAIL:-}" ] && [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
fi

echo "🤖 Dev Base: Starting entrypoint..."

# Function to find a tool in multiple locations
find_tool() {
    local tool=$1
    if command -v "$tool" >/dev/null 2>&1; then
        command -v "$tool"
        return 0
    fi
    # Search common Nix profile paths
    for p in /nix/var/nix/profiles/default/bin \
             /nix/var/nix/profiles/per-user/root/profile/bin \
             /root/.nix-profile/bin \
             /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do
        if [ -x "$p/$tool" ]; then
            echo "$p/$tool"
            return 0
        fi
    done
    return 1
}

SU_EXEC=$(find_tool su-exec)
GOSU=$(find_tool gosu)
SU=$(find_tool su)
ID=$(find_tool id)
GROUPMOD=$(find_tool groupmod)
USERMOD=$(find_tool usermod)
CHOWN=$(find_tool chown)

# Check if user exists
if [ -n "$ID" ] && "$ID" "$USERNAME" &>/dev/null; then
    # Update group ID if needed
    CUR_GID=$("$ID" -g "$USERNAME")
    if [ "$CUR_GID" != "$PGID" ] && [ -n "$GROUPMOD" ]; then
        echo "Updating GID from $CUR_GID to $PGID"
        "$GROUPMOD" -o -g "$PGID" "$USERNAME" || true
    fi

    # Update user ID if needed
    CUR_UID=$("$ID" -u "$USERNAME")
    if [ "$CUR_UID" != "$PUID" ] && [ -n "$USERMOD" ]; then
        echo "Updating UID from $CUR_UID to $PUID"
        "$USERMOD" -o -u "$PUID" "$USERNAME" || true
    fi

	# Create nixbld group if it doesn't exist (required for Nix builds)
	if ! getent group nixbld >/dev/null 2>&1; then
		echo "🤖 Dev Base: Creating nixbld group..."
		groupadd -r nixbld
		# Add the user to nixbld group to allow builds
		usermod -a -G nixbld "$USERNAME"
	fi

    # Fix permissions for home directory
    if [ -d "/home/$USERNAME" ] && [ -n "$CHOWN" ]; then
        "$CHOWN" -R "$PUID:$PGID" "/home/$USERNAME"
    fi

    # Ensure user's own Nix profile exists
    if [ -L "/home/$USERNAME/.nix-profile" ] && [ -d "/home/$USERNAME/.nix-profile/bin" ]; then
        echo "🤖 Dev Base: Using existing Nix profile..."
    elif [ -d "/nix/var/nix/profiles/per-user/$USERNAME/profile" ]; then
        echo "🤖 Dev Base: Creating Nix profile symlink..."
        ln -sf /nix/var/nix/profiles/per-user/$USERNAME/profile "/home/$USERNAME/.nix-profile"
        chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
    elif [ -d "/nix/var/nix/profiles/per-user/root/profile" ]; then
        echo "🤖 Dev Base: Linking to root Nix profile as fallback..."
        ln -sf /nix/var/nix/profiles/per-user/root/profile "/home/$USERNAME/.nix-profile"
        chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
    else
        echo "⚠️ Dev Base: Nix profile not found, using system tools only"
    fi
fi

# Function to execute command as user (for setup commands)
execute_as_user_setup() {
    echo "🤖 Dev Base: Executing as $USERNAME: $@"
    echo "🤖 Dev Base: PATH is $PATH"
    if [ -n "$GOSU" ]; then
        # Verify command availability for user
        if ! "$GOSU" "$USERNAME" which "$(echo "$@" | awk '{print $1}')" 2>/dev/null; then
            echo "⚠️ Command not found in user PATH, skipping..."
            return 0
        fi
        # Use shell -c to properly handle pipes and shell syntax
        # Pass SSL certificate environment variables to the user environment
        "$GOSU" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    elif [ -n "$SU_EXEC" ]; then
        "$SU_EXEC" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    else
        echo "❌ Dev Base: Error: No gosu or su-exec found. Cannot drop privileges."
        exit 1
    fi
}

# Function to execute final command as user (uses exec)
execute_as_user() {
    echo "🤖 Dev Base: Executing as $USERNAME: $@"
    echo "🤖 Dev Base: PATH is $PATH"
    if [ -n "$GOSU" ]; then
        # Verify command availability for user
        if ! "$GOSU" "$USERNAME" which "$(echo "$@" | awk '{print $1}')" 2>/dev/null; then
            echo "⚠️ Command not found in user PATH, skipping..."
            return 0
        fi
        # Use shell -c to properly handle pipes and shell syntax
        # Pass SSL certificate environment variables to the user environment
        exec "$GOSU" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    elif [ -n "$SU_EXEC" ]; then
        exec "$SU_EXEC" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    else
        echo "❌ Dev Base: Error: No gosu or su-exec found. Cannot drop privileges."
        exit 1
    fi
}

# Activate Nix development environment if available
if [ -f "/home/$USERNAME/project/flake.nix" ] && command -v nix >/dev/null 2>&1; then
    echo "🤖 Dev Base: Activating Nix development environment..."
    cd "/home/$USERNAME/project"

    # Source the Nix profile to make nix command available
    if [ -f "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Use nix print-dev-env to activate the environment with all packages
    echo "🤖 Dev Base: Activating nix develop environment..."
    # Ensure SSL certificate variables are passed to nix develop
    eval "$(NIX_SSL_CERT_FILE="$NIX_SSL_CERT_FILE" SSL_CERT_FILE="$SSL_CERT_FILE" CURL_CA_BUNDLE="$CURL_CA_BUNDLE" GIT_SSL_CAINFO="$GIT_SSL_CAINFO" nix print-dev-env)"

    # Update PATH to include nix environment
    export PATH="/home/$USERNAME/.nix-profile/bin:$PATH"
fi

# Optional setup commands - these may fail if tools aren't available
echo "🤖 Dev Base: Running optional setup commands..."
if command -v curl >/dev/null 2>&1; then
    # Try with SSL verification first, fallback to insecure if needed
    if execute_as_user_setup "curl --connect-timeout 10 -fsSL https://app.factory.ai/cli | sh" 2>/dev/null; then
        echo "✅ app.factory.ai CLI installed successfully"
    else
        echo "⚠️ SSL verification failed, trying with --insecure flag..."
        execute_as_user_setup "curl --connect-timeout 10 --insecure -fsSL https://app.factory.ai/cli | sh" || echo "⚠️ Failed to install app.factory.ai CLI"
    fi
else
    echo "⚠️ curl not available, skipping app.factory.ai CLI installation"
fi

if command -v uv >/dev/null 2>&1; then
    # Try to install with system Python, specifying the interpreter explicitly
    if command -v python3 >/dev/null 2>&1; then
        execute_as_user_setup "uv pip install --python $(which python3) --system llm-tldr"
    elif command -v python >/dev/null 2>&1; then
        execute_as_user_setup "uv pip install --python $(which python) --system llm-tldr"
    else
        echo "⚠️ No Python interpreter found, skipping llm-tldr installation"
    fi
    execute_as_user_setup "cd /home/$USERNAME/work; tldr warm . && tldr context main --project ." || echo "⚠️ Failed to run llm-tldr commands"
else
    echo "⚠️ uv not available, skipping llm-tldr commands"
fi

if command -v pnpm >/dev/null 2>&1; then
    execute_as_user_setup "pnpm install -g @beads/bd" || echo "⚠️ Failed to run pnpm install -g @beads/bd"
    execute_as_user_setup "pnpm install -g openskills" || echo "⚠️ Failed to run pnpm install -g openskills"
    execute_as_user_setup "pnpm install -g agent-browser" || echo "⚠️ Failed to run pnpm install -g agent-browser"
else
    echo "⚠️ pnpm not available, skipping pnpm commands"
fi


if command -v npx >/dev/null 2>&1; then
    execute_as_user_setup "npx vibe-kanban" || echo "⚠️ Failed to run vibe-kanban"
else
    echo "⚠️ npx not available, skipping vibe-kanban"
fi

# Execute command as user
execute_as_user "$@"
