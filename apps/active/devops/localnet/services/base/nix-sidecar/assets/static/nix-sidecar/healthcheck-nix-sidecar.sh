#!/usr/bin/env bash
set -eu

# NOTE: This healthcheck expects a Nix MULTI-USER installation
# It does NOT support single-user installations and will error if misconfigured
# Multi-user Nix specific requirements:
# - /nix/store owned by root:nixbld with 2775 permissions (group-writable)
# - /nix/var owned by root:root with 755 permissions
# - nixbld group (GID 30000) with nixbld1-32 users
# - build-users-group = nixbld in /etc/nix/nix.conf
#
# Note: Heavy integrity checks run via supercronic (nix store verify --all)
# This healthcheck only verifies basic operational readiness

# Drop privileges to non-root user if running as root
if [ "$(id -u)" = "0" ] && [ -n "$PUID" ]; then
    # Check if user with PUID exists and switch to it
    if getent passwd "$PUID" >/dev/null 2>&1; then
        # Use setpriv if available (more secure) - use numeric UID
        if command -v setpriv >/dev/null 2>&1; then
            exec setpriv --reuid "$PUID" --regid "$PUID" --clear-groups "$0" "$@"
        # Use chroot with numeric UID as fallback (less ideal but available)
        elif command -v chroot >/dev/null 2>&1; then
            # Find username for PUID to use with chroot
            USERNAME_FOR_PUID=$(getent passwd "$PUID" | cut -d: -f1)
            if [ -n "$USERNAME_FOR_PUID" ] && [ -d "/home/$USERNAME_FOR_PUID" ]; then
                exec chroot --userspec="$PUID:$PUID" / "$0" "$@"
            else
                echo "[WARN] ⚠️ Cannot find home directory for UID $PUID"
                echo "[WARN] ⚠️ Running healthcheck as root"
            fi
        # If no user switching tools available, continue as root but warn
        else
            echo "[WARN] ⚠️ Cannot drop privileges - no user switching tools available"
            echo "[WARN] ⚠️ Running healthcheck as root"
        fi
    else
        echo "[WARN] ⚠️ User with UID $PUID does not exist"
        echo "[WARN] ⚠️ Running healthcheck as root"
    fi
fi

# Check for verbose flag (after potential privilege drop)
if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
  VERBOSE=true
  shift
fi

# Logging functions
info() {
  if [ "${VERBOSE:-}" = "true" ]; then
    echo "[INFO] 🔍 $1"
  fi
}

warn() {
  echo "[WARN] ⚠️ $1"
}

error() {
  echo "[ERROR] ❌ $1"
}

# Test macros
test() {
  info "Testing: $1"
}

success() {
  info "✅ Success: $1"
}

not_applicable() {
  info "⚪️ Not applicable: $1"
}


