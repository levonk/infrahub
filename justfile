# Root justfile for infrahub
# Follows ADR-20260131001: direnv -> devbox -> just (*-internal)
# Orchestrates: Ansible, Docker, Packer, and LocalNet workflows

set export

# === Configuration ===
INFRAHUB_ROOT := justfile_directory()
ANSIBLE_ROOT := INFRAHUB_ROOT + "/shared/active/02-config/ansible"
CONTAINER_ROOT := INFRAHUB_ROOT + "/shared/active/03-container"
INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/oci.yml"
LOCALNET_INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/localnet.yml"
GROUP_VARS := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/group_vars"
PACKER_DIR := INFRAHUB_ROOT + "/shared/active/01-build/packer"
MOLECULE_DIR := ANSIBLE_ROOT + "/roles"

# Ansible playbooks
PB_BOOTSTRAP := ANSIBLE_ROOT + "/playbooks/cloud-server-bootstrap.yml"
PB_VPN := ANSIBLE_ROOT + "/playbooks/cloud-server-vpn.yml"
PB_NORDVPN := ANSIBLE_ROOT + "/playbooks/cloud-server-nordvpn.yml"
PB_INFRA := ANSIBLE_ROOT + "/playbooks/cloud-server-infra.yml"
PB_VMS := ANSIBLE_ROOT + "/playbooks/cloud-server-vms.yml"
PB_SITE := ANSIBLE_ROOT + "/playbooks/cloud-server-site.yml"
PB_LOCALNET_TAILSCALE := ANSIBLE_ROOT + "/playbooks/localnet-tailscale.yml"
PB_AI_INFERENCE := ANSIBLE_ROOT + "/playbooks/bootstrap-ai-inference-host.yml"

# Validation playbooks
PB_VAL_BOOTSTRAP := ANSIBLE_ROOT + "/playbooks/validate-bootstrap.yml"
PB_VAL_VPN := ANSIBLE_ROOT + "/playbooks/validate-vpn.yml"
PB_VAL_INFRA := ANSIBLE_ROOT + "/playbooks/validate-infra.yml"
PB_VAL_VMS := ANSIBLE_ROOT + "/playbooks/validate-vms.yml"
PB_FINAL_AUDIT := ANSIBLE_ROOT + "/playbooks/final-audit.yml"

# Docker commands for Ansible test containers
ANSIBLE_TEST_IMAGE := "ansible-test-runner:latest"
ANSIBLE_TEST_CONTAINER := "ansible-test-env"

# === Default recipe ===
default:
    @just --list

# === Bootstrap & Environment ===

bootstrap:
    devbox run bootstrap-internal

bootstrap-internal:
    @echo "Bootstrapping infrahub environment..."
    just setup-internal
    just prime-internal
    @echo "Bootstrap complete."

prime:
    devbox run prime-internal

prime-internal:
    @echo "Priming code indexing..."
    @echo "Prime complete."

doctor:
    devbox run doctor-internal

doctor-internal:
    @echo "Checking environment health..."
    ansible --version || echo "ansible: NOT FOUND"
    ansible-lint --version || echo "ansible-lint: NOT FOUND"
    molecule --version || echo "molecule: NOT FOUND"
    packer --version || echo "packer: NOT FOUND"
    docker --version || echo "docker: NOT FOUND"
    just --version || echo "just: NOT FOUND"
    devbox version || echo "devbox: NOT FOUND"
    @echo "Environment check complete."

setup:
    devbox run setup-internal

setup-internal:
    @echo "Setting up infrahub directories..."
    @mkdir -p {{ANSIBLE_ROOT}}/roles
    @mkdir -p {{ANSIBLE_ROOT}}/playbooks
    @mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories
    @mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/host_vars
    @mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/group_vars
    @mkdir -p {{PACKER_DIR}}
    @mkdir -p {{INFRAHUB_ROOT}}/logs
    @echo "Directory structure ready."

# === Skill Bootstrap ===

# Install the execute-upsert skill from levonk/skills-releases
# Required by infrahub-add-new-service-orchestrator.md workflow for the PRD → tasks → execute pipeline
skills-bootstrap:
    @echo "Installing execute-upsert skill from levonk/skills-releases..."
    npx skills add levonk/skills-releases --skill execute-upsert
    @echo "Skill bootstrap complete."

