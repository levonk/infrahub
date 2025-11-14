#!/usr/bin/env bash
# Shellcheck bash
# Entrypoint script for verdaccio container.
# Substitutes environment variables (including dynamically generated hashes) into the config file and starts verdaccio.

set -uo pipefail

BASE_CONFIG_PATH="/verdaccio/conf"
TEMPLATE_CONFIG_NAME="config.yaml"
# Construct template filename by appending .template
TEMPLATE_PATH="/templates${BASE_CONFIG_PATH}"
TEMPLATE_FILE="${TEMPLATE_PATH}/${TEMPLATE_CONFIG_NAME}.template"
DEST_CONFIG_FILE="${BASE_CONFIG_PATH}/${TEMPLATE_CONFIG_NAME}"

echo "[ENTRYPOINT] Starting verdaccio entrypoint script" >&2

# Export defaults
export ARTIFACT_VERDACCIO_CONTAINER_PORT="${ARTIFACT_VERDACCIO_CONTAINER_PORT:-4873}"

# Verify template file exists
if [ ! -r "$TEMPLATE_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Template file not found at $TEMPLATE_FILE" >&2 || true
  exit 1
fi

echo "[ENTRYPOINT] Environment variables for substitution:" >&2
echo "[ENTRYPOINT]   ARTIFACT_VERDACCIO_CONTAINER_PORT=${ARTIFACT_VERDACCIO_CONTAINER_PORT}" >&2

# Initialize sed_expressions array. We will add hashed placeholders first.
sed_expressions=()

# --- DYNAMIC HASH GENERATION END ---

# Enumerate standard env vars and build remaining sed expressions
sed_expressions_standard=()

# Enumerate env vars and build sed expressions
while IFS='=' read -r name value; do
  if [[ "$name" == ARTIFACT_VERDACCIO_* ]]; then
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
            echo "[ENTRYPOINT] Expanding template with sed: $src_file -> $dest_file"
            if [ ${#all_sed_expressions[@]} -gt 0 ]; then
                sed "${all_sed_expressions[@]}" "$src_file" > "$dest_file"
            else
                cp "$src_file" "$dest_file"
            fi
        else
            # Copy non-template files directly
            echo "[ENTRYPOINT] Copying file: $src_file -> $dest_file"
            cp "$src_file" "$dest_file"
        fi
		chmod 644 "$dest_file"
    done
}

# Generate configuration files from templates
echo "[ENTRYPOINT] Expanding templates for verdaccio configuration..."
expand_templates "${TEMPLATE_PATH}" "${BASE_CONFIG_PATH}"


# Verify config file exists
if [ ! -r "$DEST_CONFIG_FILE" ]; then
  echo "[ENTRYPOINT]ERROR: Config file not found at $DEST_CONFIG_FILE" >&2 || true
  exit 1
fi

echo "[ENTRYPOINT] Config ready, checking syntax and starting verdaccio..." >&2
# Check config syntax first.
yamllint --config-data "{rules: {line-length: disable}}" ${DEST_CONFIG_FILE}

# If running as root, fix ownership on bind-mounted data dir, then drop privileges.
if [ "$(id -u)" -eq 0 ]; then
  echo "[ENTRYPOINT] Running as root; ensuring /verdaccio-data ownership and permissions" >&2
  if [ -d "/verdaccio-data" ]; then
    chown -R verdaccio:node /verdaccio-data || true
    chmod -R 775 /verdaccio-data || true
  else
    echo "[ENTRYPOINT] WARN: /verdaccio-data does not exist yet; skipping chown" >&2
  fi

  # Prefer su-exec or gosu to drop privileges cleanly; fallback to runuser
  if command -v su-exec >/dev/null 2>&1; then
    exec su-exec verdaccio:node /opt/verdaccio/docker-bin/uid_entrypoint /usr/local/bin/verdaccio --config ${DEST_CONFIG_FILE}
  elif command -v gosu >/dev/null 2>&1; then
    exec gosu verdaccio:node /opt/verdaccio/docker-bin/uid_entrypoint /usr/local/bin/verdaccio --config ${DEST_CONFIG_FILE}
  else
    # Fallback: runuser (may require util-linux)
    exec runuser -u verdaccio -- /opt/verdaccio/docker-bin/uid_entrypoint /usr/local/bin/verdaccio --config ${DEST_CONFIG_FILE}
  fi
fi

# Non-root: just exec directly (uid_entrypoint will respect current user)
exec /opt/verdaccio/docker-bin/uid_entrypoint /usr/local/bin/verdaccio --config ${DEST_CONFIG_FILE}
