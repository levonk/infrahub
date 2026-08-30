# Root justfile for infrahub
# Follows ADR-20260131001: direnv -> devbox -> just (*_impl)
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
PB_STIRLING_PDF := ANSIBLE_ROOT + "/playbooks/deploy-stirling-pdf.yml"
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

_log := '
_jv_has() {
  local cat="$1"
  local v="${JUST_LOG:-0}"
  case "$v" in
    1|all) return 0 ;;
    0|"") return 1 ;;
  esac
  v="${v//startend/start,end}"
  echo ",$v," | grep -q ",$cat,"
}
log_info()   { _jv_has info   && echo "$*" || true; }
log_start()  { _jv_has start  && echo "▶ $*" || true; }
log_end()    { _jv_has end    && echo "✔ $*" || true; }
log_status() { _jv_has status && echo "$*" || true; }
log_warn()   { echo "⚠️  $*" >&2; }
log_error()  { echo "❌ $*" >&2; }
log_startend() {
  local msg="$1"; shift
  local rc
  _jv_has start && echo "▶ $msg" || true
  rc=0; "$@" || rc=$?
  _jv_has end && echo "✔ $msg complete" || true
  return $rc
}
'

# Devbox auto-detection: run impl target directly if in devbox,
# re-exec via devbox run if not, or fail with doctor diagnostic.
_devbox target *args:
    #!/usr/bin/env bash
    {{_log}}
    if [ "${DEVBOX_SHELL_ENABLED:-0}" = "1" ]; then
        exec just "{{target}}" {{args}}
    elif command -v devbox >/dev/null 2>&1; then
        exec devbox run -- just "{{target}}" {{args}}
    else
        log_error "devbox not found in PATH."
        log_warn "Running doctor to diagnose environment issues..."
        just doctor 2>/dev/null || true
        exit 1
    fi

# === Default recipe ===
default:
    @just --list

# === Bootstrap & Environment ===

bootstrap:
    @just _devbox bootstrap_impl

[private]
bootstrap_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Bootstrapping infrahub environment"
    just setup_impl
    just prime_impl
    log_end "Bootstrap complete"

prime:
    @just _devbox prime_impl

[private]
prime_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Priming code indexing"
    log_end "Prime complete"

doctor:
    #!/usr/bin/env bash
    {{_log}}
    . {{INFRAHUB_ROOT}}/scripts/ensure-env.sh
    just _devbox doctor_impl

[private]
doctor_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking environment health..."
    ansible --version || echo "ansible: NOT FOUND"
    ansible-lint --version || echo "ansible-lint: NOT FOUND"
    molecule --version || echo "molecule: NOT FOUND"
    packer --version || echo "packer: NOT FOUND"
    docker --version || echo "docker: NOT FOUND"
    just --version || echo "just: NOT FOUND"
    devbox version || echo "devbox: NOT FOUND"
    git config core.hooksPath >/dev/null 2>&1 && echo "git hooks: $(git config core.hooksPath)" || echo "git hooks: NOT CONFIGURED (run 'just setup')"
    echo "Environment check complete."

setup:
    @just _devbox setup_impl

