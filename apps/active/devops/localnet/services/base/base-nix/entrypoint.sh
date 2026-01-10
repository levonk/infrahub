#!/bin/sh
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Base Nix: Starting entrypoint..."

# Function to verify Nix environment
verify_nix() {
    echo "🤖 Base Nix: Verifying Nix environment..."
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
    echo "🤖 Base Nix: Initializing Nix environment from backup tarball..."
    if [ -f "/nix-init/bootstrap.tar" ]; then
        echo "🤖 Base Nix: Restoring from /nix-init/bootstrap.tar..."
        tar -C / -xf /nix-init/bootstrap.tar
        echo "🤖 Base Nix: Nix environment initialized."
    else
        echo "❌ Base Nix: Error: /nix-init/bootstrap.tar is missing. Cannot initialize Nix."
        exit 1
    fi
fi

# Ensure Nix binaries are in the PATH
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set up profiles and channels if missing
mkdir -p /nix/var/nix/profiles/per-user/root
if [ ! -L "/root/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/root/profile /root/.nix-profile
fi

# Ensure default profile link exists in the shared volume if it was lost
if [ ! -L "/nix/var/nix/profiles/default" ]; then
    ln -sf /nix/var/nix/profiles/per-user/root/profile /nix/var/nix/profiles/default
fi

# User management
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "🤖 Base Nix: Creating user $USERNAME (UID: $PUID, GID: $PGID)"
    addgroup -g "$PGID" "$USERNAME" || true
    mkdir -p "/home/$USERNAME"
    adduser -u "$PUID" -G "$USERNAME" -D -s /bin/bash "$USERNAME"
    chown -R "$PUID:$PGID" "/home/$USERNAME"
else
    echo "🤖 Base Nix: Configuring user $USERNAME (UID: $PUID, GID: $PGID)"
    CUR_UID=$(id -u "$USERNAME")
    CUR_GID=$(id -g "$USERNAME")

    if [ "$CUR_GID" != "$PGID" ]; then
        groupmod -o -g "$PGID" "$USERNAME" || echo "⚠️ groupmod failed"
    fi
    if [ "$CUR_UID" != "$PUID" ]; then
        usermod -o -u "$PUID" "$USERNAME" || echo "⚠️ usermod failed"
    fi

    if [ -d "/home/$USERNAME" ]; then
        chown -R "$PUID:$PGID" "/home/$USERNAME"
    fi
fi

# Set up user Nix profile
mkdir -p /nix/var/nix/profiles/per-user/"$USERNAME"
chown -R "$PUID:$PGID" /nix/var/nix/profiles/per-user/"$USERNAME"
if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
    ln -sf /nix/var/nix/profiles/per-user/"$USERNAME"/profile "/home/$USERNAME/.nix-profile"
    chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
fi

verify_nix

echo "🤖 Base Nix: Ready."

# Execute command or sleep
if [ "$#" -gt 0 ]; then
    echo "🤖 Base Nix: Executing command: $@"
    if command -v su-exec >/dev/null 2>&1; then
        exec su-exec "$USERNAME" "$@"
    elif command -v gosu >/dev/null 2>&1; then
        exec gosu "$USERNAME" "$@"
    else
        echo "❌ Base Nix: Error: No su-exec or gosu found. Cannot drop privileges per ADR-20260106001."
        exit 1
    fi
else
    echo "🤖 Base Nix: Entering wait loop."
    exec sleep 60
fi
