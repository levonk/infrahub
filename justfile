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
    #!/usr/bin/env sh
    . {{INFRAHUB_ROOT}}/scripts/ensure-env.sh
    devbox run -- just doctor-internal

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
    @echo "Checking playbook syntax (generic, no inventory)..."
    @for pb in {{ANSIBLE_ROOT}}/playbooks/*.yml; do \
        echo "  → $$(basename $$pb)"; \
        ansible-playbook --syntax-check "$$pb" 2>&1 | grep -v "^$" || true; \
    done
    @echo "For client-specific syntax checks (with inventory), run: cd levonk && just levonk-syntax"
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
# Client-specific deploy/validate recipes have been moved to levonk/justfile.
# Run them from the levonk/ subdirectory:  cd levonk && just --list
# Or:  just --justfile levonk/justfile levonk-deploy-exit-nodes-cno

# === PowerShell Lint ===

ps-lint:
    devbox run -- just ps-lint-internal

ps-lint-internal:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running PSScriptAnalyzer on all .ps1 files..."
    pwsh -NoProfile -File "{{INFRAHUB_ROOT}}/shared/scripts/ps-lint.ps1" "{{INFRAHUB_ROOT}}"
    echo "PSScriptAnalyzer complete."

# === Manual Bootstrap Scripts (run ON the target machine) ===

# Run the manual bootstrap script on a target Mac (run ON the target, not control machine)
macos-manual-bootstrap *ARGS:
    @echo "Running manual bootstrap script..."
    bash {{INFRAHUB_ROOT}}/shared/scripts/bootstrap-macos-manual.sh {{ARGS}}

# Run the manual bootstrap script on a target Windows machine (run ON the target, not control machine)
windows-manual-bootstrap *ARGS:
    @echo "Run this on the target Windows machine in admin PowerShell:"
    @echo "  powershell -ExecutionPolicy Bypass -File shared\scripts\bootstrap-windows-manual.ps1 {{ARGS}}"

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
