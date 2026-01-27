#!/bin/sh
set -eu

# Note: Heavy integrity checks run via supercronic (nix store verify --all)
# This healthcheck only verifies basic operational readiness

# Ensure Nix binaries are in the PATH
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Source Nix environment if available
if [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi

# Check if nix is operational
if ! command -v nix > /dev/null 2>&1; then
    echo "❌ healthcheck: nix not in PATH (\$PATH)"
    exit 1
fi

# Core functionality check: verify nix develop works (this is the main purpose of nix-sidecar)
if [ -f /nix-sidecar/flake.nix ]; then
    echo "🔍 healthcheck: Testing nix develop functionality..."
    if ! nix develop /nix-sidecar --command echo "nix develop test successful" > /dev/null 2>&1; then
        echo "❌ healthcheck: nix develop failed - core functionality broken"
        exit 1
    fi
    echo "✅ healthcheck: nix develop is working"
else
    echo "❌ healthcheck: /nix-sidecar/flake.nix not found"
    exit 1
fi

# Check if supercronic is running (when container is running in scheduler mode)
if [ -f /nix-sidecar/supercronic.crond ]; then
    echo "🔍 healthcheck: Checking supercronic scheduler..."
    # Check if supercronic process is running
    if ! pgrep -f "supercronic" > /dev/null 2>&1; then
        echo "❌ healthcheck: supercronic scheduler not running"
        exit 1
    fi
    echo "✅ healthcheck: supercronic scheduler is running"
fi

# Basic nix version check as additional verification
nix --version > /dev/null || { echo "❌ healthcheck: nix --version failed"; exit 1; }

# Comprehensive Nix ownership and permissions verification
echo "🔍 healthcheck: Verifying Nix ownership and permissions..."

# Check /nix directory ownership and permissions
if [ ! -d "/nix" ]; then
    echo "❌ healthcheck: /nix directory does not exist"
    exit 1
fi

# Verify /nix is owned by root:root with 755 permissions
nix_owner=$(stat -c "%U:%G" /nix 2>/dev/null || echo "unknown")
nix_perms=$(stat -c "%a" /nix 2>/dev/null || echo "unknown")
if [ "$nix_owner" != "root:root" ]; then
    echo "❌ healthcheck: /nix ownership is $nix_owner, expected root:root"
    exit 1
fi
if [ "$nix_perms" != "755" ]; then
    echo "❌ healthcheck: /nix permissions are $nix_perms, expected 755"
    exit 1
fi
echo "✅ healthcheck: /nix ownership and permissions correct (root:root, 755)"

# Check /nix/store ownership and permissions
if [ ! -d "/nix/store" ]; then
    echo "❌ healthcheck: /nix/store directory does not exist"
    exit 1
fi

store_owner=$(stat -c "%U:%G" /nix/store 2>/dev/null || echo "unknown")
store_perms=$(stat -c "%a" /nix/store 2>/dev/null || echo "unknown")
if [ "$store_owner" != "root:root" ]; then
    echo "❌ healthcheck: /nix/store ownership is $store_owner, expected root:root"
    exit 1
fi
if [ "$store_perms" != "755" ]; then
    echo "❌ healthcheck: /nix/store permissions are $store_perms, expected 755"
    exit 1
fi
echo "✅ healthcheck: /nix/store ownership and permissions correct (root:root, 755)"

# Check /nix/var ownership and permissions
if [ ! -d "/nix/var" ]; then
    echo "❌ healthcheck: /nix/var directory does not exist"
    exit 1
fi

var_owner=$(stat -c "%U:%G" /nix/var 2>/dev/null || echo "unknown")
var_perms=$(stat -c "%a" /nix/var 2>/dev/null || echo "unknown")
if [ "$var_owner" != "root:root" ]; then
    echo "❌ healthcheck: /nix/var ownership is $var_owner, expected root:root"
    exit 1
fi
if [ "$var_perms" != "755" ]; then
    echo "❌ healthcheck: /nix/var permissions are $var_perms, expected 755"
    exit 1
fi
echo "✅ healthcheck: /nix/var ownership and permissions correct (root:root, 755)"

# Verify nixbld group exists with correct GID
if ! getent group nixbld > /dev/null 2>&1; then
    echo "❌ healthcheck: nixbld group does not exist"
    exit 1
fi

nixbld_gid=$(getent group nixbld | cut -d: -f3)
if [ "$nixbld_gid" != "30000" ]; then
    echo "❌ healthcheck: nixbld group GID is $nixbld_gid, expected 30000"
    exit 1
fi
echo "✅ healthcheck: nixbld group exists with correct GID (30000)"

# Verify nixbld users exist (nixbld1 through nixbld32)
for i in $(seq 1 32); do
    if ! getent passwd "nixbld$i" > /dev/null 2>&1; then
        echo "❌ healthcheck: nixbld$i user does not exist"
        exit 1
    fi

    # Check each nixbld user has nixbld as primary group
    user_gid=$(getent passwd "nixbld$i" | cut -d: -f4)
    if [ "$user_gid" != "30000" ]; then
        echo "❌ healthcheck: nixbld$i user primary group GID is $user_gid, expected 30000"
        exit 1
    fi

    # Check nixbld users have no login shell
    user_shell=$(getent passwd "nixbld$i" | cut -d: -f7)
    if [ "$user_shell" != "/usr/sbin/nologin" ] && [ "$user_shell" != "/bin/false" ]; then
        echo "❌ healthcheck: nixbld$i user shell is $user_shell, expected /usr/sbin/nologin or /bin/false"
        exit 1
    fi
done
echo "✅ healthcheck: All nixbld users (nixbld1-32) exist with correct configuration"

# Check user profile directory structure
if [ -n "${USERNAME:-}" ] && [ -n "${PUID:-}" ]; then
    user_profile_dir="/nix/var/nix/profiles/per-user/$USERNAME"
    if [ ! -d "$user_profile_dir" ]; then
        echo "❌ healthcheck: User profile directory $user_profile_dir does not exist"
        exit 1
    fi

    # Check user profile ownership (should be USERNAME:nixbld)
    profile_owner=$(stat -c "%U:%G" "$user_profile_dir" 2>/dev/null || echo "unknown")
    if [ "$profile_owner" != "$USERNAME:nixbld" ]; then
        echo "❌ healthcheck: User profile ownership is $profile_owner, expected $USERNAME:nixbld"
        exit 1
fi
    echo "✅ healthcheck: User profile directory ownership correct ($USERNAME:nixbld)"

    # Check user profile symlink in home directory
    if [ -d "/home/$USERNAME" ]; then
        home_profile="/home/$USERNAME/.nix-profile"
        if [ -L "$home_profile" ]; then
            # Verify symlink points to correct location
            link_target=$(readlink "$home_profile" 2>/dev/null || echo "broken")
            expected_target="/nix/var/nix/profiles/per-user/$USERNAME/profile"
            if [ "$link_target" != "$expected_target" ]; then
                echo "❌ healthcheck: .nix-profile symlink points to $link_target, expected $expected_target"
                exit 1
            fi
            echo "✅ healthcheck: User .nix-profile symlink correctly configured"
        elif [ -e "$home_profile" ]; then
            echo "❌ healthcheck: .nix-profile exists but is not a symlink"
            exit 1
        else
            echo "⚠️  healthcheck: .nix-profile symlink does not exist (may be created on first use)"
        fi
    fi
else
    echo "⚠️  healthcheck: USERNAME or PUID not set, skipping user profile checks"
fi

# Verify nix.conf exists and contains build-users-group
if [ ! -f "/etc/nix/nix.conf" ]; then
    echo "❌ healthcheck: /etc/nix/nix.conf does not exist"
    exit 1
fi

if ! grep -q "build-users-group = nixbld" /etc/nix/nix.conf; then
    echo "❌ healthcheck: /etc/nix/nix.conf missing build-users-group = nixbld"
    exit 1
fi
echo "✅ healthcheck: nix.conf correctly configured with build-users-group"

# Check that critical directories are not world-writable (security check)
for dir in "/nix" "/nix/store" "/nix/var"; do
    if [ -w "$dir" ] && [ "$(stat -c "%a" "$dir" | cut -c3)" = "w" ]; then
        echo "❌ healthcheck: $dir is world-writable (security risk)"
        exit 1
    fi
done
echo "✅ healthcheck: No world-writable directories in Nix store (security verified)"

# Verify current user can access nix commands (should be running as USERNAME)
if [ -n "${USERNAME:-}" ]; then
    current_user=$(id -un)
    if [ "$current_user" != "$USERNAME" ]; then
        echo "❌ healthcheck: Running as $current_user, expected $USERNAME"
        exit 1
    fi
    echo "✅ healthcheck: Running as correct user ($USERNAME)"

    # SECURITY CHECK: Verify USERNAME is NOT in nixbld group (security isolation)
    if getent group nixbld | grep -q "$USERNAME"; then
        echo "❌ healthcheck: $USERNAME is in nixbld group - security boundary violated"
        exit 1
    fi
    echo "✅ healthcheck: $USERNAME correctly not in nixbld group (security isolation verified)"

    # Verify user has proper primary group (should not be nixbld)
    user_primary_gid=$(id -g "$USERNAME")
    if [ "$user_primary_gid" = "30000" ]; then
        echo "❌ healthcheck: $USERNAME has nixbld as primary group (GID 30000) - security risk"
        exit 1
    fi
    echo "✅ healthcheck: $USERNAME has correct primary group (not nixbld)"
fi

echo "✅ healthcheck: Nix sidecar is healthy - All ownership and permissions verified"
exit 0
