#!/usr/bin/env bash
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Nix Sidecar: Starting entrypoint..."

echo "🤖 Nix Sidecar: Update nix.conf after bind mount"
if [ -r /templates/etc/nix/nix.conf ]; then
    cp /templates/etc/nix/nix.conf /etc/nix/nix.conf
fi

# Add trusted users to nix.conf for container builds
echo "🤖 Nix Sidecar: Configuring trusted users dynamically..."
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
echo "🤖 Nix Sidecar: Checking to see if /nix needs initialization..."
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

# Ensure 'nix' and basic tools are installed in the root profile so they are available in PATH
# We use the root profile as the shared source for base tools
echo "🤖 Nix Sidecar: Installing core tools to root profile..."

# First check if core tools are already available to avoid unnecessary downloads
# Use faster verification - only check if core tools are available in root profile
echo "🤖 Nix Sidecar: Checking for core tools in root profile..."
if [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/nix" ] && \
   [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/bash" ] && \
   [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/git" ] && \
   [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/jq" ] && \
   /nix/var/nix/profiles/per-user/root/profile/bin/nix --version >/dev/null 2>&1; then
    echo "✅ Core tools available in root profile, skipping package installation"
else
    echo "🔧 Core tools missing from root profile, installing packages..."
    # Use --priority to avoid conflicts if packages are already present (though unlikely in fresh profile)
    # Add timeout to prevent hanging - increased for large nixpkgs downloads
    #timeout 180 nix profile install nixpkgs#nix nixpkgs#bash nixpkgs#coreutils nixpkgs#git nixpkgs#jq --profile /nix/var/nix/profiles/per-user/root/profile --priority 10 || {
    nix profile install nixpkgs#nix nixpkgs#bash nixpkgs#coreutils nixpkgs#git nixpkgs#jq --profile /nix/var/nix/profiles/per-user/root/profile --priority 10 || {
        echo "⚠️ Warning: Core tools installation timed out or failed, continuing with available tools..."
    }
fi


# Install required packages for user management (after volumes are mounted)
echo "🤖 Nix Sidecar: Installing required packages from flake.nix..."
# Clear any invalid Nix settings that might cause warnings
unset NIX_CONFIG 2>/dev/null || true

# Source nix profile if it exists
if [ -f "/etc/profile.d/nix.sh" ]; then
    . /etc/profile.d/nix.sh
fi

if [ -f "/nix-sidecar/flake.nix" ]; then
    # Find and set SSL certificate paths for HTTPS to work with Nix
    echo "🤖 Nix Sidecar: Setting up SSL certificates..."
    # First try system certificates (faster and more reliable), then fall back to Nix store
    CACERT_PATH=""
    if [ -f "/etc/ssl/certs/ca-bundle.crt" ]; then
        CACERT_PATH="/etc/ssl/certs/ca-bundle.crt"
        echo "🤖 Nix Sidecar: Using system CA certificates at $CACERT_PATH"
    else
        # Only search Nix store if system certs aren't available
        CACERT_PATH=$(timeout 30 nix develop /nix-sidecar --command find /nix/store -name "ca-bundle.crt" -path "*/etc/ssl/certs/*" 2>/dev/null | head -1)
        if [ -n "$CACERT_PATH" ]; then
            echo "🤖 Nix Sidecar: Found Nix store CA certificates at $CACERT_PATH"
        fi
    fi
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
        echo "⚠️ Warning: Failed to install packages from flake.nix, continuing with available tools..."
    }
    echo "✅ Nix Sidecar: Packages installed successfully from flake"
else
    echo "❌ Nix Sidecar: flake.nix not found at /nix-sidecar/flake.nix"
    exit 1
fi

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

# Create base sudoers file if it doesn't exist (not needed for gosu)
# gosu is used instead of sudo for privilege escalation
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
    echo "🤖 Nix Sidecar: Setting up user Nix profile..."
    # Create user profile directory if it doesn't exist
    mkdir -p "/nix/var/nix/profiles/per-user/$USERNAME"

    # Create .nix-profile symlink in user's home directory if home directory exists
    if [ -d "/home/$USERNAME" ]; then
        if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
            ln -sf /nix/var/nix/profiles/per-user/"$USERNAME"/profile "/home/$USERNAME/.nix-profile"
            chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
        fi
    fi

    # Set up nixbld group and users for multi-user Nix (REQUIRED for multi-user Nix)
    echo "🤖 Nix Sidecar: Setting up nixbld group and users..."

    # Create nixbld group with GID 30000 if it doesn't exist
    if ! grep -q "^nixbld:" /etc/group 2>/dev/null; then
        echo "🤖 Nix Sidecar: Creating nixbld group (GID: 30000)..."
        echo "nixbld:x:30000:" >> /etc/group
        echo "✅ nixbld group created with GID 30000"
    else
        echo "✅ nixbld group already exists"
    fi

    # Create nixbld users (nixbld1 through nixbld32)
    for i in $(seq 1 32); do
        if ! grep -q "^nixbld$i:" /etc/passwd 2>/dev/null; then
            echo "🤖 Nix Sidecar: Creating nixbld$i user..."
            echo "nixbld$i:x:$i:30000:30000::/usr/sbin/nologin:nixbld$i" >> /etc/passwd
            echo "✅ nixbld$i user created"
        fi
    done

    # Set correct permissions on /nix/store for multi-user Nix (group-writable by nixbld)
    if [ -d "/nix/store" ]; then
        echo "🤖 Nix Sidecar: Setting /nix/store permissions for multi-user Nix..."
        chown root:nixbld /nix/store
        chmod 2775 /nix/store
        echo "✅ /nix/store permissions set to root:nixbld 2775"
    fi

    # Set correct permissions on /nix/var for multi-user Nix
    if [ -d "/nix/var" ]; then
        echo "🤖 Nix Sidecar: Setting /nix/var permissions for multi-user Nix..."
        chown root:root /nix/var
        chmod 755 /nix/var
        echo "✅ /nix/var permissions set to root:root 755"
    fi
fi

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
	# Run supercronic within nix develop environment as root since it needs to execute Nix store operations
	# The individual cron jobs will handle user switching if needed
	exec nix develop /nix-sidecar --command supercronic /nix-sidecar/supercronic-nix-sidecar.crond
fi
