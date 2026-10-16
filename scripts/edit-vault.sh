#!/usr/bin/env bash
# Edit (or view/create/rekey) an Ansible vault file inside a container.
#
# Wraps the `docker run ... ansible-vault edit` pattern documented in
# AGENTS.md ("Vault Edits (Agent → User Handoff)"):
#   - vault password file mounted read-only
#   - vault DIRECTORY mounted (not the file) so ansible-vault's atomic
#     temp-file + rename replace works inside the container
#   - VAULT_EDITOR used inside the container (must exist in the image —
#     alpine/ansible ships busybox vi only, so host $EDITOR is NOT passed
#     through: host editors like nano/code/emacs aren't installed there)
#
# Usage:
#   scripts/edit-vault.sh                       # edit the default levonk vault
#   scripts/edit-vault.sh edit [vault-file]     # edit (default action)
#   scripts/edit-vault.sh view [vault-file]     # view decrypted contents
#   scripts/edit-vault.sh create <vault-file>   # create a new vault file
#   scripts/edit-vault.sh rekey [vault-file]    # change vault password
#
# Environment overrides:
#   CONTAINER_RUNTIME     (default: first of docker, podman, container in PATH;
#                          OrbStack/Docker Desktop/colima expose the `docker`
#                          CLI, so they need no special-casing)
#   VAULT_PASSWORD_FILE   (default: ~/.ansible/vault_password)
#   ANSIBLE_IMAGE         (default: alpine/ansible:latest)
#   VAULT_EDITOR          (default: vi; editor inside the container — the
#                          alpine/ansible image only has busybox vi)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_VAULT="$REPO_ROOT/levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.ansible/vault_password}"
ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-alpine/ansible:latest}"
CONTAINER_EDITOR="${VAULT_EDITOR:-vi}"

usage() {
    sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

ACTION="${1:-edit}"
case "$ACTION" in
    -h|--help|help) usage; exit 0 ;;
    edit|view|create|rekey) ;;
    *)
        # No action given — treat first arg as a vault file path.
        if [ -f "$ACTION" ] || [ "$ACTION" != "${ACTION#*/}" ]; then
            set -- edit "$@"
            ACTION="edit"
        else
            echo "ERROR: unknown action '$ACTION' (expected: edit|view|create|rekey)" >&2
            usage >&2
            exit 1
        fi
        ;;
esac

VAULT_FILE="${2:-$DEFAULT_VAULT}"

# Resolve to an absolute path (portable; no realpath/readlink -f on macOS).
case "$VAULT_FILE" in
    /*) ;;
    *)  VAULT_FILE="$(cd "$(dirname "$VAULT_FILE")" && pwd)/$(basename "$VAULT_FILE")" ;;
esac

# Pick a container runtime: explicit override, else docker → podman →
# Apple `container`.
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
if [ -n "$CONTAINER_RUNTIME" ]; then
    if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
        echo "ERROR: CONTAINER_RUNTIME='$CONTAINER_RUNTIME' not found in PATH" >&2
        exit 1
    fi
else
    for rt in docker podman container; do
        if command -v "$rt" >/dev/null 2>&1; then
            CONTAINER_RUNTIME="$rt"
            break
        fi
    done
    if [ -z "$CONTAINER_RUNTIME" ]; then
        echo "ERROR: no container runtime found (tried: docker, podman, container)" >&2
        echo "       install one, or set CONTAINER_RUNTIME to a runtime binary" >&2
        exit 1
    fi
fi

if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "ERROR: vault password file not found: $VAULT_PASSWORD_FILE" >&2
    exit 1
fi

if [ "$ACTION" != "create" ] && [ ! -f "$VAULT_FILE" ]; then
    echo "ERROR: vault file not found: $VAULT_FILE" >&2
    exit 1
fi

if [ "$ACTION" = "create" ] && [ -f "$VAULT_FILE" ]; then
    echo "ERROR: vault file already exists: $VAULT_FILE (use 'edit')" >&2
    exit 1
fi

VAULT_DIR="$(dirname "$VAULT_FILE")"
VAULT_NAME="$(basename "$VAULT_FILE")"

# podman and Apple container don't assume docker.io for unqualified image
# names (podman may prompt interactively for a registry) — qualify explicitly.
case "$CONTAINER_RUNTIME" in
    podman|container)
        case "${ANSIBLE_IMAGE%%/*}" in
            *.*|*:*|localhost) ;;
            *) ANSIBLE_IMAGE="docker.io/$ANSIBLE_IMAGE" ;;
        esac
        ;;
esac

# Per-runtime run arguments. Apple container needs its helper service running
# and uses --mount syntax (its -v read-only suffix isn't documented).
case "$CONTAINER_RUNTIME" in
    container)
        if ! container system status >/dev/null 2>&1; then
            echo "Starting Apple container service..." >&2
            container system start --enable-kernel-install
        fi
        # Apple container can only bind-mount directories — mount the
        # password file's parent dir instead of the file itself.
        PW_DIR="$(cd "$(dirname "$VAULT_PASSWORD_FILE")" && pwd)"
        if [ "$PW_DIR" = "$VAULT_DIR" ]; then
            MOUNT_ARGS=(--mount "type=bind,source=$VAULT_DIR,target=/vault-dir")
            VAULT_PW_CONTAINER="/vault-dir/$(basename "$VAULT_PASSWORD_FILE")"
        else
            MOUNT_ARGS=(
                --mount "type=bind,source=$PW_DIR,target=/vault-pw-dir,readonly"
                --mount "type=bind,source=$VAULT_DIR,target=/vault-dir"
            )
            VAULT_PW_CONTAINER="/vault-pw-dir/$(basename "$VAULT_PASSWORD_FILE")"
        fi
        ;;
    *)
        MOUNT_ARGS=(
            -v "$VAULT_PASSWORD_FILE:/vault_password:ro"
            -v "$VAULT_DIR:/vault-dir"
        )
        VAULT_PW_CONTAINER="/vault_password"
        ;;
esac

# -i -t only when attached to a terminal (edit/rekey need a TTY; view
# doesn't). Separate flags — all three runtimes accept them, and Apple
# container's parser doesn't combine shorts.
TTY_FLAGS=""
if [ -t 0 ]; then
    TTY_FLAGS="-i -t"
fi

# shellcheck disable=SC2086
exec "$CONTAINER_RUNTIME" run --rm $TTY_FLAGS \
    "${MOUNT_ARGS[@]}" \
    -e "EDITOR=$CONTAINER_EDITOR" \
    "$ANSIBLE_IMAGE" \
    ansible-vault "$ACTION" "/vault-dir/$VAULT_NAME" --vault-password-file "$VAULT_PW_CONTAINER" \
    "${@:3}"