# === Standard Quality Gates ===

build:
    devbox run build-internal

build-internal:
    @echo "Building all infrahub components..."
    @echo "(Add component-specific build steps here)"

# === Docker Image Build & Push (Invariant #2: build locally → push to registry → pull on target) ===

# Build and push all locally-built images to the OCI registry (skips unchanged)
docker-build-push-all:
    devbox run docker-build-push-all-internal

docker-build-push-all-internal:
    @echo "Building and pushing all images to local registry..."
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh

# Force rebuild and push all images (ignores cache)
docker-build-push-all-force:
    devbox run docker-build-push-all-force-internal

docker-build-push-all-force-internal:
    @echo "Force rebuilding and pushing all images to local registry..."
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh --force

# Build and push a single image (e.g., just docker-build-push headroom)
docker-build-push image:
    devbox run docker-build-push-internal {{image}}

docker-build-push-internal image:
    @echo "Building and pushing '{{image}}' to local registry..."
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh {{image}}

# List all images that can be built and pushed
docker-build-list:
    devbox run docker-build-list-internal

docker-build-list-internal:
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh --list

test:
    devbox run test-internal

test-internal:
    @echo "Running all tests..."
    just ansible-test-internal

lint:
    devbox run lint-internal

lint-internal:
    @echo "Running all lints..."
    just ansible-lint-internal
    just ps-lint-internal

quality:
    devbox run quality-internal

quality-internal:
    just lint
    just test

# === Ansible Lifecycle Commands ===

# -- Lint & Syntax Check --

ansible-lint:
    devbox run ansible-lint-internal

ansible-lint-internal:
    @echo "Running ansible-lint across roles and playbooks..."
    ansible-lint {{ANSIBLE_ROOT}}/roles/ {{ANSIBLE_ROOT}}/playbooks/ || true
    @echo "ansible-lint complete."

ansible-syntax:
    devbox run ansible-syntax-internal

ansible-syntax-internal:
    @echo "Checking playbook syntax..."
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_BOOTSTRAP}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_VPN}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_INFRA}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_VMS}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_SITE}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_BOOTSTRAP}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WORLDMONITOR}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_BASE_DEV}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_RUSTFS}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_WAZUH}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_CROC_RELAY}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_LOCAL_REGISTRY}} || true
    ansible-playbook --syntax-check -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} || true
    ansible-playbook --syntax-check -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_HARDEN}} || true
    ansible-playbook --syntax-check -i {{LOCALNET_INVENTORY}} {{PB_LOCALNET_TAILSCALE}} || true
    ansible-playbook --syntax-check -i {{LOCALNET_INVENTORY}} {{PB_AI_INFERENCE}} || true
    @echo "Syntax check complete."

# -- Molecule Tests (Docker-backed) --

ansible-test:
    devbox run ansible-test-internal