[private]
setup_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Setting up infrahub directories"
    mkdir -p {{ANSIBLE_ROOT}}/roles
    mkdir -p {{ANSIBLE_ROOT}}/playbooks
    mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories
    mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/host_vars
    mkdir -p {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/group_vars
    mkdir -p {{PACKER_DIR}}
    mkdir -p {{INFRAHUB_ROOT}}/logs
    log_info "Setting up git hooks (core.hooksPath=scripts/hooks)..."
    git config core.hooksPath scripts/hooks
    log_end "Directory structure ready"

# === Skill Bootstrap ===

# Install the execute-upsert skill from levonk/skills-releases
# Required by infrahub-add-new-service-orchestrator.md workflow for the PRD → tasks → execute pipeline
skills-bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Installing execute-upsert skill from levonk/skills-releases"
    npx skills add levonk/skills-releases --skill execute-upsert
    log_end "Skill bootstrap complete"

# === Standard Quality Gates ===

build:
    @just _devbox build_impl

[private]
build_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building all infrahub components"
    log_info "(Add component-specific build steps here)"

# === Docker Image Build & Push (Invariant #2: build locally → push to registry → pull on target) ===

# Build and push all locally-built images to the OCI registry (skips unchanged)
docker-build-push-all:
    @just _devbox docker_build_push_all_impl

[private]
docker_build_push_all_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building and pushing all images to local registry"
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh

# Force rebuild and push all images (ignores cache)
docker-build-push-all-force:
    @just _devbox docker_build_push_all_force_impl

[private]
docker_build_push_all_force_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Force rebuilding and pushing all images to local registry"
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh --force

# Build and push a single image (e.g., just docker-build-push headroom)
docker-build-push image:
    @just _devbox docker_build_push_impl {{image}}

[private]
docker_build_push_impl image:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building and pushing '{{image}}' to local registry"
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh {{image}}

# List all images that can be built and pushed
docker-build-list:
    @just _devbox docker_build_list_impl

[private]
docker_build_list_impl:
    {{INFRAHUB_ROOT}}/scripts/build-and-push-images.sh --list

# Build and push the Directory Empire dashboard image (external repo build)
# Clones lrepo52/directory-empire, builds multi-stage Dockerfile, pushes to registry.
build-directory-empire-image:
    @just _devbox build_directory_empire_image_impl

[private]
build_directory_empire_image_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building and pushing directory-empire image to local registry"
    {{INFRAHUB_ROOT}}/scripts/build-directory-empire-image.sh

test:
    @just _devbox test_impl

[private]
test_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running all tests"
    just ansible_test_impl

lint:
    @just _devbox lint_impl

[private]
lint_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running all lints"
    just ansible_lint_impl
    just ps_lint_impl

quality:
    @just _devbox quality_impl

[private]
quality_impl:
    just lint
    just test

# === Ansible Lifecycle Commands ===

# -- Lint & Syntax Check --

ansible-lint:
    @just _devbox ansible_lint_impl

[private]
ansible_lint_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running ansible-lint across roles and playbooks"
    ansible-lint {{ANSIBLE_ROOT}}/roles/ {{ANSIBLE_ROOT}}/playbooks/ || true
    log_end "ansible-lint complete"

ansible-syntax:
    @just _devbox ansible_syntax_impl

[private]
ansible_syntax_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Checking playbook syntax (generic, no inventory)"
    for pb in {{ANSIBLE_ROOT}}/playbooks/*.yml; do
        log_info "  → $(basename "$pb")"
        ansible-playbook --syntax-check "$pb" 2>&1 | grep -v "^$" || true
    done
    log_info "For client-specific syntax checks (with inventory), run: cd levonk && just levonk-syntax"
    log_end "Syntax check complete"

# -- Molecule Tests (Docker-backed) --

ansible-test:
    @just _devbox ansible_test_impl

[private]
ansible_test_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule tests for all roles"
    for role_dir in {{MOLECULE_DIR}}/*/; do
        role_name=$(basename "$role_dir")
        if [ -d "$role_dir/molecule" ]; then
            log_info "Testing role: $role_name"
            (cd "$role_dir" && molecule test) || log_warn "Molecule test failed for $role_name"
        else
            log_info "No molecule tests for $role_name"
        fi
    done
    log_end "Molecule tests complete"

molecule-test role:
    @just _devbox molecule_test_impl {{role}}

[private]
molecule_test_impl role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule test for role: {{role}}"
    cd {{MOLECULE_DIR}}/{{role}} && molecule test

molecule-converge role:
    @just _devbox molecule_converge_impl {{role}}

[private]
molecule_converge_impl role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule converge for role: {{role}}"
    cd {{MOLECULE_DIR}}/{{role}} && molecule converge

molecule-destroy role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Destroying Molecule environment for role: {{role}}"
    cd {{MOLECULE_DIR}}/{{role}} && molecule destroy

molecule-verify role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule verify for role: {{role}}"
    cd {{MOLECULE_DIR}}/{{role}} && molecule verify

# -- Docker-based Molecule Tests (bypass Nix dependency issues) --

MOLECULE_DOCKER_IMAGE := "molecule-test-runner:latest"
MOLECULE_DOCKER_CONTAINER := "molecule-test-env"
MOLECULE_DOCKERFILE := CONTAINER_ROOT + "/Dockerfile.molecule"

molecule-docker-build:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building Molecule Docker image"
    docker build -t {{MOLECULE_DOCKER_IMAGE}} -f {{MOLECULE_DOCKERFILE}} {{CONTAINER_ROOT}}

molecule-docker-test role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule test for role: {{role}} in Docker container"
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule test"

molecule-docker-converge role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule converge for role: {{role}} in Docker container"
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule converge"

molecule-docker-verify role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running Molecule verify for role: {{role}} in Docker container"
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule verify"

molecule-docker-destroy role:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Destroying Molecule environment for role: {{role}} in Docker container"
    docker run --rm \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash -c "cd /workspace/shared/active/02-config/ansible/roles/{{role}} && molecule destroy"

molecule-docker-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Starting interactive shell in Molecule Docker container"
    docker run --rm -it \
        -v {{INFRAHUB_ROOT}}:/workspace \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        {{MOLECULE_DOCKER_IMAGE}} \
        bash

# -- Docker Test Environment for Ansible --

ansible-test-env-build:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building Ansible test Docker image"
    docker build -t {{ANSIBLE_TEST_IMAGE}} -f {{ANSIBLE_ROOT}}/Dockerfile.test {{ANSIBLE_ROOT}} || log_warn "No Dockerfile.test found; using default image"

ansible-test-env-run:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Starting Ansible test container"
    docker run -d --name {{ANSIBLE_TEST_CONTAINER}} \
        --rm \
        -v {{ANSIBLE_ROOT}}:/ansible:ro \
        -v {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible:/ansible/inventories:ro \
        {{ANSIBLE_TEST_IMAGE}} tail -f /dev/null || log_error "Test container start failed"

ansible-test-env-exec cmd="ansible-playbook":
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Executing in test container: {{cmd}}"
    docker exec -it {{ANSIBLE_TEST_CONTAINER}} {{cmd}}

ansible-test-env-stop:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Stopping Ansible test container"
    docker stop {{ANSIBLE_TEST_CONTAINER}} || true
    docker rm {{ANSIBLE_TEST_CONTAINER}} || true

# -- Nested Virtualization Tests (cross-platform) --

ansible-test-nested-virt:
    @just _devbox ansible_test_nested_virt_impl

[private]
ansible_test_nested_virt_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Testing nested virtualization on Linux (OCI cloud server)"
    ansible-playbook -i {{INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-windows:
    @just _devbox ansible_test_nested_virt_windows_impl

[private]
ansible_test_nested_virt_windows_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Testing nested virtualization on Windows (dtop202311 / WSL2)"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

ansible-test-nested-virt-all:
    @just _devbox ansible_test_nested_virt_all_impl

[private]
ansible_test_nested_virt_all_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Testing nested virtualization on all hosts (Linux + Windows)"
    ansible-playbook -i {{INVENTORY}} -i {{WINDOWS_INVENTORY}} {{PB_NESTED_VIRT}} --vault-password-file ~/.ansible/vault_password

# -- Enable WSL2 KVM Nested Virtualization on Windows Docker Hosts --
# Installs Debian minimal WSL2 distro, builds KVM kernel modules from
# the matching WSL2-Linux-Kernel source, and configures auto-load at boot.
# WARNING: This restarts WSL2 (wsl --shutdown), which will stop all running
# Docker containers on the host. Run during a maintenance window.

ansible-enable-wsl2-kvm:
    @just _devbox ansible_enable_wsl2_kvm_impl

[private]
ansible_enable_wsl2_kvm_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Enabling WSL2 KVM nested virtualization on Windows host"
    log_warn "This will restart WSL2 and stop all running Docker containers."
    log_info "Press Ctrl+C to abort, or wait 5 seconds..."
    sleep 5
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_ENABLE_WSL2_KVM}} --vault-password-file ~/.ansible/vault_password

# -- Deploy Nix Cache Chain + Garnix CI (nl region) --
# Deploys Harmonia + ncps + ncro + garnix-ci on dtop202311.
# All services share the nix-sidecar's /nix/store for package reuse.
# Prerequisites: nix-sidecar running, Traefik Windows deployed, WSL2 KVM enabled,
# DNS CNAMEs configured, container images built.

ansible-deploy-nix-cache-garnix:
    @just _devbox ansible_deploy_nix_cache_garnix_impl

[private]
ansible_deploy_nix_cache_garnix_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Nix Cache Chain + Garnix CI on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password

# Deploy only the Nix cache chain (Harmonia + ncps + ncro), skip garnix-ci
ansible-deploy-nix-cache:
    @just _devbox ansible_deploy_nix_cache_impl

[private]
ansible_deploy_nix_cache_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Nix Cache Chain (Harmonia + ncps + ncro) on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags garnix-ci

# Deploy only garnix-ci, skip the cache chain
ansible-deploy-garnix-ci:
    @just _devbox ansible_deploy_garnix_ci_impl

[private]
ansible_deploy_garnix_ci_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Garnix CI on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_NIX_CACHE_GARNIX}} --vault-password-file ~/.ansible/vault_password --skip-tags harmonia,ncro,ncps

