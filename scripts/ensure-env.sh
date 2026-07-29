#!/usr/bin/env sh
# Ensure Nix and devbox are reachable in the current shell.
#
# Safe to source OR execute. When sourced, exports PATH/NIX_PATH into the
# caller's shell. When executed, prints status and exits 0 (never non-zero,
# so sourcing can never break a shell).
#
# Idempotent: re-sourcing is a no-op once paths are present.
#
# Usage:
#   source scripts/ensure-env.sh     # fix PATH in current shell
#   . scripts/ensure-env.sh          # same thing
#   scripts/ensure-env.sh            # just print status, don't persist
#
# Wired into `just doctor-internal` so `just doctor` self-heals its own PATH
# before checking tool versions. AGENTS.md points agents here instead of
# inlining the detection logic.

# --- Nix detection ---
if ! command -v nix >/dev/null 2>&1; then
    for _nix_bin in \
        /nix/var/nix/profiles/default/bin/nix \
        "$HOME/.nix-profile/bin/nix" \
        /usr/local/bin/nix \
        /usr/bin/nix; do
        if [ -x "$_nix_bin" ]; then
            _nix_dir="$(dirname "$_nix_bin")"
            case ":$PATH:" in
                *":$_nix_dir:"*) ;;
                *) PATH="$_nix_dir:$PATH"; export PATH ;;
            esac
            break
        fi
    done
    unset _nix_bin _nix_dir

    # Source Nix profile script if present (sets NIX_PATH, NIX_PROFILES, etc.)
    if [ -r /etc/profile.d/nix.sh ]; then
        . /etc/profile.d/nix.sh
    elif [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi

# --- devbox detection ---
if ! command -v devbox >/dev/null 2>&1; then
    for _dbx_dir in \
        "$HOME/.local/share/devbox/global/shims" \
        /usr/local/bin; do
        if [ -x "$_dbx_dir/devbox" ]; then
            case ":$PATH:" in
                *":$_dbx_dir:"*) ;;
                *) PATH="$_dbx_dir:$PATH"; export PATH ;;
            esac
            break
        fi
    done
    unset _dbx_dir
fi

# --- Status report (stderr so sourcing doesn't pollute stdout) ---
_nix_status() { command -v nix >/dev/null 2>&1 && nix --version 2>/dev/null || echo 'NOT FOUND'; }
_dbx_status() { command -v devbox >/dev/null 2>&1 && devbox version 2>/dev/null || echo 'NOT FOUND'; }
_rtk_status()  { command -v devbox >/dev/null 2>&1 && devbox run -- command -v rtk 2>/dev/null || echo 'NOT FOUND'; }
_just_status() { command -v devbox >/dev/null 2>&1 && devbox run -- just -V 2>/dev/null || echo 'NOT FOUND'; }

printf 'Nix:    %s\n'    "$(_nix_status)"    >&2
printf 'Devbox: %s\n'    "$(_dbx_status)"    >&2
printf 'rtk:    %s\n'    "$(_rtk_status)"   >&2
printf 'Just:   %s\n'    "$(_just_status)"   >&2
unset -f _nix_status _dbx_status _rtk_status _just_status

# Source-safe terminator: return when sourced, exit 0 when executed.
return 0 2>/dev/null || exit 0
