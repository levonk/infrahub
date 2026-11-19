#!/usr/bin/env bash
# View an Ansible vault file inside a container — safely by default.
#
# DEFAULT MODE lists top-level variable NAMES only. Secret values are never
# printed unless you explicitly ask for them, so the output is safe to paste
# into tickets, logs, or agent transcripts.
#
# Usage:
#   scripts/view-vault.sh [vault-file]              # list variable names (default vault)
#   scripts/view-vault.sh --keys [vault-file]       # same as default
#   scripts/view-vault.sh --grep PATTERN [vault-file]  # names matching PATTERN
#   scripts/view-vault.sh --get VAR [vault-file]    # print one variable's YAML block
#   scripts/view-vault.sh --full [vault-file]       # print full decrypted YAML
#
# Options may come before or after the vault-file path.
#
# Environment overrides:
#   CONTAINER_RUNTIME     (default: first of docker, podman, container in PATH)
#   VAULT_PASSWORD_FILE   (default: ~/.ansible/vault_password)
#   ANSIBLE_IMAGE         (default: alpine/ansible:latest)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_VAULT="$REPO_ROOT/levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$HOME/.ansible/vault_password}"
ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-alpine/ansible:latest}"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- Argument parsing --------------------------------------------------------

MODE="keys"
GREP_PAT=""
GET_VAR=""
POSITIONAL=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help|help) usage; exit 0 ;;
        --keys)  MODE="keys" ;;
        --full)  MODE="full" ;;
        --grep)
            [ $# -ge 2 ] || { echo "ERROR: --grep requires a pattern" >&2; exit 1; }
            MODE="grep"; GREP_PAT="$2"; shift ;;
        --grep=*) MODE="grep"; GREP_PAT="${1#--grep=}" ;;
        --get)
            [ $# -ge 2 ] || { echo "ERROR: --get requires a variable name" >&2; exit 1; }
            MODE="get"; GET_VAR="$2"; shift ;;
        --get=*) MODE="get"; GET_VAR="${1#--get=}" ;;
        --) shift; POSITIONAL+=("$@"); break ;;
        -*) echo "ERROR: unknown option '$1'" >&2; usage >&2; exit 1 ;;
        *)  POSITIONAL+=("$1") ;;
    esac
    shift
done

VAULT_FILE="${POSITIONAL[0]:-$DEFAULT_VAULT}"

# --- Vault path resolution + submodule auto-init (same as edit-vault.sh) ------

VAULT_ABS="$VAULT_FILE"
case "$VAULT_ABS" in
    /*) ;;
    *)  VAULT_ABS="$PWD/$VAULT_FILE" ;;
esac
if [ ! -f "$VAULT_ABS" ]; then
    case "$VAULT_ABS" in
        "$REPO_ROOT"/*)
            rel="${VAULT_ABS#"$REPO_ROOT"/}"
            top="$(printf '%s' "$rel" | cut -d/ -f1)"
            sub_path="$(git -C "$REPO_ROOT" config -f .gitmodules --get "submodule.$top.path" 2>/dev/null || true)"
            if [ -n "$sub_path" ]; then
                case "$VAULT_ABS" in
                    "$REPO_ROOT/$sub_path"/*|"$REPO_ROOT/$sub_path")
                        echo "Vault file missing — initializing submodule '$top'..." >&2
                        git -C "$REPO_ROOT" submodule update --init "$top"
                        ;;
                esac
            fi
            ;;
    esac
fi

case "$VAULT_FILE" in
    /*) ;;
    *)  VAULT_FILE="$(cd "$(dirname "$VAULT_FILE")" && pwd)/$(basename "$VAULT_FILE")" ;;
esac

# --- Container runtime selection (same as edit-vault.sh) ----------------------

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
        exit 1
    fi
fi

if [ ! -f "$VAULT_PASSWORD_FILE" ]; then
    echo "ERROR: vault password file not found: $VAULT_PASSWORD_FILE" >&2
    exit 1
fi

if [ ! -f "$VAULT_FILE" ]; then
    echo "ERROR: vault file not found: $VAULT_FILE" >&2
    exit 1
fi

VAULT_DIR="$(dirname "$VAULT_FILE")"
VAULT_NAME="$(basename "$VAULT_FILE")"

case "$CONTAINER_RUNTIME" in
    podman|container)
        case "${ANSIBLE_IMAGE%%/*}" in
            *.*|*:*|localhost) ;;
            *) ANSIBLE_IMAGE="docker.io/$ANSIBLE_IMAGE" ;;
        esac
        ;;
esac

case "$CONTAINER_RUNTIME" in
    container)
        if ! container system status >/dev/null 2>&1; then
            echo "Starting Apple container service..." >&2
            container system start --enable-kernel-install
        fi
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

# --- Decrypt (stays in a shell variable; filtered before printing) -------------

DECRYPTED="$("$CONTAINER_RUNTIME" run --rm \
    "${MOUNT_ARGS[@]}" \
    "$ANSIBLE_IMAGE" \
    ansible-vault view "/vault-dir/$VAULT_NAME" --vault-password-file "$VAULT_PW_CONTAINER")"

# --- Output filtering ----------------------------------------------------------
# Top-level YAML keys only: lines starting at column 0 with name:.

TOP_KEYS="$(printf '%s\n' "$DECRYPTED" | grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*:' | tr -d ':' | sort -u)"

case "$MODE" in
    keys)
        printf '%s\n' "$TOP_KEYS" | sed '/^$/d'
        ;;
    grep)
        printf '%s\n' "$TOP_KEYS" | grep -E "$GREP_PAT" || true
        ;;
    get)
        # Print the top-level block for VAR: from '^VAR:' up to (not incl.)
        # the next top-level key. Works for scalars, nested maps, and lists.
        if ! printf '%s\n' "$DECRYPTED" | grep -qE "^${GET_VAR}:"; then
            echo "ERROR: variable '$GET_VAR' not found in $VAULT_NAME" >&2
            exit 1
        fi
        printf '%s\n' "$DECRYPTED" | awk -v k="$GET_VAR" '
            $0 ~ "^" k ":" { p=1 }
            p && $0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*:/ && $0 !~ "^" k ":" { exit }
            p { print }
        '
        ;;
    full)
        printf '%s\n' "$DECRYPTED"
        ;;
esac