# Deploy Directory Empire dashboard on Windows Docker host
# Prerequisites: Traefik Windows deployed, DNS CNAME configured, image built+pushed.
ansible-deploy-directory-empire:
    @just _devbox ansible_deploy_directory_empire_impl

[private]
ansible_deploy_directory_empire_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Directory Empire dashboard on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_DIRECTORY_EMPIRE}} --vault-password-file ~/.ansible/vault_password

# Deploy Stirling-PDF on Windows Docker host (nl region)
# Prerequisites: Traefik Windows deployed, DNS CNAME configured.
ansible-deploy-stirling-pdf:
    @just _devbox ansible_deploy_stirling_pdf_impl

[private]
ansible_deploy_stirling_pdf_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Stirling-PDF on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_STIRLING_PDF}} --vault-password-file ~/.ansible/vault_password

# Deploy Web Proxy Chain (MITM → Privoxy → Varnish → Gost) on Windows Docker host
# Prerequisites: DNS chain deployed (Tor proxy at 172.26.255.70:9050), Gost image built.
ansible-deploy-proxy-web:
    @just _devbox ansible_deploy_proxy_web_impl

[private]
ansible_deploy_proxy_web_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Web Proxy Chain on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit windows_docker_hosts

# Deploy Web Proxy Chain on OCI cloud server
ansible-deploy-proxy-web-oci:
    @just _devbox ansible_deploy_proxy_web_oci_impl

