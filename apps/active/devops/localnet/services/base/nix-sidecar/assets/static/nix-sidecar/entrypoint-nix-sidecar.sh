#!/bin/sh
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Nix Sidecar: Starting entrypoint..."

# Function to verify Nix environment
verify_nix() {
    echo "🤖 Nix Sidecar: Verifying Nix environment..."
    if [ -x /bin/nix ] || [ -x /usr/local/bin/nix ] || command -v nix >/dev/null 2>&1; then
        echo "✅ nix binary found"
        [ -f /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
        nix --version || echo "⚠️ nix --version failed"
    else
        echo "❌ nix binary missing"
    fi

    if [ -d /nix/store ]; then
        echo "✅ /nix/store exists ($(ls -A /nix/store 2>/dev/null | wc -l) items)"
    else
        echo "❌ /nix/store missing"
    fi
}

# Check if Nix environment needs initialization
if [ ! -d "/nix/store" ] || [ -z "$(ls -A /nix/store 2>/dev/null)" ]; then
    echo "🤖 Nix Sidecar: Initializing Nix environment from backup tarball..."
    if [ -f "/nix-sidecar/tmp/bootstrap-slash-nix.tar" ]; then
        echo "🤖 Nix Sidecar: Restoring from /nix-sidecar/tmp/bootstrap-slash-nix.tar..."
        tar -C / -xf /nix-sidecar/tmp/bootstrap-slash-nix.tar
        echo "🤖 Nix Sidecar: Nix environment initialized."
    else
        echo "❌ Nix Sidecar: Error: /nix-sidecar/tmp/bootstrap-slash-nix.tar is missing. Cannot initialize Nix."
        exit 1
    fi
fi

# Install required packages for user management (after volumes are mounted)
echo "🤖 Nix Sidecar: Installing required packages from flake.nix..."
# Clear any invalid Nix settings that might cause warnings
unset NIX_CONFIG 2>/dev/null || true
if [ -f "/nix-sidecar/flake.nix" ]; then
    # Find and set SSL certificate paths for HTTPS to work with Nix
    echo "🤖 Nix Sidecar: Setting up SSL certificates..."
    CACERT_PATH=$(nix develop /nix-sidecar --command find /nix/store -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1)
    if [ -n "$CACERT_PATH" ] && [ -f "$CACERT_PATH" ]; then
        echo "🤖 Nix Sidecar: Found CA certificates at $CACERT_PATH"
        export NIX_SSL_CERT_FILE="$CACERT_PATH"
        export SSL_CERT_FILE="$CACERT_PATH"
        export CURL_CA_BUNDLE="$CACERT_PATH"
        export GIT_SSL_CAINFO="$CACERT_PATH"
        echo "✅ SSL certificate environment variables set"
    else
        echo "⚠️ Warning: Could not find CA certificates, HTTPS may not work properly"
    fi

    nix develop /nix-sidecar --command echo "Packages installed successfully" || {
        echo "❌ Nix Sidecar: Failed to install packages from flake.nix"
        exit 1
    }
    echo "✅ Nix Sidecar: Packages installed successfully from flake"
else
    echo "❌ Nix Sidecar: flake.nix not found at /nix-sidecar/flake.nix"
    exit 1
fi

# Ensure 'nix' and basic tools are installed in the root profile so they are available in PATH
# We use the root profile as the shared source for base tools
echo "🤖 Nix Sidecar: Installing core tools to root profile..."
# Use --priority to avoid conflicts if packages are already present (though unlikely in fresh profile)
nix profile install nixpkgs#nix nixpkgs#bash nixpkgs#coreutils nixpkgs#git nixpkgs#jq --profile /nix/var/nix/profiles/per-user/root/profile --priority 10

# Ensure Nix binaries are in the PATH
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set up profiles and channels if missing (fix permissions first)
echo "🤖 Nix Sidecar: Setting up Nix profiles directory..."
mkdir -p /nix/var/nix/profiles/per-user
chmod 755 /nix/var/nix/profiles/per-user

# Create root profile
mkdir -p /nix/var/nix/profiles/per-user/root
if [ ! -L "/root/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/root/profile /root/.nix-profile
fi

# User management (run within flake environment to have access to shadow tools)
echo "🤖 Nix Sidecar: Setting up user management..."
nix develop /nix-sidecar --command sh -c "
if ! id \"$USERNAME\" >/dev/null 2>&1; then
    echo \"🤖 Nix Sidecar: Creating user $USERNAME (UID: $PUID, GID: $PGID)\"
    groupadd -g \"$PGID\" \"$USERNAME\" || true
    mkdir -p \"/home/$USERNAME\"
    useradd -u \"$PUID\" -g \"$PGID\" -d \"/home/$USERNAME\" -s /bin/sh \"$USERNAME\"
    chown -R \"$PUID:$PGID\" \"/home/$USERNAME\"
else
    echo \"🤖 Nix Sidecar: Configuring user $USERNAME (UID: $PUID, GID: $PGID)\"
    CUR_UID=\$(id -u \"$USERNAME\")
    CUR_GID=\$(id -g \"$USERNAME\")

    if [ \"\$CUR_GID\" != \"$PGID\" ]; then
        groupmod -o -g \"$PGID\" \"$USERNAME\" || echo \"⚠️ groupmod failed\"
    fi
    if [ \"\$CUR_UID\" != \"$PUID\" ]; then
        usermod -o -u \"$PUID\" \"$USERNAME\" || echo \"⚠️ usermod failed\"
    fi
fi
"
if [ -d "/home/$USERNAME" ]; then
    chown -R "$PUID:$PGID" "/home/$USERNAME"
fi

# Set up user Nix profile
echo "🤖 Nix Sidecar: Setting up user Nix profile..."
mkdir -p /nix/var/nix/profiles/per-user/"$USERNAME"
# Ensure parent directory has correct permissions first
chmod 755 /nix/var/nix/profiles/per-user
# Set ownership of user's profile directory
chown -R "$PUID:$PGID" /nix/var/nix/profiles/per-user/"$USERNAME"
# Ensure the parent directory is also accessible by the user
chown "$PUID:$PGID" /nix/var/nix/profiles/per-user

# Link user profile to root profile if empty so they share tools
if [ ! -e /nix/var/nix/profiles/per-user/"$USERNAME"/profile ]; then
    echo "🤖 Nix Sidecar: Linking $USERNAME profile to root profile..."
    ln -sf /nix/var/nix/profiles/per-user/root/profile /nix/var/nix/profiles/per-user/"$USERNAME"/profile
fi

if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/"$USERNAME"/profile "/home/$USERNAME/.nix-profile"
    chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
fi

verify_nix

# Function to execute command as non-root user
exec_as_user() {
    local cmd="$1"
    echo "🤖 Nix Sidecar: Executing as user $USERNAME: $cmd"
    # Always run within nix develop environment for consistent PATH and dependencies
    nix develop /nix-sidecar --command sh -c "
    if command -v gosu >/dev/null 2>&1; then
        exec gosu \"$USERNAME\" $cmd
    elif command -v su-exec >/dev/null 2>&1; then
        exec su-exec \"$USERNAME\" $cmd
    else
        exec su \"$USERNAME\" -s /bin/sh -c \"$cmd\"
    fi
    "
}

echo "🤖 Nix Sidecar: Ready."

# Execute command or run supercronic as main process
if [ "$#" -gt 0 ]; then
	echo "🤖 Nix Sidecar: Executing command: $@"
    exec_as_user "$@"
else
	echo "🤖 Nix Sidecar: Starting scheduled tasks with supercronic as main process..."
    # Run supercronic - exec_as_user will handle the nix develop wrapper
    exec_as_user "supercronic /nix-sidecar/supercronic-nix-sidecar.crond"
fi
