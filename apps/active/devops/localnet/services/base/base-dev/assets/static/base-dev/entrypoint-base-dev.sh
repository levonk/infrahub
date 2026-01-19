#!/bin/bash
set -e

# Ensure Nix binaries are in the PATH, searching multiple profile locations
# Include user's nix profile in PATH
export PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/root/profile/bin:/home/${USERNAME}/.nix-profile/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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

    # Fix permissions for home directory
    if [ -d "/home/$USERNAME" ] && [ -n "$CHOWN" ]; then
        "$CHOWN" -R "$PUID:$PGID" "/home/$USERNAME"
    fi

    # Ensure Nix profile is linked
    if [ -d "/nix/var/nix/profiles/per-user/$USERNAME/profile" ]; then
        if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
            echo "🤖 Dev Base: Linking Nix profile..."
            ln -sf "/nix/var/nix/profiles/per-user/$USERNAME/profile" "/home/$USERNAME/.nix-profile"
            if [ -n "$CHOWN" ]; then
                "$CHOWN" -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile"
            fi
        fi
    else
        echo "⚠️ Dev Base: Nix profile for $USERNAME not found in /nix/var/nix/profiles/per-user/"
        echo "   (This is normal if nix-sidecar hasn't finished setup yet)"
    fi
fi

# Function to execute command as user
execute_as_user() {
    echo "🤖 Dev Base: Executing as $USERNAME: $@"
    echo "🤖 Dev Base: PATH is $PATH"
    if [ -n "$GOSU" ]; then
        # Verify command availability for user
        if ! "$GOSU" "$USERNAME" which "$(echo "$@" | awk '{print $1}')" 2>/dev/null; then
            echo "⚠️ Command not found in user PATH, skipping..."
            return 0
        fi
        exec "$GOSU" "$USERNAME" "$@"
    elif [ -n "$SU_EXEC" ]; then
        exec "$SU_EXEC" "$USERNAME" "$@"
    else
        echo "❌ Dev Base: Error: No gosu or su-exec found. Cannot drop privileges."
        exit 1
    fi
}

# Optional setup commands - these may fail if tools aren't available
echo "🤖 Dev Base: Running optional setup commands..."
if command -v curl >/dev/null 2>&1; then
    execute_as_user "curl -fsSL https://app.factory.ai/cli | sh" || echo "⚠️ Failed to install app.factory.ai CLI"
else
    echo "⚠️ curl not available, skipping app.factory.ai CLI installation"
fi

if command -v uv >/dev/null 2>&1; then
    execute_as_user "uv install llm-tldr"
    execute_as_user "cd /home/$USERNAME/work; tldr warm . && tldr context main --project ." || echo "⚠️ Failed to run llm-tldr commands"
else
    echo "⚠️ uv not available, skipping llm-tldr commands"
fi

if command -v pnpm >/dev/null 2>&1; then
    execute_as_user "pnpm install -g @beads/bd" || echo "⚠️ Failed to run pnpm install -g @beads/bd"
    execute_as_user "pnpm install -g openskills" || echo "⚠️ Failed to run pnpm install -g openskills"
    execute_as_user "pnpm install -g agent-browser" || echo "⚠️ Failed to run pnpm install -g agent-browser"
else
    echo "⚠️ pnpm not available, skipping pnpm commands"
fi


if command -v npx >/dev/null 2>&1; then
    execute_as_user "npx vibe-kanban" || echo "⚠️ Failed to run vibe-kanban"
else
    echo "⚠️ npx not available, skipping vibe-kanban"
fi

# Execute command as user
execute_as_user "$@"