ansible-test-internal:
    @echo "Running Molecule tests for all roles..."
    @for role_dir in {{MOLECULE_DIR}}/*/; do \
        role_name=$$(basename "$$role_dir"); \
        if [ -d "$$role_dir/molecule" ]; then \
            echo "Testing role: $$role_name"; \
            (cd "$$role_dir" && molecule test) || echo "Molecule test failed for $$role_name"; \
        else \
            echo "No molecule tests for $$role_name"; \
        fi; \
    done
    @echo "Molecule tests complete."

molecule-test role:
    devbox run molecule-test-internal {{role}}

molecule-test-internal role:
    @echo "Running Molecule test for role: {{role}}..."
    cd {{MOLECULE_DIR}}/{{role}} && molecule test

molecule-converge role:
    devbox run molecule-converge-internal

molecule-converge-internal role:
    @echo "Running Molecule converge for role: {{role}}..."
    cd {{MOLECULE_DIR}}/{{role}} && molecule converge

molecule-destroy role:
    @echo "Destroying Molecule environment for role: {{role}}..."
    cd {{MOLECULE_DIR}}/{{role}} && molecule destroy

molecule-verify role:
    @echo "Running Molecule verify for role: {{role}}..."
    cd {{MOLECULE_DIR}}/{{role}} && molecule verify

# -- Docker-based Molecule Tests (bypass Nix dependency issues) --

MOLECULE_DOCKER_IMAGE := "molecule-test-runner:latest"
MOLECULE_DOCKER_CONTAINER := "molecule-test-env"
MOLECULE_DOCKERFILE := CONTAINER_ROOT + "/Dockerfile.molecule"

molecule-docker-build:
    @echo "Building Molecule Docker image..."
    docker build -t {{MOLECULE_DOCKER_IMAGE}} -f {{MOLECULE_DOCKERFILE}} {{CONTAINER_ROOT}}

molecule-docker-test role:
    @echo "Running Molecule test for role: {{role}} in Docker container..."
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule test"

molecule-docker-converge role:
    @echo "Running Molecule converge for role: {{role}} in Docker container..."
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule converge"

molecule-docker-verify role:
    @echo "Running Molecule verify for role: {{role}} in Docker container..."
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule verify"

molecule-docker-destroy role:
    @echo "Destroying Molecule environment for role: {{role}} in Docker container..."
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule destroy"

molecule-docker-shell:
    @echo "Starting interactive shell in Molecule Docker container..."
    docker run --rm -it \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash

# -- Docker Test Environment for Ansible --

ansible-test-env-build:
    @echo "Building Ansible test Docker image..."
    docker build -t {{ANSIBLE_TEST_IMAGE}} -f {{ANSIBLE_ROOT}}/Dockerfile.test {{ANSIBLE_ROOT}} || echo "No Dockerfile.test found; using default image"

ansible-test-env-run:
    @echo "Starting Ansible test container..."
    docker run -d --name {{ANSIBLE_TEST_CONTAINER}} \
        --rm \
        -v {{ANSIBLE_ROOT}}:/ansible:ro \
        -v {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible:/ansible/inventories:ro \
        {{ANSIBLE_TEST_IMAGE}} tail -f /dev/null || echo "Test container start failed"

ansible-test-env-exec cmd="ansible-playbook":
    @echo "Executing in test container: {{cmd}}..."
    docker exec -it {{ANSIBLE_TEST_CONTAINER}} {{cmd}}

ansible-test-env-stop:
    @echo "Stopping Ansible test container..."
    docker stop {{ANSIBLE_TEST_CONTAINER}} || true
    docker rm {{ANSIBLE_TEST_CONTAINER}} || true

# -- Deploy Playbooks --

ansible-deploy-bootstrap:
    devbox run ansible-deploy-bootstrap

ansible-deploy-bootstrap-internal:
    @echo "Deploying bootstrap playbook..."
    ansible-playbook -i {{INVENTORY}} {{PB_BOOTSTRAP}}

ansible-deploy-vpn:
    devbox run ansible-deploy-vpn

ansible-deploy-vpn-internal:
    @echo "Deploying VPN playbook..."
    ansible-playbook -i {{INVENTORY}} {{PB_VPN}} --ask-vault-pass

ansible-deploy-nordvpn:
    devbox run ansible-deploy-nordvpn

ansible-deploy-nordvpn-internal:
    @echo "Deploying NordVPN playbook..."
    bash scripts/deploy-nordvpn.sh

ansible-deploy-infra:
    devbox run ansible-deploy-infra

ansible-deploy-infra-internal:
    @echo "Deploying infrastructure playbook..."
    ansible-playbook -i {{INVENTORY}} {{PB_INFRA}}

ansible-deploy-vms:
    devbox run ansible-deploy-vms

ansible-deploy-vms-internal:
    @echo "Deploying VM playbook..."
    ansible-playbook -i {{INVENTORY}} {{PB_VMS}}

ansible-deploy-site:
    devbox run ansible-deploy-site

ansible-deploy-site-internal:
    @echo "Deploying site playbook (full stack)..."
    ansible-playbook -i {{INVENTORY}} {{PB_SITE}}
    @echo "Regenerating service catalog..."
    just generate-service-catalog-internal

# -- Local Network Deployment --

ansible-deploy-localnet-tailscale:
    devbox run ansible-deploy-localnet-tailscale

ansible-deploy-localnet-tailscale-internal:
    @echo "Deploying Tailscale to local network hosts..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_LOCALNET_TAILSCALE}} --ask-vault-pass

# -- Windows Docker Desktop Deployment --

WINDOWS_DOCKER_INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/windows-docker.yml"
PB_WINDOWS_BOOTSTRAP := ANSIBLE_ROOT + "/playbooks/bootstrap-windows-docker-host.yml"
PB_WINDOWS_HARDEN := ANSIBLE_ROOT + "/playbooks/harden-windows-host.yml"
PB_WORLDMONITOR := ANSIBLE_ROOT + "/playbooks/deploy-worldmonitor.yml"
PB_BASE_DEV := ANSIBLE_ROOT + "/playbooks/deploy-base-dev.yml"
PB_RUSTFS := ANSIBLE_ROOT + "/playbooks/deploy-rustfs.yml"
PB_CROC_RELAY := ANSIBLE_ROOT + "/playbooks/deploy-croc-relay.yml"
PB_WAZUH := ANSIBLE_ROOT + "/playbooks/deploy-wazuh.yml"
PB_LOCAL_REGISTRY := ANSIBLE_ROOT + "/playbooks/deploy-local-registry.yml"

ansible-deploy-local-registry:
    devbox run ansible-deploy-local-registry

ansible-deploy-local-registry-internal:
    @echo "Deploying local Docker registry on OCI cloud server..."
    ansible-playbook -i {{INVENTORY}} {{PB_LOCAL_REGISTRY}} --vault-password-file ~/.ansible/vault_password

ansible-bootstrap-windows-docker:
    devbox run ansible-bootstrap-windows-docker

ansible-bootstrap-windows-docker-internal:
    @echo "Bootstrapping Windows Docker host (WSL2, Docker Desktop, Git, Tailscale, registry config)..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_BOOTSTRAP}} --vault-password-file ~/.ansible/vault_password

ansible-harden-windows:
    devbox run ansible-harden-windows

ansible-harden-windows-internal:
    @echo "Hardening Windows host (SSH config, authorized_keys ACL, RDP, scheduled drift check)..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_HARDEN}} --vault-password-file ~/.ansible/vault_password

ansible-harden-windows-check:
    @echo "Dry-run Windows hardening (check mode)..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_HARDEN}} --check --diff --vault-password-file ~/.ansible/vault_password

ansible-deploy-croc-relay:
    devbox run ansible-deploy-croc-relay

ansible-deploy-croc-relay-internal:
    @echo "Deploying Croc relay on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_CROC_RELAY}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-croc-relay-check:
    @echo "Dry-run Croc relay deployment (check mode)..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_CROC_RELAY}} --check --diff --vault-password-file ~/.ansible/vault_password

# -- Hosts-file blocklist (IP-logger/tracker/grabber sinkhole) --

# Deploy the hosts-file blocklist to ALL machines in the levonk inventory
# (OCI cloud server, isolation VMs, localnet hosts, AI inference host, Windows Docker hosts, macOS hosts).
# Uses --tags hosts-blocklist so only the blocklist role runs, skipping everything else.
ansible-deploy-hosts-blocklist:
    devbox run ansible-deploy-hosts-blocklist-internal

ansible-deploy-hosts-blocklist-internal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Deploying hosts-file blocklist to all levonk machines..."
    echo "  → OCI cloud server + isolation VMs (Oracle Linux)..."
    ansible-playbook -i {{INVENTORY}} {{PB_BOOTSTRAP}} --tags hosts-blocklist --vault-password-file ~/.ansible/vault_password
    echo "  → Localnet hosts (Linux)..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_LOCALNET_TAILSCALE}} --tags hosts-blocklist --ask-vault-pass
    echo "  → AI inference host / kckinai (NVIDIA Linux)..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_AI_INFERENCE}} --tags hosts-blocklist --limit kckinai --ask-vault-pass
    echo "  → Windows Docker hosts..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_HARDEN}} --tags hosts-blocklist --vault-password-file ~/.ansible/vault_password
    echo "  → macOS hosts..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} --tags hosts-blocklist --vault-password-file ~/.ansible/vault_password --ask-become-pass
    echo "Hosts-file blocklist deployed to all machines."

# Dry-run the hosts-file blocklist deployment (check mode, no changes)
ansible-deploy-hosts-blocklist-check:
    devbox run ansible-deploy-hosts-blocklist-check-internal

ansible-deploy-hosts-blocklist-check-internal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Dry-run hosts-file blocklist deployment (check mode)..."
    echo "  → OCI cloud server + isolation VMs (Oracle Linux)..."
    ansible-playbook -i {{INVENTORY}} {{PB_BOOTSTRAP}} --tags hosts-blocklist --check --diff --vault-password-file ~/.ansible/vault_password
    echo "  → Localnet hosts (Linux)..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_LOCALNET_TAILSCALE}} --tags hosts-blocklist --check --diff --ask-vault-pass
    echo "  → AI inference host / kckinai (NVIDIA Linux)..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_AI_INFERENCE}} --tags hosts-blocklist --check --diff --limit kckinai --ask-vault-pass
    echo "  → Windows Docker hosts..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WINDOWS_HARDEN}} --tags hosts-blocklist --check --diff --vault-password-file ~/.ansible/vault_password
    echo "  → macOS hosts..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} --tags hosts-blocklist --check --diff --vault-password-file ~/.ansible/vault_password --ask-become-pass
    echo "Dry-run complete."

# === PowerShell Lint ===

ps-lint:
    devbox run -- just ps-lint-internal

ps-lint-internal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running PSScriptAnalyzer on all .ps1 files..."
    pwsh -NoProfile -File "{{INFRAHUB_ROOT}}/shared/scripts/ps-lint.ps1" "{{INFRAHUB_ROOT}}"
    echo "PSScriptAnalyzer complete."

ansible-deploy-worldmonitor:
    devbox run ansible-deploy-worldmonitor

ansible-deploy-worldmonitor-internal:
    @echo "Building images on Mac, pushing to registry, deploying on Windows..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WORLDMONITOR}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-worldmonitor-check:
    @echo "Dry-run WorldMonitor deployment (check mode)..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_WORLDMONITOR}} --check --diff --vault-password-file ~/.ansible/vault_password

ansible-deploy-base-dev:
    devbox run ansible-deploy-base-dev

ansible-deploy-base-dev-internal:
    @echo "Building base-dev image on Mac, pushing to registry, deploying on Windows..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} {{PB_BASE_DEV}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-rustfs:
    devbox run ansible-deploy-rustfs

ansible-deploy-rustfs-internal:
    @echo "Deploying RustFS to Windows Docker host and Traefik on OCI..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_RUSTFS}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-rustfs-check:
    @echo "Dry-run RustFS deployment (check mode) on Windows Docker host and OCI..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_RUSTFS}} --check --diff --vault-password-file ~/.ansible/vault_password

# -- Wazuh SIEM/XDR Deployment --

ansible-deploy-wazuh:
    devbox run ansible-deploy-wazuh

ansible-deploy-wazuh-internal:
    @echo "Deploying Wazuh SIEM/XDR to Windows Docker host and Traefik on OCI..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_WAZUH}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-wazuh-check:
    @echo "Dry-run Wazuh deployment (check mode) on Windows Docker host and OCI..."
    ansible-playbook -i {{WINDOWS_DOCKER_INVENTORY}} -i {{INVENTORY}} {{PB_WAZUH}} --check --diff --vault-password-file ~/.ansible/vault_password

# -- macOS Host Deployment --

MACOS_INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/macos-hosts.yml"
PB_MACOS_BOOTSTRAP := ANSIBLE_ROOT + "/playbooks/bootstrap-macos-host.yml"

ansible-bootstrap-macos:
    devbox run ansible-bootstrap-macos-internal

ansible-bootstrap-macos-internal:
    @echo "Bootstrapping macOS host (Nix, Homebrew, OrbStack, apps, Tailscale, Netbird)..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} --vault-password-file ~/.ansible/vault_password --ask-become-pass

ansible-bootstrap-macos-check:
    @echo "Dry-run macOS bootstrap (check mode)..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} --check --diff --vault-password-file ~/.ansible/vault_password --ask-become-pass

# Run the manual bootstrap script on a target Mac (run ON the target, not control machine)
# Uses embedded default key (lzkmbp2016-micro-oracle); override with --ssh-key <path>
# Usage: just macos-manual-bootstrap
macos-manual-bootstrap *ARGS:
    @echo "Running manual bootstrap script..."
    bash {{INFRAHUB_ROOT}}/shared/scripts/bootstrap-macos-manual.sh {{ARGS}}

# Run the manual bootstrap script on a target Windows machine (run ON the target, not control machine)
# Uses embedded default key (lzkmbp2016-micro-oracle); override with -SshKey <path>
# Usage: just windows-manual-bootstrap
windows-manual-bootstrap *ARGS:
    @echo "Run this on the target Windows machine in admin PowerShell:"
    @echo "  powershell -ExecutionPolicy Bypass -File shared\scripts\bootstrap-windows-manual.ps1 {{ARGS}}"

# -- Validation Playbooks --

ansible-validate-bootstrap:
    devbox run ansible-validate-bootstrap-internal

ansible-validate-bootstrap-internal:
    @echo "Validating bootstrap deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_BOOTSTRAP}}

ansible-validate-vpn:
    devbox run ansible-validate-vpn-internal

ansible-validate-vpn-internal:
    @echo "Validating VPN deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_VPN}}

ansible-validate-infra:
    devbox run ansible-validate-infra-internal

ansible-validate-infra-internal:
    @echo "Validating infrastructure deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_INFRA}}

ansible-validate-vms:
    devbox run ansible-validate-vms-internal

ansible-validate-vms-internal:
    @echo "Validating VM deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_VMS}}

ansible-validate-all:
    @echo "Running all validation playbooks..."
    just ansible-validate-bootstrap-internal
    just ansible-validate-vpn-internal
    just ansible-validate-infra-internal
    just ansible-validate-vms-internal

ansible-final-audit:
    devbox run ansible-final-audit-internal

ansible-final-audit-internal:
    @echo "Running final security audit..."
    ansible-playbook -i {{INVENTORY}} {{PB_FINAL_AUDIT}}

# === Service Catalog Generation ===

generate-service-catalog:
    devbox run generate-service-catalog-internal

generate-service-catalog-internal:
    @echo "Generating SERVICES.md from infrastructure YAML..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py

# === Packer VM Image Creation ===

packer-build:
    devbox run packer-build-internal

packer-build-internal:
    @echo "Building cloud server VM image with Packer..."
    @if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then \
        cd {{PACKER_DIR}} && packer build cloud-server.pkr.hcl; \
    else \
        echo "No Packer config found at {{PACKER_DIR}}/cloud-server.pkr.hcl"; \
        echo "Create one to enable VM image builds."; \
    fi

packer-validate:
    @echo "Validating Packer configuration..."
    @if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then \
        cd {{PACKER_DIR}} && packer validate cloud-server.pkr.hcl; \
    else \
        echo "No Packer config found"; \
    fi

packer-init:
    @echo "Initializing Packer plugins..."
    @if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then \
        cd {{PACKER_DIR}} && packer init cloud-server.pkr.hcl; \
    else \
        echo "No Packer config found"; \
    fi

# === LocalNet Docker Delegation ===

# Delegate Docker/LocalNet commands to component justfile
localnet-up:
    just -f {{CONTAINER_ROOT}}/justfile base-up

localnet-down:
    just -f {{CONTAINER_ROOT}}/justfile down

localnet-build:
    just -f {{CONTAINER_ROOT}}/justfile build

localnet-logs service="":
    just -f {{CONTAINER_ROOT}}/justfile logs {{service}}

localnet-health:
    just -f {{CONTAINER_ROOT}}/justfile health-check

localnet-ps:
    just -f {{CONTAINER_ROOT}}/justfile ps

# === Cleanup ===

clean:
    devbox run clean

clean-internal:
    @echo "Cleaning build artifacts..."
    @rm -rf {{INFRAHUB_ROOT}}/logs/*.log
    @docker system prune -f || true
    @echo "Cleanup complete."

clean-all:
    devbox run clean-all

clean-all-internal:
    @echo "Deep cleaning all artifacts and caches..."
    @rm -rf {{INFRAHUB_ROOT}}/logs/*.log
    @docker system prune -af || true
    @docker volume prune -f || true
    @echo "Deep clean complete."
