#!/usr/bin/env bash
set -e

# Function to add path to PATH only if it's not already present
add_to_path_if_missing() {
    local path_to_add="$1"
    if [[ ":$PATH:" != *":$path_to_add:"* ]]; then
        export PATH="$path_to_add:$PATH"
        echo "🤖 Nix Sidecar: Added to PATH: $path_to_add"
    else
        echo "🤖 Nix Sidecar: Path already in PATH: $path_to_add"
    fi
}

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USERNAME=${USERNAME:-cuser}

echo "🤖 Nix Sidecar: Starting entrypoint..."

# STEP 1: Initialize Nix environment FIRST - must happen before using any nix commands
# Check if Nix environment needs initialization
echo "🤖 Nix Sidecar: Checking if /nix needs initialization..."
if [ ! -d "/nix/store" ] || [ -z "$(ls -A /nix/store 2>/dev/null)" ]; then
    echo "🤖 Nix Sidecar: Fresh volume mount, initializing Nix environment from backup tarball..."
    if [ -f "/nix-sidecar/tmp/bootstrap-slash-nix.tar" ]; then
        echo "🤖 Nix Sidecar: Restoring from /nix-sidecar/tmp/bootstrap-slash-nix.tar..."
        # Try different tar locations - busybox tar or standalone tar
        if [ -x "/bin/tar" ]; then
            /bin/tar -C / -xf /nix-sidecar/tmp/bootstrap-slash-nix.tar
        elif command -v tar >/dev/null 2>&1; then
            tar -C / -xf /nix-sidecar/tmp/bootstrap-slash-nix.tar
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox tar -C / -xf /nix-sidecar/tmp/bootstrap-slash-nix.tar
        else
            echo "❌ Nix Sidecar: Error: tar command not found. Cannot extract bootstrap archive."
            exit 1
        fi
        echo "🤖 Nix Sidecar: Nix environment initialized."
    else
        echo "❌ Nix Sidecar: Error: /nix-sidecar/tmp/bootstrap-slash-nix.tar is missing. Cannot initialize Nix."
        exit 1
    fi
else
    echo "🤖 Nix Sidecar: /nix/store already exists, skipping initialization"
fi

# STEP 2: Source nix environment now that nix is available
if [ -f /etc/profile.d/nix.sh ]; then
    echo "🤖 Nix Sidecar: Sourcing nix environment..."
    . /etc/profile.d/nix.sh
fi

# Also add common nix locations to PATH just in case (only if not already present)
add_to_path_if_missing "/nix/var/nix/profiles/default/bin"
add_to_path_if_missing "/root/.nix-profile/bin"

# STEP 3: Install coreutils immediately so we have working cp, cat, etc.
echo "🤖 Nix Sidecar: Checking for coreutils availability..."
if command -v cp >/dev/null 2>&1 && command -v cat >/dev/null 2>&1; then
    echo "✅ Coreutils already available, skipping installation"