# Ensure Nix binaries are in the PATH
export PATH="/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Source Nix environment if available
if [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi

# Check if nix is operational
test "nix binary availability..."
if ! command -v nix > /dev/null 2>&1; then
    error "nix not in PATH (\$PATH)"
    exit 1
fi

# Quick nix version check
nix_version=$(nix --version 2>/dev/null | head -1)
if [ -n "$nix_version" ]; then
    success "Nix binary available: $nix_version"
else
    error "Nix version check failed"
    exit 1
fi

# Check nix store basic functionality
if [ -d "/nix/store" ] && [ -d "/nix/var/nix" ]; then
    success "Nix store directories exist"
else
    error "Nix store directories missing"
    exit 1
fi

# Skip nix develop check for healthcheck (too slow)
# Only run it if explicitly requested with --full
if [ "${FULL_CHECK:-}" = "true" ]; then
    info "Running full nix develop check..."
    if [ -f /nix-sidecar/flake.nix ]; then
        if nix develop /nix-sidecar --command echo "nix develop OK" 2>/dev/null; then
            success "nix develop works"
        else
            error "nix develop failed - core functionality broken"
            exit 1
        fi
    else
        error "/nix-sidecar/flake.nix not found"
        exit 1
    fi
else
    info "Skipping nix develop check (use FULL_CHECK=true for full validation)"
fi

# Check if supercronic is running (when container is running in scheduler mode)
if [ -f /nix-sidecar/supercronic.crond ]; then
    test "supercronic scheduler..."
    # Check if supercronic process is running
    if ! pgrep -f "supercronic" > /dev/null 2>&1; then
        warn "supercronic scheduler not running"
        exit 1
    fi
    success "supercronic scheduler is running"
fi

# Basic nix version check as additional verification
nix --version > /dev/null || { error "nix --version failed"; exit 1; }

# Comprehensive Nix ownership and permissions verification
info "Verifying Nix ownership and permissions..."

# Check /nix directory ownership and permissions (MULTI-USER NIX REQUIREMENTS)
if [ ! -d "/nix" ]; then
    error "/nix directory does not exist"
    exit 1
fi

# Verify /nix is owned by root:root with 755 permissions (base directory)
test "/nix directory ownership..."
nix_owner=$(stat -c "%U:%G" /nix 2>/dev/null || echo "unknown")
nix_perms=$(stat -c "%a" /nix 2>/dev/null || echo "unknown")
if [ "$nix_owner" != "root:root" ]; then
    error "/nix ownership is $nix_owner, REQUIRED: root:root (multi-user Nix base dir)"
    exit 1
fi
if [ "$nix_perms" != "755" ]; then
    error "/nix permissions are $nix_perms, REQUIRED: 755 (multi-user Nix base dir)"
    exit 1
fi
success "/nix ownership and permissions correct (multi-user Nix base: root:root, 755)"

# Check /etc/nix ownership and permissions (MULTI-USER NIX REQUIREMENTS)
test "/etc/nix directory..."
if [ ! -d "/etc/nix" ]; then
    error "/etc/nix directory does not exist"
    exit 1
fi

etc_nix_owner=$(stat -c "%U:%G" /etc/nix 2>/dev/null || echo "unknown")
etc_nix_perms=$(stat -c "%a" /etc/nix 2>/dev/null || echo "unknown")
# Multi-user Nix REQUIRES root:root ownership with 644 permissions for shared config
if [ "$etc_nix_owner" != "root:root" ]; then
    error "/etc/nix ownership is $etc_nix_owner, REQUIRED: root:root (multi-user Nix shared config)"
    exit 1
fi
if [ "$etc_nix_perms" != "644" ] && [ "$etc_nix_perms" != "755" ]; then
    error "/etc/nix permissions are $etc_nix_perms, REQUIRED: 644 (multi-user Nix shared config)"
    exit 1
fi
if [ "$etc_nix_perms" = "755" ]; then
    warn "/etc/nix permissions are 755 (acceptable for Docker volumes, 644 preferred)"
fi
success "/etc/nix ownership and permissions correct (multi-user Nix shared config: $etc_nix_owner, $etc_nix_perms)"

# Check /root/.cache/nix ownership and permissions (MULTI-USER NIX REQUIREMENTS)
test "/root/.cache/nix directory..."
if [ ! -d "/root/.cache/nix" ]; then
    not_applicable "/root/.cache/nix directory does not exist (may not be mounted yet)"
else
    cache_nix_owner=$(stat -c "%U:%G" /root/.cache/nix 2>/dev/null || echo "unknown")
    cache_nix_perms=$(stat -c "%a" /root/.cache/nix 2>/dev/null || echo "unknown")
    # Multi-user Nix REQUIRES root:root ownership with 755 permissions for daemon cache
    if [ "$cache_nix_owner" != "root:root" ]; then
        error "/root/.cache/nix ownership is $cache_nix_owner, REQUIRED: root:root (multi-user Nix daemon cache)"
        exit 1
    fi
    if [ "$cache_nix_perms" != "755" ]; then
        error "/root/.cache/nix permissions are $cache_nix_perms, REQUIRED: 755 (multi-user Nix daemon cache)"
        exit 1
    fi
    success "/root/.cache/nix ownership and permissions correct (multi-user Nix daemon cache: $cache_nix_owner, $cache_nix_perms)"
fi

# Check /nix/store ownership and permissions (MULTI-USER NIX REQUIREMENTS)
test "/nix/store directory..."
if [ ! -d "/nix/store" ]; then
    error "/nix/store directory does not exist"
    exit 1
fi

store_owner=$(stat -c "%U:%G" /nix/store 2>/dev/null || echo "unknown")
store_perms=$(stat -c "%a" /nix/store 2>/dev/null || echo "unknown")
# Multi-user Nix REQUIRES root:nixbld ownership with group write permissions (2775)
if [ "$store_owner" != "root:nixbld" ]; then
    error "/nix/store ownership is $store_owner, REQUIRED: root:nixbld (multi-user Nix)"
    error "Single-user Nix installations are NOT supported"
    exit 1
fi
# Multi-user Nix REQUIRES 2775 permissions (group-writable by nixbld)
# However, Docker volumes may not support setgid, so accept 1775 as well
if [ "$store_perms" != "2775" ] && [ "$store_perms" != "1775" ]; then
    error "/nix/store permissions are $store_perms, REQUIRED: 2775 (multi-user Nix) or 1775 (Docker volume compatible)"
    error "Single-user Nix installations are NOT supported"
    exit 1
fi
if [ "$store_perms" = "1775" ]; then
    warn "/nix/store permissions are 1775 (setgid not supported on Docker volumes)"
    warn "This is acceptable for Docker-mounted volumes"
fi
success "/nix/store ownership and permissions correct (multi-user Nix: $store_owner, $store_perms)"

# Check /nix/var ownership and permissions (MULTI-USER NIX REQUIREMENTS)
test "/nix/var directory..."
if [ ! -d "/nix/var" ]; then
    error "/nix/var directory does not exist"
    exit 1
fi

var_owner=$(stat -c "%U:%G" /nix/var 2>/dev/null || echo "unknown")
var_perms=$(stat -c "%a" /nix/var 2>/dev/null || echo "unknown")
# Multi-user Nix REQUIRES root:root ownership for /nix/var
if [ "$var_owner" != "root:root" ]; then
    error "/nix/var ownership is $var_owner, REQUIRED: root:root (multi-user Nix)"
    exit 1
fi
# Multi-user Nix REQUIRES 755 permissions for /nix/var
if [ "$var_perms" != "755" ]; then
    error "/nix/var permissions are $var_perms, REQUIRED: 755 (multi-user Nix)"
    exit 1
fi
success "/nix/var ownership and permissions correct (multi-user Nix: $var_owner, $var_perms)"

# Verify nixbld group exists with correct GID
test "nixbld group..."
nixbld_found=false
while IFS=: read -r name passwd gid members; do
    if [ "$name" = "nixbld" ]; then
        nixbld_found=true
        if [ "$gid" = "30000" ]; then
            success "nixbld group exists with correct GID (30000)"
        else
            warn "nixbld group GID is $gid, expected 30000"
        fi
        break
    fi
done < /etc/group

if [ "$nixbld_found" = "false" ]; then
    error "nixbld group does not exist"
    exit 1
fi

# Check nixbld users exist
test "nixbld users..."
nixbld_users=0
for i in $(seq 1 32); do
    nixbld_user_found=false
    while IFS=: read -r name passwd uid gid comment home shell; do
        if [ "$name" = "nixbld$i" ]; then
            nixbld_user_found=true
            nixbld_users=$((nixbld_users + 1))
            break
        fi
    done < /etc/passwd

    if [ "$nixbld_user_found" = "false" ]; then
        error "nixbld$i user does not exist"
        exit 1
    fi
done

if [ "$nixbld_users" -lt 32 ]; then
    warn "Only $nixbld_users nixbld users found, expected 32"
else
    success "All 32 nixbld users exist"
fi

for i in $(seq 1 32); do
    # Check each nixbld user has nixbld as primary group
    user_gid=""
    while IFS=: read -r name passwd uid gid comment home shell; do
        if [ "$name" = "nixbld$i" ]; then
            user_gid="$gid"
            break
        fi
    done < /etc/passwd

    if [ "$user_gid" != "30000" ]; then
        echo "❌ healthcheck: nixbld$i user primary group GID is $user_gid, expected 30000"
        exit 1
    fi
done

# Check nixbld users have no login shell
for i in $(seq 1 32); do
    user_shell=""
    while IFS=: read -r name passwd uid gid comment home shell; do
        if [ "$name" = "nixbld$i" ]; then
            user_shell="$shell"
            break
        fi
    done < /etc/passwd

    # Accept various nologin paths in Nix
    if [ "$user_shell" != "/usr/sbin/nologin" ] && [ "$user_shell" != "/bin/false" ] && [ "$user_shell" != "/run/current-system/sw/bin/nologin" ]; then
        echo "❌ healthcheck: nixbld$i user shell is $user_shell, expected nologin"
        exit 1
    fi
done
echo "✅ healthcheck: All nixbld users (nixbld1-32) exist with correct configuration"

# Check if we can write to user profile directory
if [ -n "$PUID" ]; then
    # Get username for PUID to construct profile path
    USERNAME_FOR_PUID=$(getent passwd "$PUID" 2>/dev/null | cut -d: -f1)
    if [ -n "$USERNAME_FOR_PUID" ]; then
        user_profile_dir="/nix/var/nix/profiles/per-user/$USERNAME_FOR_PUID"
        if [ ! -d "$user_profile_dir" ]; then
            not_applicable "User profile directory does not exist"
        else
            test "user profile write access..."
            if touch "$user_profile_dir/.test_write" 2>/dev/null; then
                rm -f "$user_profile_dir/.test_write"
                success "User profile directory is writable by UID $PUID"
            else
                warn "User profile directory is not writable by UID $PUID"
            fi
        fi
    else
        not_applicable "Cannot find username for PUID $PUID, skipping profile write test"
    fi
else
    not_applicable "PUID not set, skipping profile write test"
fi

# Check user profile directory structure and symlinks
if [ -z "$PUID" ]; then
    warn "PUID not set, skipping user profile checks"
else
    # Get username for PUID to construct profile path
    USERNAME_FOR_PUID=$(getent passwd "$PUID" 2>/dev/null | cut -d: -f1)
    if [ -z "$USERNAME_FOR_PUID" ]; then
        warn "Cannot find username for PUID $PUID, skipping user profile checks"
    else
        test "user profile for UID $PUID ($USERNAME_FOR_PUID)..."
        user_profile_dir="/nix/var/nix/profiles/per-user/$USERNAME_FOR_PUID"
        if [ ! -d "$user_profile_dir" ]; then
            error "User profile directory $user_profile_dir does not exist"
            exit 1
        fi
        success "User profile directory exists"

        # Check user profile ownership (should be USERNAME_FOR_PUID:nixbld)
        profile_owner=$(stat -c "%U:%G" "$user_profile_dir" 2>/dev/null || echo "unknown")
        if [ "$profile_owner" != "$USERNAME_FOR_PUID:nixbld" ]; then
            warn "User profile ownership is $profile_owner, expected $USERNAME_FOR_PUID:nixbld"
        else
            success "User profile ownership correct ($USERNAME_FOR_PUID:nixbld)"
        fi

        # Check user profile symlink
        if [ -L "/home/$USERNAME_FOR_PUID/.nix-profile" ]; then
            test "user profile symlink..."
            symlink_target=$(readlink "/home/$USERNAME_FOR_PUID/.nix-profile" 2>/dev/null || echo "unknown")
            if [ "$symlink_target" = "/nix/var/nix/profiles/per-user/$USERNAME_FOR_PUID/profile" ]; then
                success "User profile symlink points to correct location"
            else
                warn "User profile symlink points to $symlink_target"
            fi
        else
            warn "User profile symlink does not exist"
        fi
    fi
fi

# Check nix.conf settings
test "nix.conf configuration..."
if [ ! -f "/etc/nix/nix.conf" ]; then
    error "/etc/nix/nix.conf does not exist"
    exit 1
fi

# Check if build-users-group is set
build_users_group=""
while IFS= read -r line; do
    case "$line" in
        build-users-group=*)
            build_users_group="${line#build-users-group=}"
            build_users_group=$(echo "$build_users_group" | tr -d ' ')
            break
            ;;
    esac