[private]
ansible_deploy_proxy_web_oci_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Web Proxy Chain on OCI cloud server"
    ansible-playbook -i {{INVENTORY}} {{PB_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# Validate Web Proxy Chain deployment
ansible-validate-proxy-web:
    @just _devbox ansible_validate_proxy_web_impl

[private]
ansible_validate_proxy_web_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Validating Web Proxy Chain on Windows Docker host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{PB_VAL_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit windows_docker_hosts

ansible-validate-proxy-web-oci:
    @just _devbox ansible_validate_proxy_web_oci_impl

[private]
ansible_validate_proxy_web_oci_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Validating Web Proxy Chain on OCI cloud server"
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_PROXY_WEB}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# -- Deploy Playbooks --
# Client-specific deploy/validate recipes have been moved to levonk/justfile.

# Deploy fwknop-server SPA (Single Packet Authorization) on OCI cloud server
# Port 22 stays OPEN by default — test SPA before closing it.
# To close port 22 after testing: add -e fwknop_close_public_ssh=true
ansible-deploy-fwknop:
    @just _devbox ansible_deploy_fwknop_impl

[private]
ansible_deploy_fwknop_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying fwknop-server SPA on OCI cloud server (port 22 stays open)"
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers

# Close public SSH port 22 after confirming SPA works
ansible-deploy-fwknop-close-ssh:
    @just _devbox ansible_deploy_fwknop_close_ssh_impl

[private]
ansible_deploy_fwknop_close_ssh_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Closing public SSH port 22 (SPA now required for public access)"
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP}} --vault-password-file ~/.ansible/vault_password --limit cloud_servers -e fwknop_close_public_ssh=true

# Deploy fwknop SPA client to all hosts (installs fwknop, ~/.fwknoprc, ~/.ssh/config.d/infrahub)
# Linux: apt/dnf install. macOS: brew install + deploy to GUI user's home.
# Windows hosts are excluded (fwknop not available natively).
ansible-deploy-fwknop-client:
    @just _devbox ansible_deploy_fwknop_client_impl

[private]
ansible_deploy_fwknop_client_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying fwknop SPA client to all hosts"
    ansible-playbook -i {{INVENTORY}} {{PB_FWKNOP_CLIENT}} --vault-password-file ~/.ansible/vault_password

# Run them from the levonk/ subdirectory:  cd levonk && just --list
# Or:  just --justfile levonk/justfile levonk-deploy-exit-nodes-cno

# === PowerShell Lint ===

ps-lint:
    @just _devbox ps_lint_impl

