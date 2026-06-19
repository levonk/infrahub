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
    devbox run bootstrap

bootstrap-internal:
    @echo "Bootstrapping infrahub environment..."
    just setup-internal
    just prime-internal
    @echo "Bootstrap complete."

prime:
    devbox run prime

prime-internal:
    @echo "Priming code indexing..."
    @echo "Prime complete."

doctor:
    devbox run doctor

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

# === Standard Quality Gates ===

build:
    devbox run build

build-internal:
    @echo "Building all infrahub components..."
    @echo "(Add component-specific build steps here)"

test:
    devbox run test

test-internal:
    @echo "Running all tests..."
    just ansible-test-internal

lint:
    devbox run lint

lint-internal:
    @echo "Running all lints..."
    just ansible-lint-internal

quality:
    just lint
    just test

# === Ansible Lifecycle Commands ===

# -- Lint & Syntax Check --

ansible-lint:
    devbox run ansible-lint

ansible-lint-internal:
    @echo "Running ansible-lint across roles and playbooks..."
    ansible-lint {{ANSIBLE_ROOT}}/roles/ {{ANSIBLE_ROOT}}/playbooks/ || true
    @echo "ansible-lint complete."

ansible-syntax:
    devbox run ansible-syntax

ansible-syntax-internal:
    @echo "Checking playbook syntax..."
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_BOOTSTRAP}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_VPN}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_INFRA}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_VMS}} || true
    ansible-playbook --syntax-check -i {{INVENTORY}} {{PB_SITE}} || true
    @echo "Syntax check complete."

# -- Molecule Tests (Docker-backed) --

ansible-test:
    devbox run ansible-test

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
    @echo "Running Molecule test for role: {{role}}..."
    cd {{MOLECULE_DIR}}/{{role}} && molecule test

molecule-converge role:
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

# -- Local Network Deployment --

ansible-deploy-localnet-tailscale:
    devbox run ansible-deploy-localnet-tailscale

ansible-deploy-localnet-tailscale-internal:
    @echo "Deploying Tailscale to local network hosts..."
    ansible-playbook -i {{LOCALNET_INVENTORY}} {{PB_LOCALNET_TAILSCALE}} --ask-vault-pass

# -- Validation Playbooks --

ansible-validate-bootstrap:
    devbox run ansible-validate-bootstrap

ansible-validate-bootstrap-internal:
    @echo "Validating bootstrap deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_BOOTSTRAP}}

ansible-validate-vpn:
    devbox run ansible-validate-vpn

ansible-validate-vpn-internal:
    @echo "Validating VPN deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_VPN}}

ansible-validate-infra:
    devbox run ansible-validate-infra

ansible-validate-infra-internal:
    @echo "Validating infrastructure deployment..."
    ansible-playbook -i {{INVENTORY}} {{PB_VAL_INFRA}}

ansible-validate-vms:
    devbox run ansible-validate-vms

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
    devbox run ansible-final-audit

ansible-final-audit-internal:
    @echo "Running final security audit..."
    ansible-playbook -i {{INVENTORY}} {{PB_FINAL_AUDIT}}

# === Packer VM Image Creation ===

packer-build:
    devbox run packer-build

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
