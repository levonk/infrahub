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
PB_NESTED_VIRT := ANSIBLE_ROOT + "/playbooks/test-nested-virtualization.yml"
PB_ENABLE_WSL2_KVM := ANSIBLE_ROOT + "/playbooks/enable-wsl2-kvm.yml"
PB_NIX_CACHE_GARNIX := ANSIBLE_ROOT + "/playbooks/deploy-nix-cache-and-garnix.yml"
PB_DIRECTORY_EMPIRE := ANSIBLE_ROOT + "/playbooks/deploy-directory-empire.yml"
PB_PROXY_WEB := ANSIBLE_ROOT + "/playbooks/deploy-proxy-web-stack.yml"
PB_VAL_PROXY_WEB := ANSIBLE_ROOT + "/playbooks/validate-proxy-web.yml"
PB_FWKNOP := ANSIBLE_ROOT + "/playbooks/deploy-fwknop.yml"
PB_FWKNOP_CLIENT := ANSIBLE_ROOT + "/playbooks/deploy-fwknop-client.yml"
WINDOWS_INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/windows-docker.yml"
MACOS_INVENTORY := INFRAHUB_ROOT + "/levonk/active/02-config/ansible/inventories/macos-hosts.yml"
PB_CONFIGURE_MACOS := ANSIBLE_ROOT + "/playbooks/configure-macos-host.yml"
PB_BOOTSTRAP_MACOS := ANSIBLE_ROOT + "/playbooks/bootstrap-macos-host.yml"

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
    @git config core.hooksPath >/dev/null 2>&1 && echo "git hooks: $(git config core.hooksPath)" || echo "git hooks: NOT CONFIGURED (run 'just setup')"
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
    @echo "Setting up git hooks (core.hooksPath=scripts/hooks)..."
    @git config core.hooksPath scripts/hooks
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

# Build and push the Directory Empire dashboard image (external repo build)
# Clones lrepo52/directory-empire, builds multi-stage Dockerfile, pushes to registry.
build-directory-empire-image:
    devbox run build-directory-empire-image-internal

build-directory-empire-image-internal:
    @echo "Building and pushing directory-empire image to local registry..."
    {{INFRAHUB_ROOT}}/scripts/build-directory-empire-image.sh

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

# -- Nested Virtualization Tests (cross-platform) --

ansible-test-nested-virt:
    @echo "Testing nested virtualization on Linux (OCI cloud server)..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-internal:
    @echo "Testing nested virtualization on Linux (OCI cloud server)..."
    ansible-playbook -i {{INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-windows:
    @echo "Testing nested virtualization on Windows (dtop202311 / WSL2)..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-windows-internal:
    @echo "Testing nested virtualization on Windows (dtop202311 / WSL2)..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-all:
    @echo "Testing nested virtualization on all hosts (Linux + Windows)..."
    devbox run -- ansible-playbook -i {{INVENTORY}} -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-all-internal:
    @echo "Testing nested virtualization on all hosts (Linux + Windows)..."
    ansible-playbook -i {{INVENTORY}} -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

# -- Enable WSL2 KVM Nested Virtualization on Windows Docker Hosts --
# Installs Debian minimal WSL2 distro, builds KVM kernel modules from
# the matching WSL2-Linux-Kernel source, and configures auto-load at boot.
# WARNING: This restarts WSL2 (wsl --shutdown), which will stop all running
# Docker containers on the host. Run during a maintenance window.

ansible-enable-wsl2-kvm:
    @echo "Enabling WSL2 KVM nested virtualization on Windows host..."
    @echo "WARNING: This will restart WSL2 and stop all running Docker containers."
    @echo "Press Ctrl+C to abort, or wait 5 seconds..."
    @sleep 5
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_ENABLE_WSL2_KVM}} --vault-password-file ~/.ansible/vault_password

ansible-enable-wsl2-kvm-internal:
    @echo "Enabling WSL2 KVM nested virtualization on Windows host..."
    @echo "WARNING: This will restart WSL2 and stop all running Docker containers."
    @echo "Press Ctrl+C to abort, or wait 5 seconds..."
    @sleep 5
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_ENABLE_WSL2_KVM}} --vault-password-file ~/.ansible/vault_password

# -- Deploy Nix Cache Chain + Garnix CI (nl region) --
# Deploys Harmonia + ncps + ncro + garnix-ci on dtop202311.
# All services share the nix-sidecar's /nix/store for package reuse.
# Prerequisites: nix-sidecar running, Traefik Windows deployed, WSL2 KVM enabled,
# DNS CNAMEs configured, container images built.

ansible-deploy-nix-cache-garnix:
    @echo "Deploying Nix Cache Chain + Garnix CI on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-nix-cache-garnix-internal:
    @echo "Deploying Nix Cache Chain + Garnix CI on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password

# Deploy only the Nix cache chain (Harmonia + ncps + ncro), skip garnix-ci
ansible-deploy-nix-cache:
    @echo "Deploying Nix Cache Chain (Harmonia + ncps + ncro) on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags garnix-ci

