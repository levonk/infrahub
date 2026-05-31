#!/usr/bin/env bash
set -euo pipefail

# client-init.sh
# Initializes the private levonk submodule and creates the template directory
# structure for personal overlays. Safe to run multiple times.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SUBMODULE_NAME="levonk"
SUBMODULE_PATH="${REPO_ROOT}/${SUBMODULE_NAME}"

echo "=== Infrahub Client Init ==="
echo "Repo root: ${REPO_ROOT}"

# --- 1. Initialize submodule ---
if [ -d "${SUBMODULE_PATH}/.git" ]; then
    echo "Submodule '${SUBMODULE_NAME}' already present. Updating..."
    git -C "${REPO_ROOT}" submodule update --init --recursive "${SUBMODULE_NAME}"
else
    echo "Initializing submodule '${SUBMODULE_NAME}'..."
    git -C "${REPO_ROOT}" submodule update --init --recursive "${SUBMODULE_NAME}"
fi

if [ ! -d "${SUBMODULE_PATH}" ]; then
    echo "ERROR: Submodule '${SUBMODULE_NAME}' not found at ${SUBMODULE_PATH}"
    echo "Ensure .gitmodules is configured and the private repo is accessible."
    exit 1
fi

echo "Submodule ready: ${SUBMODULE_PATH}"

# --- 2. Create template directory structure ---
echo "Creating template directory structure under ${SUBMODULE_PATH}..."

# Mirror shared/active structure
declare -a DIRS=(
    "active/00-os"
    "active/01-build"
    "active/02-config/ansible/inventories"
    "active/02-config/ansible/host_vars"
    "active/03-container/services"
    "active/04-deploy"
    "active/05-gitops/flux"
    "active/05-gitops/platform"
    "active/05-gitops/policy"
    "active/05-gitops/secrets"
    "active/06-provision/pulumi"
    "active/07-local/vagrant"
    "active/08-docs/adr"
    "active/08-docs/architecture"
    "active/08-docs/diagrams"
    "active/08-docs/postmortems"
    "active/08-docs/reqs"
    "active/08-docs/runbooks"
    "active/08-docs/security"
)

for d in "${DIRS[@]}"; do
    target="${SUBMODULE_PATH}/${d}"
    if [ ! -d "${target}" ]; then
        mkdir -p "${target}"
        echo "  created: ${d}"
    fi
done

# --- 3. Add .gitkeep to preserve empty directories ---
echo "Adding .gitkeep placeholders..."
find "${SUBMODULE_PATH}/active" -type d -empty | while read -r dir; do
    touch "${dir}/.gitkeep"
done

# --- 4. Add .gitignore for private data ---
GITIGNORE="${SUBMODULE_PATH}/.gitignore"
if [ ! -f "${GITIGNORE}" ]; then
    cat > "${GITIGNORE}" <<'EOF'
# Private data — never commit secrets or real host IPs
*.vault
*.key
*.pem
*.crt
vault_password
.env
.env.*
EOF
    echo "  created: .gitignore"
fi

# --- 5. Add README ---
README="${SUBMODULE_PATH}/README.md"
if [ ! -f "${README}" ] || [ "$(wc -c < "${README}" | tr -d ' ')" -lt 100 ]; then
    cat > "${README}" <<'EOF'
# Private Infra Overlay

This directory contains personal/private infrastructure content that overlays the
public `shared/` tree in the parent repo.

## Directory Layout

Mirrors `shared/active/` so private inventory, host_vars, secrets, and local
deploy configs can live here without exposing them in the public repository.

## Usage

Ansible playbooks reference this overlay via:

```bash
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/production.yml \
  shared/active/02-config/ansible/playbooks/site.yml
```

## Rules

- Never commit secrets, real host IPs, or credentials.
- Use `ansible-vault` for sensitive variables.
- Keep this repo private.
EOF
    echo "  created: README.md"
fi

# --- 6. Add sample inventory template ---
SAMPLE_INV="${SUBMODULE_PATH}/active/02-config/ansible/inventories/production.yml"
if [ ! -f "${SAMPLE_INV}" ]; then
    cat > "${SAMPLE_INV}" <<'EOF'
---
# Production inventory template
# Copy and edit this file for real hosts. Never commit real IPs publicly.
all:
  children:
    localnet_hosts:
      hosts:
        localnet-primary:
          ansible_host: "{{ ansible_host_ip }}"
          ansible_user: admin
          ansible_ssh_private_key_file: ~/.ssh/localnet
      vars:
        localnet_base_dir: "{{ ansible_env.HOME }}/localnet"
EOF
    echo "  created: sample inventory (active/02-config/ansible/inventories/production.yml)"
fi

echo ""
echo "Done. Review and commit changes in the private repo:"
echo "  cd ${SUBMODULE_PATH}"
echo "  git add ."
echo "  git commit -m 'chore: init template structure'"
