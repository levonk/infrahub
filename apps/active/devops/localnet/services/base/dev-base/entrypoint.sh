#!/bin/bash
set -e

# Ensure Nix binaries are in the PATH, searching multiple profile locations
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/root/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

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

    # Fix permissions for home directory
    if [ -d "/home/$USERNAME" ] && [ -n "$CHOWN" ]; then
        "$CHOWN" -R "$PUID:$PGID" "/home/$USERNAME"
    fi
fi

# Execute command as user
echo "🤖 Dev Base: Executing as $USERNAME: $@"
if [ -n "$GOSU" ]; then
    exec "$GOSU" "$USERNAME" "$@"
elif [ -n "$SU_EXEC" ]; then
    exec "$SU_EXEC" "$USERNAME" "$@"
else
    echo "❌ Dev Base: Error: No gosu or su-exec found. Cannot drop privileges."
    exit 1
fi