[private]
ps_lint_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running PSScriptAnalyzer on all .ps1 files"
    pwsh -NoProfile -File "{{INFRAHUB_ROOT}}/shared/scripts/ps-lint.ps1" "{{INFRAHUB_ROOT}}"
    log_end "PSScriptAnalyzer complete"

# === Manual Bootstrap Scripts (run ON the target machine) ===

# Run the manual bootstrap script on a target Mac (run ON the target, not control machine)
macos-manual-bootstrap *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Running manual bootstrap script"
    bash {{INFRAHUB_ROOT}}/shared/scripts/bootstrap-macos-manual.sh {{ARGS}}

# Run the manual bootstrap script on a target Windows machine (run ON the target, not control machine)
windows-manual-bootstrap *ARGS:
    echo "Run this on the target Windows machine in admin PowerShell:"
    echo "  powershell -ExecutionPolicy Bypass -File shared\scripts\bootstrap-windows-manual.ps1 {{ARGS}}"

# === Service Catalog Generation ===

generate-service-catalog:
    @just _devbox generate_service_catalog_impl

[private]
generate_service_catalog_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating levonk/SERVICES.md from infrastructure YAML"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py

# Generate repo-root SERVICES.md (shared defaults only — no client deployment info)
generate-service-catalog-shared:
    @just _devbox generate_service_catalog_shared_impl

[private]
generate_service_catalog_shared_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating repo-root SERVICES.md (shared defaults only)"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

# Generate both catalogs (client + repo-root)
generate-service-catalog-all:
    @just _devbox generate_service_catalog_all_impl

[private]
generate_service_catalog_all_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating both SERVICES.md catalogs (client + repo-root)"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py
    python3 {{ANSIBLE_ROOT}}/scripts/generate_service_catalog.py --shared-only --output SERVICES.md

# === Tool Catalog Generation ===

generate-tool-catalog:
    @just _devbox generate_tool_catalog_impl

[private]
generate_tool_catalog_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating levonk/TOOLS.md from infrastructure YAML"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py

# Generate repo-root TOOLS.md (shared defaults only — no client deployment info)
generate-tool-catalog-shared:
    @just _devbox generate_tool_catalog_shared_impl

[private]
generate_tool_catalog_shared_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating repo-root TOOLS.md (shared defaults only)"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

# Generate both tool catalogs (client + repo-root)
generate-tool-catalog-all:
    @just _devbox generate_tool_catalog_all_impl

[private]
generate_tool_catalog_all_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Generating both TOOLS.md catalogs (client + repo-root)"
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py
    python3 {{ANSIBLE_ROOT}}/scripts/generate_tool_catalog.py --shared-only --output TOOLS.md

# === Sandboxed CLI Proxy Deployment ===

# === macOS Host Management ===

# Bootstrap a fresh macOS host (creates auser, SSH, Nix, Tailscale, Netbird)
ansible-bootstrap-macos:
    @just _devbox ansible_bootstrap_macos_impl

[private]
ansible_bootstrap_macos_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Bootstrapping macOS host"
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_BOOTSTRAP_MACOS}} \
      --vault-password-file ~/.ansible/vault_password --ask-become-pass

# Configure macOS host (nix-darwin + apps + pmset + Xcode)
ansible-configure-macos:
    @just _devbox ansible_configure_macos_impl

[private]
ansible_configure_macos_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Configuring macOS host"
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_CONFIGURE_MACOS}} \
      --vault-password-file ~/.ansible/vault_password

# Install Xcode on macOS hosts via mas (Mac App Store CLI)
# Requires: Apple ID signed in to App Store (System Settings → App Store)
ansible-install-xcode:
    @just _devbox ansible_install_xcode_impl

[private]
ansible_install_xcode_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Installing Xcode on macOS hosts"
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_CONFIGURE_MACOS}} \
      --vault-password-file ~/.ansible/vault_password \
      --tags xcode

# Deploy Firefox enterprise policy (Bitwarden force-install, password manager
# disable, telemetry off, form autofill off, popups → tabs with full chrome)
# to macOS hosts. Requires root for .app/Contents/Resources/distribution.
ansible-deploy-firefox-policy-macos:
    @just _devbox ansible_deploy_firefox_policy_macos_impl

[private]
ansible_deploy_firefox_policy_macos_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Firefox enterprise policy to macOS hosts"
    ansible-playbook -i {{MACOS_INVENTORY}} {{PB_CONFIGURE_MACOS}} \
      --vault-password-file ~/.ansible/vault_password \
      --tags firefox-policy