ansible-deploy-nix-cache-internal:
    @echo "Deploying Nix Cache Chain (Harmonia + ncps + ncro) on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags garnix-ci

# Deploy only garnix-ci, skip the cache chain
ansible-deploy-garnix-ci:
    @echo "Deploying Garnix CI on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags harmonia,ncro,ncps

ansible-deploy-garnix-ci-internal:
    @echo "Deploying Garnix CI on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags harmonia,ncro,ncps

# Deploy Directory Empire dashboard on Windows Docker host
# Prerequisites: Traefik Windows deployed, DNS CNAME configured, image built+pushed.
ansible-deploy-directory-empire:
    @echo "Deploying Directory Empire dashboard on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_DIRECTORY_EMPIRE}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-directory-empire-internal:
    @echo "Deploying Directory Empire dashboard on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_DIRECTORY_EMPIRE}} --vault-password-file ~/.ansible/vault_password

# Deploy Web Proxy Chain (MITM → Privoxy → Varnish → Gost) on Windows Docker host
# Prerequisites: DNS chain deployed (Tor proxy at 172.26.255.70:9050), Gost image built.
ansible-deploy-proxy-web:
    @echo "Deploying Web Proxy Chain on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit windows_docker_hosts

ansible-deploy-proxy-web-internal:
    @echo "Deploying Web Proxy Chain on Windows Docker host..."
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit windows_docker_hosts

# Deploy Web Proxy Chain on OCI cloud server
ansible-deploy-proxy-web-oci:
    @echo "Deploying Web Proxy Chain on OCI cloud server..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

ansible-deploy-proxy-web-oci-internal:
    @echo "Deploying Web Proxy Chain on OCI cloud server..."
    ansible-playbook -i {{INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# Validate Web Proxy Chain deployment
ansible-validate-proxy-web:
    @echo "Validating Web Proxy Chain on Windows Docker host..."
    devbox run -- ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_VAL_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit windows_docker_hosts

ansible-validate-proxy-web-oci:
    @echo "Validating Web Proxy Chain on OCI cloud server..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_VAL_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# -- Deploy Playbooks --
# Client-specific deploy/validate recipes have been moved to levonk/justfile.

# Deploy fwknop-server SPA (Single Packet Authorization) on OCI cloud server
# Port 22 stays OPEN by default — test SPA before closing it.
# To close port 22 after testing: add -e fwknop_close_public_ssh=true
ansible-deploy-fwknop:
    @echo "Deploying fwknop-server SPA on OCI cloud server (port 22 stays open)..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

ansible-deploy-fwknop-internal:
    @echo "Deploying fwknop-server SPA on OCI cloud server (port 22 stays open)..."
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# Close public SSH port 22 after confirming SPA works
ansible-deploy-fwknop-close-ssh:
    @echo "Closing public SSH port 22 (SPA now required for public access)..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers -e fwknop_close_public_ssh=true

ansible-deploy-fwknop-close-ssh-internal:
    @echo "Closing public SSH port 22 (SPA now required for public access)..."
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers -e fwknop_close_public_ssh=true

# Deploy fwknop SPA client to all hosts (installs fwknop, ~/.fwknoprc, ~/.ssh/config.d/infrahub)
# Linux: apt/dnf install. macOS: brew install + deploy to GUI user's home.
# Windows hosts are excluded (fwknop not available natively).
ansible-deploy-fwknop-client:
    @echo "Deploying fwknop SPA client to all hosts..."
    devbox run -- ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP_CLIENT}} --vault-password-file ~/.ansible/vault_password

ansible-deploy-fwknop-client-internal:
    @echo "Deploying fwknop SPA client to all hosts..."
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP_CLIENT}} --vault-password-file ~/.ansible/vault_password

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
    @echo "Generating levonk/SERVICES.md from infrastructure YAML..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py

generate-service-catalog-internal:
    @echo "Generating SERVICES.md from infrastructure YAML..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py

# Generate repo-root SERVICES.md (shared defaults only — no client deployment info)
generate-service-catalog-shared:
    @echo "Generating repo-root SERVICES.md (shared defaults only)..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

generate-service-catalog-shared-internal:
    @echo "Generating repo-root SERVICES.md (shared defaults only)..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

# Generate both catalogs (client + repo-root)
generate-service-catalog-all:
    @echo "Generating both SERVICES.md catalogs (client + repo-root)..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

generate-service-catalog-all-internal:
    @echo "Generating both SERVICES.md catalogs (client + repo-root)..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

# === Tool Catalog Generation ===

generate-tool-catalog:
    @echo "Generating levonk/TOOLS.md from infrastructure YAML..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py

generate-tool-catalog-internal:
    @echo "Generating TOOLS.md from infrastructure YAML..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py

# Generate repo-root TOOLS.md (shared defaults only — no client deployment info)
generate-tool-catalog-shared:
    @echo "Generating repo-root TOOLS.md (shared defaults only)..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

generate-tool-catalog-shared-internal:
    @echo "Generating repo-root TOOLS.md (shared defaults only)..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

