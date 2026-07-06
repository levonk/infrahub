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

# Configure trusted users for Nix builds
echo "🤖 Dev Base: Configuring trusted users..."
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

# ponytail: `|| true` prevents set -e from killing the script when a tool
# is absent. Downstream code guards with [ -n "$VAR" ] so empty is safe.
SU_EXEC=$(find_tool su-exec || true)
GOSU=$(find_tool gosu || true)
SU=$(find_tool su || true)
ID=$(find_tool id || true)
GROUPMOD=$(find_tool groupmod || true)
USERMOD=$(find_tool usermod || true)
CHOWN=$(find_tool chown || true)

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
    elif [ -n "$SU" ]; then
        # ponytail: `su` fallback when gosu/su-exec are absent (base-kalinix
        # doesn't ship either). -s /bin/sh avoids the user's login shell.
        exec "$SU" "$USERNAME" -s /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" $*"
    else
        echo "❌ Dev Base: Error: No gosu, su-exec, or su found. Cannot drop privileges."
        exit 1
    fi
}

# Activate Devbox development environment if available
if [ -f "/home/$USERNAME/devbox.json" ] && command -v devbox >/dev/null 2>&1; then
    echo "🤖 Dev Base: Activating Devbox development environment..."
    cd "/home/$USERNAME"

    # Source the Nix profile to make devbox command available
    if [ -f "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "/home/$USERNAME/.nix-profile/etc/profile.d/nix.sh"
    fi

    # Install Devbox packages
    echo "🤖 Dev Base: Installing Devbox packages..."
    eval "$(NIX_SSL_CERT_FILE="$NIX_SSL_CERT_FILE" SSL_CERT_FILE="$SSL_CERT_FILE" CURL_CA_BUNDLE="$CURL_CA_BUNDLE" GIT_SSL_CAINFO="$GIT_SSL_CAINFO" devbox shell --print-env)"

    # Update PATH to include devbox environment
    export PATH="/home/$USERNAME/.nix-profile/bin:$PATH"
fi

# Function to execute commands inside Devbox environment
execute_as_user_in_devbox() {
    echo "🤖 Executing in Devbox environment as $USERNAME: $@"
    if [ -n "$GOSU" ]; then
        # Use shell -c to properly handle pipes and shell syntax
        # Pass SSL certificate environment variables to the user environment
        "$GOSU" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" devbox run -- $*"
    elif [ -n "$SU_EXEC" ]; then
        "$SU_EXEC" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" devbox run -- $*"
    elif [ -n "$SU" ]; then
        # ponytail: `su` fallback when gosu/su-exec are absent. `su` needs
        # a shell, so we wrap with -s /bin/sh -c. devbox run executes the
        # command inside the nix/devbox environment for the user.
        "$SU" "$USERNAME" -s /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" devbox run -- $*"
    else
        echo "❌ Dev Base: Error: No gosu, su-exec, or su found. Cannot drop privileges."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# CRITICAL PATH: omnigent CLI install + runner registration
# This must succeed for the container to serve its purpose. Everything below
# this block (optional dev tools) is non-fatal.
# ---------------------------------------------------------------------------
echo "🤖 Dev Base: Devbox development environment ready"

# ponytail: Install uv + omnigent CLI directly via nix/gosu, NOT via devbox.
# devbox run tries to install ALL 200+ packages in devbox.json, which is slow
# and fragile (comby fails nix evaluation). The critical path only needs uv
# to install the omnigent CLI. We install uv to the root nix profile (shared
# via volume), then use gosu to run uv as cuser.
if [ -n "$GOSU" ]; then
    # Ensure uv is available in the root nix profile
    if ! command -v uv >/dev/null 2>&1 && [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/uv" ]; then
        export PATH="/nix/var/nix/profiles/per-user/root/profile/bin:$PATH"
    fi
    if ! command -v uv >/dev/null 2>&1; then
        echo "🤖 Dev Base: Installing uv via nix profile..."
        nix profile install nixpkgs#uv --profile /nix/var/nix/profiles/per-user/root/profile 2>/dev/null || echo "⚠️ Failed to install uv via nix"
        export PATH="/nix/var/nix/profiles/per-user/root/profile/bin:$PATH"
    fi

    # Install omnigent CLI via uv tool (container-wide, available in all shells)
    # Version is unpinned because the runner must match the server — the server
    # negotiates the protocol on connect, so a stale runner just 409s and the
    # user re-runs this entrypoint or `uv tool upgrade omnigent`.
    if command -v uv >/dev/null 2>&1; then
        echo "🤖 Dev Base: Installing omnigent CLI via uv tool..."
        "$GOSU" "$USERNAME" /bin/sh -c "NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\" PATH=\"$PATH\" uv tool install omnigent" 2>&1 || { echo "⚠️ Failed to install omnigent CLI"; }
    else
        echo "⚠️ uv not available, cannot install omnigent CLI"
    fi

    # Register as Omnigent runner if OMNIGENT_SERVER_URL is set.
    # ponytail: headless login — `omni login` uses click.prompt for username +
    # password (no --username/--password flags). We pipe credentials via stdin
    # to avoid the interactive prompt. OMNIGENT_USERNAME and OMNIGENT_PASSWORD
    # are set by the Ansible playbook from vault.
    if [ -n "${OMNIGENT_SERVER_URL:-}" ]; then
        echo "🤖 Dev Base: Registering as Omnigent runner against ${OMNIGENT_SERVER_URL}..."
        # Find the omni binary (uv tool installs to ~/.local/bin)
        OMNI_BIN="/home/$USERNAME/.local/bin/omni"
        if [ -x "$OMNI_BIN" ]; then
            USER_PATH="$PATH:/home/$USERNAME/.local/bin:/home/$USERNAME/.bun/bin"
            SSL_ENV="NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\""
            if [ -n "${OMNIGENT_USERNAME:-}" ] && [ -n "${OMNIGENT_PASSWORD:-}" ]; then
                # Pipe username + password to omni login's click.prompt
                printf '%s\n%s\n' "${OMNIGENT_USERNAME}" "${OMNIGENT_PASSWORD}" | "$GOSU" "$USERNAME" /bin/sh -c "$SSL_ENV PATH=\"$USER_PATH\" omni login \"${OMNIGENT_SERVER_URL}\"" 2>&1 || { echo "⚠️ Failed to login to Omnigent server"; }
                # Register as host in the background — omni host stays connected
                # via WebSocket and blocks, so we background it with & and let
                # the entrypoint continue to devbox update + harness installs.
                "$GOSU" "$USERNAME" /bin/sh -c "$SSL_ENV PATH=\"$USER_PATH\" nohup omni host \"${OMNIGENT_SERVER_URL}\" > /tmp/omni-host.log 2>&1 &" 2>&1
                echo "🤖 Dev Base: omni host started in background (logs at /tmp/omni-host.log)"
            else
                "$GOSU" "$USERNAME" /bin/sh -c "$SSL_ENV PATH=\"$USER_PATH\" nohup omni login \"${OMNIGENT_SERVER_URL}\" && nohup omni host \"${OMNIGENT_SERVER_URL}\" > /tmp/omni-host.log 2>&1 &" 2>&1 || { echo "⚠️ Failed to register as Omnigent runner (interactive login may be needed)"; }
            fi
        else
            echo "⚠️ omni CLI not found at $OMNI_BIN, skipping registration"
        fi
    fi
else
    echo "⚠️ No gosu available, skipping omnigent CLI install + registration"
fi

# ---------------------------------------------------------------------------
# BACKGROUND: devbox update + harness CLI installs
# ponytail: devbox update fixes the legacy format warning and broken packages
# (e.g. comby fails nix evaluation). Runs in the background so the container
# is ready immediately; devbox packages become available as they install.
# Also installs bun (via nix) and the pi CLI (via bun install -g) so the
# pi-native harness shows as configured on the host. The omni host daemon
# was started with ~/.bun/bin on PATH above, so it finds pi once installed.
# ---------------------------------------------------------------------------
if [ -n "$GOSU" ] && [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/devbox" ]; then
    echo "🤖 Dev Base: Starting background devbox update + harness CLI installs..."
    (
        set +e
        NIX_BIN="/nix/var/nix/profiles/per-user/root/profile/bin"
        USER_PATH="$NIX_BIN:/home/$USERNAME/.local/bin:/home/$USERNAME/.bun/bin"
        SSL_ENV="NIX_SSL_CERT_FILE=\"$NIX_SSL_CERT_FILE\" SSL_CERT_FILE=\"$SSL_CERT_FILE\" CURL_CA_BUNDLE=\"$CURL_CA_BUNDLE\" GIT_SSL_CAINFO=\"$GIT_SSL_CAINFO\""

        # devbox update: migrates legacy format + repairs broken package refs.
        # ponytail: run as root because cuser can't access /nix/var/nix/db/big-lock
        # (the nix daemon db). devbox update only rewrites devbox.json — it
        # doesn't install packages, so root is fine.
        "$GOSU" root /bin/sh -c "$SSL_ENV PATH=\"$USER_PATH\" devbox update --quiet" > /tmp/devbox-update.log 2>&1
        DEVBX_UPD_RC=$?
        if [ $DEVBX_UPD_RC -eq 0 ]; then
            echo "✅ devbox update completed (background)" | tee -a /tmp/devbox-update.log
        else
            echo "⚠️ devbox update failed (rc=$DEVBX_UPD_RC) — see /tmp/devbox-update.log" | tee -a /tmp/devbox-update.log
        fi

        # Install bun via nix profile (needed for npm-package-based harness CLIs)
        if ! [ -x "$NIX_BIN/bun" ]; then
            echo "🤖 Dev Base: Installing bun via nix profile (background)..." >> /tmp/devbox-update.log 2>&1
            nix profile install nixpkgs#bun --profile /nix/var/nix/profiles/per-user/root/profile >> /tmp/devbox-update.log 2>&1
        fi

        # Install pi CLI via bun (enables pi-native harness on this host)
        if [ -x "$NIX_BIN/bun" ]; then
            if ! [ -x "/home/$USERNAME/.bun/bin/pi" ] && ! command -v pi >/dev/null 2>&1; then
                echo "🤖 Dev Base: Installing pi CLI via bun (background)..." >> /tmp/devbox-update.log 2>&1
                BUN_INSTALL="/home/$USERNAME/.bun"
                mkdir -p "$BUN_INSTALL/bin"
                chown -R "$USERNAME:$USERNAME" "$BUN_INSTALL"
                "$GOSU" "$USERNAME" /bin/sh -c "$SSL_ENV PATH=\"$USER_PATH\" BUN_INSTALL=\"$BUN_INSTALL\" bun install -g @earendil-works/pi-coding-agent" >> /tmp/devbox-update.log 2>&1
                if [ $? -eq 0 ] && [ -x "/home/$USERNAME/.bun/bin/pi" ]; then
                    echo "✅ pi CLI installed (background)" | tee -a /tmp/devbox-update.log
                else
                    echo "⚠️ pi CLI install failed — see /tmp/devbox-update.log" | tee -a /tmp/devbox-update.log
                fi
            else
                echo "✅ pi CLI already available" >> /tmp/devbox-update.log 2>&1
            fi
        else
            echo "⚠️ bun not available, cannot install pi CLI" >> /tmp/devbox-update.log 2>&1
        fi

        echo "🤖 Dev Base: Background devbox update + harness installs complete" >> /tmp/devbox-update.log 2>&1
    ) &
    echo "🤖 Dev Base: Background task started (PID $!), logs at /tmp/devbox-update.log"
else
    echo "⚠️ devbox not available, skipping background devbox update + harness installs"
fi

# ---------------------------------------------------------------------------
# OPTIONAL DEV TOOLS: factory.ai, pnpm packages, cargo packages, etc.
# Wrapped in a subshell with set +e so any failure exits only the subshell,
# not the container. The container stays up even if every optional tool fails.
# ---------------------------------------------------------------------------
(
    set +e
    echo "🤖 Dev Base: Installing optional dev tools (non-fatal)..."

    # curl check
    execute_as_user_in_devbox "which curl" >/dev/null 2>&1 || { echo "⚠️ curl not available, skipping network installs"; exit 0; }

    # factory.ai CLI
    if execute_as_user_in_devbox "curl --connect-timeout 10 -fsSL https://app.factory.ai/cli | sh" 2>/dev/null; then
        echo "✅ app.factory.ai CLI installed successfully"
    else
        echo "⚠️ Failed to install app.factory.ai CLI"
    fi

    # agent-deck
    if execute_as_user_in_devbox "curl -fsSL https://raw.githubusercontent.com/asheshgoplani/agent-deck/main/install.sh | bash" 2>/dev/null; then
        echo "✅ agent-deck installed successfully"
    else
        echo "⚠️ Failed to install agent-deck"
    fi

    # pnpm packages
    if execute_as_user_in_devbox "which pnpm" >/dev/null 2>&1; then
        execute_as_user_in_devbox "pnpm setup" 2>/dev/null
        for pkg in @beads/bd openskills agent-browser @tobilu/qmd @twsxtd/hapi portless turbo yarn bun zerobox; do
            execute_as_user_in_devbox "pnpm install -g $pkg" 2>/dev/null && echo "✅ $pkg" || echo "⚠️ $pkg failed"
        done
    else
        echo "⚠️ pnpm not available, skipping npm global installs"
    fi

    # shadcn components
    if execute_as_user_in_devbox "which npx" >/dev/null 2>&1; then
        execute_as_user_in_devbox "npx shadcn add https://soundcn.xyz/r/click-soft.json" 2>/dev/null || echo "⚠️ soundcn failed"
        execute_as_user_in_devbox "npx shadcn@latest add https://goey-toast.vercel.app/r/goey-toaster.json" 2>/dev/null || echo "⚠️ goey-toast failed"
    fi

    # Python packages via uv
    if execute_as_user_in_devbox "which uv" >/dev/null 2>&1; then
        for pkg in llm-tldr memsearch git_bayesect; do
            execute_as_user_in_devbox "uv pip install --system $pkg" 2>/dev/null && echo "✅ $pkg" || echo "⚠️ $pkg failed"
        done
    else
        echo "⚠️ uv not available, skipping Python packages"
    fi

    # Cargo packages
    if execute_as_user_in_devbox "which cargo" >/dev/null 2>&1; then
        execute_as_user_in_devbox "cargo install worktrunk" 2>/dev/null && echo "✅ worktrunk" || echo "⚠️ worktrunk failed"
        execute_as_user_in_devbox "cargo install --git https://github.com/rtk-ai/rtk" 2>/dev/null && echo "✅ rtk" || echo "⚠️ rtk failed"
    else
        echo "⚠️ cargo not available, skipping Rust packages"
    fi

    # gh-dash plugin
    execute_as_user_in_devbox "gh extension install dlvhdr/gh-dash" >/dev/null 2>&1 || echo "⚠️ gh-dash failed"

    # llm-tldr warm/context
    execute_as_user_in_devbox "cd /home/$USERNAME/work 2>/dev/null && tldr warm . && tldr context main --project ." 2>/dev/null || echo "⚠️ llm-tldr warm/context failed"

    echo "🤖 Dev Base: Optional dev tools phase complete"
) || echo "⚠️ Some optional dev tools failed to install (non-fatal)"

# ---------------------------------------------------------------------------
# Keep container running
# ---------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    echo "🤖 Dev Base: No command provided, sleeping indefinitely..."
    echo "🤖 Dev Base: Container will wait for manual intervention"
    # Sleep indefinitely to keep container running
    while true; do
        devbox run  -- sleep 3600
    done
else
    execute_as_user "$@"
fi