# Deploy Firefox enterprise policy to OCI cloud server (Linux)
ansible-deploy-firefox-policy-oci:
    @just _devbox ansible_deploy_firefox_policy_oci_impl

[private]
ansible_deploy_firefox_policy_oci_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Firefox enterprise policy to OCI cloud server"
    ansible-playbook -i {{INVENTORY}} {{PB_BOOTSTRAP}} \
      --vault-password-file ~/.ansible/vault_password \
      --tags firefox-policy

# Deploy Firefox enterprise policy to Windows Docker host
ansible-deploy-firefox-policy-windows:
    @just _devbox ansible_deploy_firefox_policy_windows_impl

[private]
ansible_deploy_firefox_policy_windows_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying Firefox enterprise policy to Windows host"
    ansible-playbook -i {{WINDOWS_INVENTORY}} {{ANSIBLE_ROOT}}/playbooks/harden-windows-host.yml \
      --vault-password-file ~/.ansible/vault_password \
      --tags firefox-policy

# Deploy the sandbox CLI proxy (iron-proxy) to Mac hosts
deploy-sandbox-proxy-macos:
    @just _devbox deploy_sandbox_proxy_macos_impl

[private]
deploy_sandbox_proxy_macos_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying sandbox CLI proxy to macOS hosts"
    rtk ansible-playbook \
      -i {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories/macos-hosts.yml \
      {{ANSIBLE_ROOT}}/playbooks/deploy-sandbox-proxy.yml \
      --vault-password-file ~/.ansible/vault_password

# Deploy the sandbox CLI proxy (iron-proxy) to OCI cloud server
deploy-sandbox-proxy-oci:
    @just _devbox deploy_sandbox_proxy_oci_impl

[private]
deploy_sandbox_proxy_oci_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deploying sandbox CLI proxy to OCI cloud server"
    rtk ansible-playbook \
      -i {{INFRAHUB_ROOT}}/levonk/active/02-config/ansible/inventories/oci.yml \
      {{ANSIBLE_ROOT}}/playbooks/deploy-sandbox-proxy.yml \
      --vault-password-file ~/.ansible/vault_password

# === Sandboxed CLI Tools ===

# Run a sandboxed CLI tool through the iron-proxy egress boundary.
# Usage: just sandbox-run osint sherlock/sherlock "target.com"
sandbox-run profile image *args:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    SANDBOX_ENV="{{INFRAHUB_ROOT}}/.sandbox-env"
    if [ ! -f "$SANDBOX_ENV" ]; then
        log_error ".sandbox-env not found at $SANDBOX_ENV"
        log_warn "Deploy the sandbox proxy first: just deploy-sandbox-proxy-macos"
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
        log_error "Profile '{{profile}}' not found in .sandbox-env"
        log_warn "Available profiles: check $SANDBOX_ENV"
        exit 1
    fi
    log_info "Running {{image}} through sandbox profile '{{profile}}' (network: $NETWORK, proxy: $PROXY_HOST)"
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
    @just _devbox packer_build_impl

[private]
packer_build_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Building cloud server VM image with Packer"
    if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then
        cd {{PACKER_DIR}} && packer build cloud-server.pkr.hcl
    else
        log_warn "No Packer config found at {{PACKER_DIR}}/cloud-server.pkr.hcl"
        log_info "Create one to enable VM image builds."
    fi

packer-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Validating Packer configuration"
    if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then
        cd {{PACKER_DIR}} && packer validate cloud-server.pkr.hcl
    else
        log_warn "No Packer config found"
    fi

packer-init:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Initializing Packer plugins"
    if [ -f {{PACKER_DIR}}/cloud-server.pkr.hcl ]; then
        cd {{PACKER_DIR}} && packer init cloud-server.pkr.hcl
    else
        log_warn "No Packer config found"
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
    @just _devbox clean_impl

[private]
clean_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Cleaning build artifacts"
    rm -rf {{INFRAHUB_ROOT}}/logs/*.log
    docker system prune -f || true
    log_end "Cleanup complete"

clean-all:
    @just _devbox clean_all_impl

[private]
clean_all_impl:
    #!/usr/bin/env bash
    set -euo pipefail
    {{_log}}
    log_start "Deep cleaning all artifacts and caches"
    rm -rf {{INFRAHUB_ROOT}}/logs/*.log
    docker system prune -af || true
    docker volume prune -f || true
    log_end "Deep clean complete"
