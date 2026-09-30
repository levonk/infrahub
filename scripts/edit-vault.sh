#!/usr/bin/env bash
# Edit (or view/create/rekey) an Ansible vault file inside a Docker container.
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

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found in PATH" >&2
    exit 1
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

# -it only when attached to a terminal (edit/rekey need a TTY; view doesn't).
TTY_FLAGS=""
if [ -t 0 ]; then
    TTY_FLAGS="-it"
fi

# shellcheck disable=SC2086
exec docker run --rm $TTY_FLAGS \
    -v "$VAULT_PASSWORD_FILE:/vault_password:ro" \
    -v "$VAULT_DIR:/vault-dir" \
    -e "EDITOR=$CONTAINER_EDITOR" \
    "$ANSIBLE_IMAGE" \
    ansible-vault "$ACTION" "/vault-dir/$VAULT_NAME" --vault-password-file /vault_password \
    "${@:3}"
