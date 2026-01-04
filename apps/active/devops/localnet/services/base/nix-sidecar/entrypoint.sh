#!/usr/bin/env bash
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-developer}

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    # Update group ID if needed
    if [ "$(id -g "$USERNAME")" != "$PGID" ]; then
        echo "Updating GID from $(id -g "$USERNAME") to $PGID"
        groupmod -o -g "$PGID" "$USERNAME"
    fi

    # Update user ID if needed
    if [ "$(id -u "$USERNAME")" != "$PUID" ]; then
        echo "Updating UID from $(id -u "$USERNAME") to $PUID"
        usermod -o -u "$PUID" "$USERNAME"
    fi

    # Fix permissions for home directory if it exists
    if [ -d "/home/$USERNAME" ]; then
        chown -R "$PUID:$PGID" "/home/$USERNAME"
    fi
fi

# Execute command as user
if command -v su-exec >/dev/null; then
    exec su-exec "$USERNAME" "$@"
else
    exec su "$USERNAME" -c "$*"
fi