else
    echo "🤖 Nix Sidecar: Installing coreutils via nix..."
    if command -v nix >/dev/null 2>&1; then
        # Install coreutils to a profile that will be in PATH
        echo "🤖 Nix Sidecar: Running nix profile install..."
        nix profile install nixpkgs#coreutils --profile /nix/var/nix/profiles/per-user/root/profile || echo "⚠️ nix profile install exited with code $?"
        # Export PATH to include the newly installed tools FIRST
        add_to_path_if_missing "/nix/var/nix/profiles/per-user/root/profile/bin"
        echo "🤖 Nix Sidecar: PATH set to: $PATH"
        # Debug: check if cp exists in the profile
        if [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/cp" ]; then
            echo "✅ cp found in nix profile"
            ls -la /nix/var/nix/profiles/per-user/root/profile/bin/cp
        else
            echo "❌ cp NOT found in nix profile at /nix/var/nix/profiles/per-user/root/profile/bin/cp"
            ls -la /nix/var/nix/profiles/per-user/root/profile/bin/ 2>/dev/null || echo "Directory doesn't exist or is empty"
        fi
    else
        echo "❌ nix command not available, cannot install coreutils"
        exit 1
    fi
fi

# Verify coreutils are available
echo "🤖 Nix Sidecar: Verifying core tools..."
if ! command -v cp >/dev/null 2>&1; then
    echo "❌ cp not available after coreutils install"
    exit 1
fi
if ! command -v cat >/dev/null 2>&1; then
    echo "❌ cat not available after coreutils install"
    exit 1
fi
echo "✅ Coreutils available"

echo "🤖 Nix Sidecar: Update nix.conf after bind mount"
if [ -r /templates/etc/nix/nix.conf ]; then
    if command -v cp >/dev/null 2>&1; then
        cp /templates/etc/nix/nix.conf /etc/nix/nix.conf
    elif command -v cat >/dev/null 2>&1; then
        cat /templates/etc/nix/nix.conf > /etc/nix/nix.conf
    else
        echo "⚠️ Warning: Cannot copy nix.conf - cp and cat not available"
    fi
fi

# STEP 4: Install ripgrep for fast text searching (after nix.conf is configured)
echo "🤖 Nix Sidecar: Checking for ripgrep availability..."
if command -v rg >/dev/null 2>&1; then
    echo "✅ ripgrep already available, skipping installation"
else
    echo "🤖 Nix Sidecar: Installing ripgrep via nix..."
    if command -v nix >/dev/null 2>&1; then
        # Install ripgrep to the same profile as coreutils
        echo "🤖 Nix Sidecar: Running nix profile install for ripgrep..."
        nix profile add nixpkgs#ripgrep --profile /nix/var/nix/profiles/per-user/root/profile || echo "⚠️ ripgrep installation exited with code $?"
        # Ensure PATH includes the profile (should already be there from coreutils)
        add_to_path_if_missing "/nix/var/nix/profiles/per-user/root/profile/bin"
        echo "🤖 Nix Sidecar: PATH set to: $PATH"
        # Debug: check if rg exists in the profile
        if [ -x "/nix/var/nix/profiles/per-user/root/profile/bin/rg" ]; then
            echo "✅ ripgrep found in nix profile"
        else
            echo "⚠️ ripgrep NOT found in nix profile, installation may have failed"
        fi
    else
        echo "❌ nix command not available, cannot install ripgrep"
    fi
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

    # Check if specific trusted users are already configured in nix.conf before appending
    if command -v rg >/dev/null 2>&1 && [ -f /etc/nix/nix.conf ]; then
        # Check if all our required users are already in the trusted-users line
        missing_users=""
        for user in $TRUSTED_USERS; do
            if ! rg "^trusted-users\s*=.*\b$user\b" /etc/nix/nix.conf >/dev/null 2>&1; then
                missing_users="$missing_users $user"
            fi
        done
        
        if [ -z "$missing_users" ]; then
            echo "✅ All required trusted users already configured in nix.conf, skipping"
        else
            echo "🤖 Nix Sidecar: Adding missing trusted users:$missing_users"
            echo "trusted-users = $TRUSTED_USERS" >> /etc/nix/nix.conf
            echo "✅ Configured trusted-users dynamically: $TRUSTED_USERS"
        fi
    else
        # Fallback: Simply append to nix.conf if ripgrep not available
        echo "trusted-users = $TRUSTED_USERS" >> /etc/nix/nix.conf
        echo "✅ Configured trusted-users dynamically: $TRUSTED_USERS"
    fi
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
# (Already initialized at the beginning of this script, but check again in case)
if [ ! -d "/nix/store" ] || [ -z "$(ls -A /nix/store 2>/dev/null)" ]; then
    echo "❌ Nix Sidecar: Error: /nix/store is empty after initialization. This should not happen."
    exit 1
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

    # TODO: Re-enable nix develop command once container is stable
    echo "🤖 Nix Sidecar: Skipping nix develop for now to ensure container stability"
    echo "✅ Nix Sidecar: Basic setup completed"
    #nix develop /nix-sidecar --command echo "Packages installed successfully" || {
        #echo "⚠️ Warning: Failed to install packages from flake.nix, continuing with available tools..."
    #}
    #echo "✅ Nix Sidecar: Packages installed successfully from flake"
else
    echo "❌ Nix Sidecar: flake.nix not found at /nix-sidecar/flake.nix"
    exit 1
fi

# Ensure Nix binaries are in the PATH
export PATH="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set up profiles and channels if missing (fix permissions first)
echo "🤖 Nix Sidecar: Setting up Nix profiles directory..."
# Use busybox mkdir if available, otherwise try mkdir
if command -v mkdir >/dev/null 2>&1; then
    mkdir -p /nix/var/nix/profiles/per-user
elif [ -x "/bin/busybox" ]; then
    /bin/busybox mkdir -p /nix/var/nix/profiles/per-user
else
    echo "❌ Nix Sidecar: Error: mkdir command not found. Cannot create profiles directory."
    exit 1
fi
# Use busybox chmod if available, otherwise try chmod
if command -v chmod >/dev/null 2>&1; then
    chmod 755 /nix/var/nix/profiles/per-user
elif [ -x "/bin/busybox" ]; then
    /bin/busybox chmod 755 /nix/var/nix/profiles/per-user
else
    echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set permissions."
    exit 1
fi

# Create root profile
if command -v mkdir >/dev/null 2>&1; then
    mkdir -p /nix/var/nix/profiles/per-user/root
elif [ -x "/bin/busybox" ]; then
    /bin/busybox mkdir -p /nix/var/nix/profiles/per-user/root
else
    echo "❌ Nix Sidecar: Error: mkdir command not found. Cannot create root profile."
    exit 1
fi
if [ ! -L "/root/.nix-profile" ]; then
    /bin/busybox ln -sf /nix/var/nix/profiles/per-user/root/profile /root/.nix-profile
fi

# TODO: Simplify user management to avoid nix develop complexity
echo "🤖 Nix Sidecar: Setting up user management (simplified)..."
# Basic user setup without complex nix develop commands
if [ -n "$USERNAME" ] && [ -n "$PUID" ] && [ -n "$PGID" ]; then
    # User management (run within flake environment to have access to shadow tools)
    echo "🤖 Nix Sidecar: User setup here for $USERNAME (UID: $PUID, GID: $PGID)"
    nix develop /nix-sidecar --command sh -c "
    if ! id \"$USERNAME\" >/dev/null 2>&1; then
        echo \"🤖 Nix Sidecar: Creating user $USERNAME (UID: $PUID, GID: $PGID)\"
        groupadd -g \"$PGID\" \"$USERNAME\" || true
        mkdir -p \"/home/$USERNAME\" || true
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
    fi"
    # Create base sudoers file if it doesn't exist (not needed for gosu)
    # gosu is used instead of sudo for privilege escalation
else
    echo "🤖 Nix Sidecar: Using default user configuration"
fi
if [ -d "/home/$USERNAME" ]; then
    if command -v chown >/dev/null 2>&1; then
        chown -R "$PUID:$PGID" "/home/$USERNAME" || true
    elif [ -x "/bin/busybox" ]; then
        /bin/busybox chown -R "$PUID:$PGID" "/home/$USERNAME" || true
    else
        echo "❌ Nix Sidecar: Error: chown command not found. Cannot set home directory ownership."
        exit 1
    fi
fi

# Set up user Nix profile
echo "🤖 Nix Sidecar: Setting up user Nix profile..."
if command -v mkdir >/dev/null 2>&1; then
    mkdir -p /nix/var/nix/profiles/per-user/"$USERNAME" || true
elif [ -x "/bin/busybox" ]; then
    /bin/busybox mkdir -p /nix/var/nix/profiles/per-user/"$USERNAME" || true
else
    echo "❌ Nix Sidecar: Error: mkdir command not found. Cannot create user profile."
    exit 1
fi
# Ensure parent directory has correct permissions first
if command -v chmod >/dev/null 2>&1; then
    chmod 755 /nix/var/nix/profiles/per-user || true
elif [ -x "/bin/busybox" ]; then
    /bin/busybox chmod 755 /nix/var/nix/profiles/per-user || true
else
    echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set permissions."
    exit 1
fi
# Set ownership of user's profile directory
if command -v chown >/dev/null 2>&1; then
    chown -R "$PUID:$PGID" /nix/var/nix/profiles/per-user/"$USERNAME" || true
elif [ -x "/bin/busybox" ]; then
    /bin/busybox chown -R "$PUID:$PGID" /nix/var/nix/profiles/per-user/"$USERNAME" || true
else
    echo "❌ Nix Sidecar: Error: chown command not found. Cannot set profile ownership."
    exit 1
fi
# Ensure the parent directory is also accessible by the user
if command -v chown >/dev/null 2>&1; then
    chown "$PUID:$PGID" /nix/var/nix/profiles/per-user || true
elif [ -x "/bin/busybox" ]; then
    /bin/busybox chown "$PUID:$PGID" /nix/var/nix/profiles/per-user || true
else
    echo "❌ Nix Sidecar: Error: chown command not found. Cannot set parent directory ownership."
    exit 1
fi

# Link user profile to root profile if empty so they share tools
if [ ! -e /nix/var/nix/profiles/per-user/"$USERNAME"/profile ]; then
    echo "🤖 Nix Sidecar: Setting up user Nix profile..."
    # Create user profile directory if it doesn't exist
    if command -v mkdir >/dev/null 2>&1; then
        mkdir -p "/nix/var/nix/profiles/per-user/$USERNAME" || true
    elif [ -x "/bin/busybox" ]; then
        /bin/busybox mkdir -p "/nix/var/nix/profiles/per-user/$USERNAME" || true
    else
        echo "❌ Nix Sidecar: Error: mkdir command not found. Cannot create user profile directory."
        exit 1
    fi

    # Create .nix-profile symlink in user's home directory if home directory exists
    if [ -d "/home/$USERNAME" ]; then
        if [ ! -L "/home/$USERNAME/.nix-profile" ]; then
            ln -sf /nix/var/nix/profiles/per-user/"$USERNAME"/profile "/home/$USERNAME/.nix-profile" || true
            if command -v chown >/dev/null 2>&1; then
                chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile" || true
            elif [ -x "/bin/busybox" ]; then
                /bin/busybox chown -h "$PUID:$PGID" "/home/$USERNAME/.nix-profile" || true
            else
                echo "❌ Nix Sidecar: Error: chown command not found. Cannot set symlink ownership."
                exit 1
            fi
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
    i=1
    while [ $i -le 32 ]; do
        if ! grep -q "^nixbld$i:" /etc/passwd 2>/dev/null; then
            echo "🤖 Nix Sidecar: Creating nixbld$i user..."
            echo "nixbld$i:x:$i:30000:30000::/usr/sbin/nologin:nixbld$i" >> /etc/passwd
            echo "✅ nixbld$i user created"
        fi
        i=$((i + 1))
    done

    # Set correct permissions on /nix/store for multi-user Nix (group-writable by nixbld)
    if [ -d "/nix/store" ]; then
        echo "🤖 Nix Sidecar: Setting /nix/store permissions for multi-user Nix..."
        if command -v chown >/dev/null 2>&1; then
            chown root:nixbld /nix/store || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chown root:nixbld /nix/store || true
        else
            echo "❌ Nix Sidecar: Error: chown command not found. Cannot set store ownership."
            exit 1
        fi
        if command -v chmod >/dev/null 2>&1; then
            chmod 2775 /nix/store || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chmod 2775 /nix/store || true
        else
            echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set store permissions."
            exit 1
        fi
        echo "✅ /nix/store permissions set to root:nixbld 2775"
    fi

    # Set correct permissions on /nix/var for multi-user Nix
    if [ -d "/nix/var" ]; then
        echo "🤖 Nix Sidecar: Setting /nix/var permissions for multi-user Nix..."
        if command -v chown >/dev/null 2>&1; then
            chown root:root /nix/var || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chown root:root /nix/var || true
        else
            echo "❌ Nix Sidecar: Error: chown command not found. Cannot set var ownership."
            exit 1
        fi
        if command -v chmod >/dev/null 2>&1; then
            chmod 755 /nix/var || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chmod 755 /nix/var || true
        else
            echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set var permissions."
            exit 1
        fi
        echo "✅ /nix/var permissions set to root:root 755"
    fi

    # Set correct permissions on /etc/nix for multi-user Nix (shared config)
    if [ -d "/etc/nix" ]; then
        echo "🤖 Nix Sidecar: Setting /etc/nix permissions for multi-user Nix..."
        if command -v chown >/dev/null 2>&1; then
            chown root:root /etc/nix || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chown root:root /etc/nix || true
        else
            echo "❌ Nix Sidecar: Error: chown command not found. Cannot set etc/nix ownership."
            exit 1
        fi
        if command -v chmod >/dev/null 2>&1; then
            chmod 644 /etc/nix || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chmod 644 /etc/nix || true
        else
            echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set etc/nix permissions."
            exit 1
        fi
        echo "✅ /etc/nix permissions set to root:root 644"
    fi

    # Set correct permissions on /root/.cache/nix for multi-user Nix (daemon cache)
    if [ -d "/root/.cache/nix" ]; then
        echo "🤖 Nix Sidecar: Setting /root/.cache/nix permissions for multi-user Nix..."
        if command -v chown >/dev/null 2>&1; then
            chown root:root /root/.cache/nix || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chown root:root /root/.cache/nix || true
        else
            echo "❌ Nix Sidecar: Error: chown command not found. Cannot set cache ownership."
            exit 1
        fi
        if command -v chmod >/dev/null 2>&1; then
            chmod 755 /root/.cache/nix || true
        elif [ -x "/bin/busybox" ]; then
            /bin/busybox chmod 755 /root/.cache/nix || true
        else
            echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set cache permissions."
            exit 1
        fi
        echo "✅ /root/.cache/nix permissions set to root:root 755"
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

# Insure proper execute permissions for manual call of scripts
if command -v chmod >/dev/null 2>&1; then
    chmod +x /nix-sidecar/healthcheck-nix-sidecar.sh /nix-sidecar/entrypoint-nix-sidecar.sh
elif [ -x "/bin/busybox" ]; then
    /bin/busybox chmod +x /nix-sidecar/healthcheck-nix-sidecar.sh /nix-sidecar/entrypoint-nix-sidecar.sh
else
    echo "❌ Nix Sidecar: Error: chmod command not found. Cannot set script permissions."
    exit 1
fi

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
