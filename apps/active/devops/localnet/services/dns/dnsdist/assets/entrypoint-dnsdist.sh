#!/usr/bin/env bash
# Shellcheck bash
# Entrypoint script for dnsdist container.
# Substitutes environment variables (including dynamically generated hashes) into the config file and starts dnsdist.

set -uo pipefail

BASE_CONFIG_PATH="/etc/dnsdist"
TEMPLATE_CONFIG_NAME="dnsdist"
# Construct template filename by appending .template
TEMPLATE_FILE="/templates${BASE_CONFIG_PATH}/${TEMPLATE_CONFIG_NAME}.conf.template"
DEST_CONFIG_FILE="${BASE_CONFIG_PATH}/dnsdist.conf"

echo "[ENTRYPOINT] Starting dnsdist entrypoint script" >&2

# Export defaults
export DNS_DNSDIST_MAIN_CONTAINER_PORT="${DNS_DNSDIST_MAIN_CONTAINER_PORT:-53}"
export DNS_DNSDIST_HEALTHCHECK_CONTAINER_PORT="${DNS_DNSDIST_HEALTHCHECK_CONTAINER_PORT:-5353}"

# Verify template file exists
if [ ! -r "$TEMPLATE_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Template file not found at $TEMPLATE_FILE" >&2 || true
  exit 1
fi

echo "[ENTRYPOINT] Environment variables for substitution:" >&2
echo "[ENTRYPOINT]   DNS_DNSDIST_MAIN_CONTAINER_PORT=${DNS_DNSDIST_MAIN_CONTAINER_PORT}" >&2

# Initialize sed_expressions array. We will add hashed placeholders first.
sed_expressions=()

# Function to generate hash and add to sed_expressions array
generate_and_add_hash() {
    local ENV_VAR_NAME="$1"
    local TEMPLATE_PLACEHOLDER="$2"
	echo "Processing ENV_VAR_NAME |$ENV_VAR_NAME|" >&2
	echo "Processing TEMPLATE_PLACEHOLDER |$TEMPLATE_PLACEHOLDER|" >&2

    # Get the value, defaulting to empty if not set
    local PLAIN_TEXT_VALUE="${!ENV_VAR_NAME:-}"
	echo "Processing PLAIN_TEXT_VALUE |$PLAIN_TEXT_VALUE|" >&2

    if [ -n "${PLAIN_TEXT_VALUE}" ]; then
        echo "[ENTRYPOINT] Generating HASH for ENV_VAR_NAME |${ENV_VAR_NAME}|..." >&2

        # CRITICAL FIX: Pass the hash command as a single argument and strip ONLY newlines/CR
        # We rely on the hash being generated correctly and ONLY outputting the hash string.
        HASHED_VALUE=$(/usr/bin/dnsdist --disable-syslog --config="" --execute "print(hashPassword(\"${PLAIN_TEXT_VALUE}\"))" 2>/dev/null | tr -d '\r\n')

        if [ -z "$HASHED_VALUE" ] || [[ "$HASHED_VALUE" == dnsdist* ]]; then
            echo "[ENTRYPOINT]ERROR: Failed to generate hash for ENV_VAR_NAME |${ENV_VAR_NAME}|. Check if password is empty or if dnsdist version is too old." >&2
            echo "[ENTRYPOINT]Attempted output HASHED_VALUE: |${HASHED_VALUE}|" >&2
            exit 1
        fi

        echo "[ENTRYPOINT] Substitution: TEMPLATE PLACEHOLDER |${TEMPLATE_PLACEHOLDER}| set to hash." >&2
        sed_expressions+=(-e "s|${TEMPLATE_PLACEHOLDER}|${HASHED_VALUE}|g")
    else
        echo "[ENTRYPOINT]WARNING: ENV_VAR_NAME |${ENV_VAR_NAME}| not set. Placeholder TEMPLATE_PLACEHOLDER |${TEMPLATE_PLACEHOLDER}| will be left un-substituted." >&2
    fi
}

# Generate hashes for required secrets using their expected ENV VAR names
generate_and_add_hash "DNS_DNSDIST_CONTROL_PASSWORD" "{DNS_DNSDIST_CONTROL_PASSWORD_HASH}"
generate_and_add_hash "DNS_DNSDIST_WEB_PASSWORD" "{DNS_DNSDIST_WEB_PASSWORD_HASH}"
generate_and_add_hash "DNS_DNSDIST_WEB_API_KEY" "{DNS_DNSDIST_WEB_API_KEY_HASH}"

# --- DYNAMIC HASH GENERATION END ---

# Enumerate standard env vars and build remaining sed expressions
sed_expressions_standard=()

# Enumerate env vars and build sed expressions
while IFS='=' read -r name value; do
  if [[ "$name" == DNS_* || "$name" == DNSDIST_* ]]; then
    # Skip variables we manually processed via hash generation
    if ! [[ "$name" == *PASSWORD* || "$name" == *API_KEY* ]]; then
        # Escape for sed replacement: backslash, ampersand, and our '|' delimiter
        value_escaped=${value//\\/\\\\}
        value_escaped=${value_escaped//&/\\&}
        value_escaped=${value_escaped//|/\\|}
        echo "[ENTRYPOINT] Substituting ${name}=${value}" >&2
        sed_expressions_standard+=(-e "s|{${name}}|${value_escaped}|g")
    fi
  fi
done < <(env)

# Combine the manually created hash substitutions with the standard substitutions
all_sed_expressions=("${sed_expressions[@]}" "${sed_expressions_standard[@]}")

# Function to expand templates and copy files
# Usage: expand_templates <source_dir> <dest_dir>
expand_templates() {
    local src_dir="$1"
    local dest_dir="$2"

    # Process all files in source directory recursively
    find "$src_dir" -type f | while read -r src_file; do
        # Get relative path
        local rel_path="${src_file#$src_dir/}"
        local dest_file="$dest_dir/$rel_path"

        # Create destination directory
        mkdir -p "$(dirname "$dest_file")"

        # Process .template files
        if [[ "$src_file" == *.template ]]; then
            # Remove .template extension
            dest_file="${dest_file%.template}"
            echo "Expanding template: $src_file -> $dest_file"
            envsubst < "$src_file" > "$dest_file"
            chmod 644 "$dest_file"
        else
            # Copy non-template files directly
            echo "Copying file: $src_file -> $dest_file"
            cp "$src_file" "$dest_file"
            chmod 644 "$dest_file"
        fi
    done
}

# Generate configuration files from templates
echo "Expanding templates for dnsdist configuration..."
expand_templates "/templates/etc/dnsdist" "/etc/dnsdist"

# Substitute all variables in one pass
if [ ${#all_sed_expressions[@]} -gt 0 ]; then
    sed "${all_sed_expressions[@]}" "$TEMPLATE_FILE" > "$DEST_CONFIG_FILE" || true
else
    cp "$TEMPLATE_FILE" "$DEST_CONFIG_FILE" || true
fi

# Verify config file exists
if [ ! -r "$DEST_CONFIG_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Config file not found at $DEST_CONFIG_FILE" >&2 || true
  exit 1
fi

echo "[ENTRYPOINT] Config ready, checking syntax and starting dnsdist..." >&2
# Check config syntax first.
/usr/bin/dnsdist --config ${DEST_CONFIG_FILE} --check-config || { echo "[ENTRYPOINT]ERROR: dnsdist configuration check failed." >&2; exit 1; }
# Wiat for a few secons to ensure upstream is ready
sleep 30
# Start dnsdist
/usr/bin/dnsdist --supervised --config "${DEST_CONFIG_FILE}"
retCode=$?
echo "[ENTRYPOINT] dnsdist exit code: |${retCode}|" >&2
exit "${retCode}"