done < /etc/nix/nix.conf

if [ -n "$build_users_group" ]; then
    if [ "$build_users_group" = "nixbld" ]; then
        success "build-users-group is set to nixbld"
    else
        warn "build-users-group is set to '$build_users_group', expected nixbld"
    fi
else
    warn "build-users-group not set in nix.conf"
fi

# Check that critical directories are not world-writable (security check)
test "world-writable directories (security)..."
world_writable_found=false
for dir in "/nix" "/nix/store" "/nix/var"; do
    if [ -w "$dir" ] && [ "$(stat -c "%a" "$dir" | cut -c3)" = "w" ]; then
        error "$dir is world-writable (security risk)"
        world_writable_found=true
    fi
done

if [ "$world_writable_found" = "false" ]; then
    info "No world-writable directories in Nix store (security verified)"
fi

# Check current user is not in nixbld group (security isolation)
if [ -z "$PUID" ]; then
    not_applicable "PUID not set, skipping user group check"
else
    # Get username for PUID to check group membership
    USERNAME_FOR_PUID=$(getent passwd "$PUID" 2>/dev/null | cut -d: -f1)
    if [ -z "$USERNAME_FOR_PUID" ]; then
        not_applicable "Cannot find username for PUID $PUID, skipping user group check"
    else
        test "user group membership for security..."
        # Check if user is in nixbld group by checking /etc/group
        user_in_nixbld=false
        while IFS=: read -r name passwd gid members; do
            if [ "$name" = "nixbld" ]; then
                # Check if USERNAME_FOR_PUID is in the members list
                case ",$members," in
                    *,"$USERNAME_FOR_PUID",*) user_in_nixbld=true ;;
                esac
                break
            fi
        done < /etc/group

        if [ "$user_in_nixbld" = "true" ]; then
            error "$USERNAME_FOR_PUID (UID $PUID) is in nixbld group - security boundary violated"
            exit 1
        else
            success "$USERNAME_FOR_PUID (UID $PUID) is not in nixbld group (security isolation verified)"
        fi
    fi
fi

# Final success message
success "All health checks passed - Nix multi-user installation verified"
exit 0