# Generate both tool catalogs (client + repo-root)
generate-tool-catalog-all:
    @echo "Generating both TOOLS.md catalogs (client + repo-root)..."
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py
    devbox run -- python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

generate-tool-catalog-all-internal:
    @echo "Generating both TOOLS.md catalogs (client + repo-root)..."
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

# === Sandboxed CLI Proxy Deployment ===

# === macOS Host Management ===

# Bootstrap a fresh macOS host (creates auser, SSH, Nix, Tailscale, Netbird)
ansible-bootstrap-macos-internal:
    @echo "Bootstrapping macOS host..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_BOOTSTRAP_MACOS}} \
      --vault-password-file ~/.ansible/vault_password --ask-become-pass

# Configure macOS host (nix-darwin + apps + pmset + Xcode)
ansible-configure-macos-internal:
    @echo "Configuring macOS host..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_CONFIGURE_MACOS}} \
      --vault-password-file ~/.ansible/vault_password

# Install Xcode on macOS hosts via mas (Mac App Store CLI)
# Requires: Apple ID signed in to App Store (System Settings → App Store)
ansible-install-xcode-internal:
    @echo "Installing Xcode on macOS hosts..."
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_CONFIGURE_MACOS}} \
      --vault-password-file ~/.ansible/vault_password \
      --tags xcode

# Deploy the sandbox CLI proxy (iron-proxy) to Mac hosts
deploy-sandbox-proxy-macos:
    @echo "Deploying sandbox CLI proxy to macOS hosts..."
    devbox run -- rtk ansible-playbook \
      -i {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories/macos-hosts.yml \
      {{ANSIBLE_ROOT}}/playbooks/deploy-sandbox-proxy.yml \
      --vault-password-file ~/.ansible/vault_password

# Deploy the sandbox CLI proxy (iron-proxy) to OCI cloud server
deploy-sandbox-proxy-oci:
    @echo "Deploying sandbox CLI proxy to OCI cloud server..."
    devbox run -- rtk ansible-playbook \
      -i {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories/oci.yml \
      {{ANSIBLE_ROOT}}/playbooks/deploy-sandbox-proxy.yml \
      --vault-password-file ~/.ansible/vault_password

# === Sandboxed CLI Tools ===

# Run a sandboxed CLI tool through the iron-proxy egress boundary.
# Usage: just sandbox-run osint sherlock/sherlock "target.com"
sandbox-run profile image *args:
    #!/usr/bin/env bash
    set -euo pipefail
    SANDBOX_ENV="{{INFRAHUB_ROOT}}/.sandbox-env"
    if [ ! -f "$SANDBOX_ENV" ]; then
        echo "Error: .sandbox-env not found at $SANDBOX_ENV"
        echo "Deploy the sandbox proxy first: just deploy-sandbox-proxy-macos"
        exit 1
    fi
    source "$SANDBOX_ENV"
    # Build profile-specific variable names
    PROFILE_UPPER=$(echo "{{profile}}" | tr '[:lower:]' '[:upper:]')
    NETWORK_VAR="SANDBOX_${PROFILE_UPPER}_NETWORK"
    PROXY_HOST_VAR="SANDBOX_${PROFILE_UPPER}_PROXY_HOST"
    NETWORK="${!NETWORK_VAR}"
    PROXY_HOST="${!PROXY_HOST_VAR}"
    CA_HOST_PATH="SANDBOX_${PROFILE_UPPER}_CA_HOST_PATH"
    CA_HOST="${!CA_HOST_PATH}"
    if [ -z "$NETWORK" ] || [ -z "$PROXY_HOST" ]; then
        echo "Error: Profile '{{profile}}' not found in .sandbox-env"
        echo "Available profiles: check $SANDBOX_ENV"
        exit 1
    fi
    echo "Running {{image}} through sandbox profile '{{profile}}' (network: $NETWORK, proxy: $PROXY_HOST)"
    docker run --rm -i \
      --network "$NETWORK" \
      --read-only \
      --tmpfs /tmp:rw,size=64m \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --user 1000:1000 \
      -e HTTP_PROXY="http://${PROXY_HOST}:80" \
      -e HTTPS_PROXY="http://${PROXY_HOST}:443" \
      -e REQUESTS_CA_BUNDLE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -e SSL_CERT_FILE="${SANDBOX_CA_CERT_CONTAINER_PATH}" \
      -v "${CA_HOST}:${SANDBOX_CA_CERT_SYSTEM_PATH}:ro" \
      --entrypoint sh \
      "{{image}}" \
      -c "update-ca-certificates 2>/dev/null || true; exec {{args}}"

# Sandboxed Sherlock — username enumeration across social networks
# Usage: just sandbox-sherlock username1 username2
sandbox-sherlock *args: (sandbox-run "osint" "sherlock/sherlock" "sherlock" args)

# Sandboxed Subfinder — subdomain discovery via passive sources
# Usage: just sandbox-subfinder -d example.com
sandbox-subfinder *args: (sandbox-run "osint" "projectdiscovery/subfinder" "subfinder" args)

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
