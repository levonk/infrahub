#!/bin/bash
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=appuser

# Check if user exists
if id "$USERNAME" >/dev/null 2>&1; then
    # Update group ID if needed
    CUR_GID=$(id -g "$USERNAME")
    if [ "$CUR_GID" != "$PGID" ]; then
        echo "Updating GID from $CUR_GID to $PGID"
        groupmod -o -g "$PGID" "$USERNAME"
    fi

    # Update user ID if needed
    CUR_UID=$(id -u "$USERNAME")
    if [ "$CUR_UID" != "$PUID" ]; then
        echo "Updating UID from $CUR_UID to $PUID"
        usermod -o -u "$PUID" "$USERNAME"
    fi

    # Fix permissions for home directory
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
