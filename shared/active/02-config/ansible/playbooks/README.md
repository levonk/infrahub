# Ansible Playbooks

Shared playbooks for the infrahub infrastructure.

## Available Playbooks

### `cloud-server-bootstrap.yml`

Bootstraps cloud servers with foundational infrastructure:
- Host OS bootstrap (`host-os-bootstrap`)
- Nix package manager installation (`nix-installation`)
- Docker engine setup (`docker-engine`)
- Nix core tools installation (`nix-core-tools`)

**Usage:**

```bash
# Syntax check
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml --syntax-check

# Dry-run
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml --check --diff

# Deploy
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml
```

**Target group:** `cloud_servers`

**Requires:**
- `cloud_server_admin_user` defined in `group_vars`
- `cloud_server_ansible_host_ip` defined in `group_vars`
- `cloud_server_ssh_host_port` defined in `group_vars`

### `cloud-server-site.yml`

Top-level site playbook that deploys the entire cloud server stack in the correct order. This is the recommended entry point for full deployments.

**Deployment Order:**

1. **Phase 1: Bootstrap** (`cloud-server-bootstrap.yml`)
   - Host OS bootstrap, Nix, Docker, core tools
   - Prerequisite for all subsequent phases

2. **Phase 2: VPN & Security** (`cloud-server-vpn.yml`)
   - Tailscale, Netbird client, firewall, SSH hardening, fail2ban
   - Requires: Bootstrap completed

3. **Phase 3: Infrastructure Services** (`cloud-server-infra.yml`)
   - Netbird control plane, DNS (CoreDNS), proxy (Traefik), SSO (Authelia)
   - Requires: Bootstrap completed, VPN mesh established

4. **Phase 4: VM Hypervisor** (`cloud-server-vms.yml`)
   - KVM, libvirt, networks, storage pools
   - Requires: Bootstrap completed

**Usage:**

```bash
# Full deployment (all phases)
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml

# Dry-run to preview changes
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml --check --diff

# Resume from specific phase if deployment fails
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml --start-at-task="Import Phase 2: VPN and Security Playbook"

# Deploy only specific phases using tags
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml --tags "bootstrap"
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml --tags "vpn,security"
```

**Target group:** `cloud_servers`

**Pre-tasks:**
- Display deployment start information (target, OS, architecture, timestamp)
- Validate required site-level variables
- Validate SSH connectivity to target host
- Check available disk space (warn if >80% used)

**Post-tasks:**
- Verify Docker is accessible
- Verify Nix is accessible
- Verify libvirt is accessible
- Display final deployment summary with component status
- Log deployment completion to `/var/log/cloud-server-deploy.log`

**Rollback Strategy:**

Each phase playbook is idempotent and can be re-run safely. For rollback scenarios:

- **Resume from failure:** Use `--start-at-task` to resume from the specific phase that failed
- **Partial rollback:** Re-run the previous phase's playbook with `--check --diff` to verify state, then manually revert if needed
- **Full rollback:** Manually revert each phase in reverse order:
  1. Revert VM hypervisor (Phase 4)
  2. Revert infrastructure services (Phase 3)
  3. Revert VPN & security (Phase 2)
  4. Revert bootstrap (Phase 1)

**Note:** Full rollback requires manual intervention as Ansible does not have built-in rollback capabilities. The recommended approach is to fix the issue and re-deploy the affected phase.

### `site.yml`

Full site playbook that deploys all enabled stacks.

**Usage:**

```bash
ansible-playbook -i inventories/localnet.yml playbooks/site.yml
```

### `dns-stack.yml`

Deploys the DNS stack.

### `proxy-stack.yml`

Deploys the proxy/web stack.

### `cloud-server-infra.yml`

Deploys infrastructure services on cloud servers as Docker containers:
- Netbird control plane (management, signal, TURN relay) — `vpn-netbird-control`
- DNS stack (CoreDNS) — `dns-coredns`
- Reverse proxy (Traefik) — `proxy-traefik`
- SSO service (Authelia) — `proxy-authelia`

**Usage:**

```bash
# Syntax check
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-infra.yml --syntax-check

# Dry-run
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-infra.yml --check --diff

# Deploy
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-infra.yml
```

**Target group:** `cloud_servers`

**Requires:**
- `cloud_server_admin_user` defined in `group_vars`
- `cloud_server_ansible_host_ip` defined in `group_vars`
- `cloud_server_ssh_host_port` defined in `group_vars`
- Docker engine installed and running (run `cloud-server-bootstrap.yml` first)

**Pre-tasks:**
- Validate required cloud_server variables
- Verify Docker CLI is installed
- Verify Docker daemon is responsive

**Post-tasks:**
- Verify all infrastructure containers are running
- HTTP probe for Traefik ping endpoint
- HTTP probe for Authelia health endpoint
- DNS query verification via CoreDNS

### `cloud-server-vms.yml`

Sets up the KVM hypervisor on cloud servers for VM workloads:
- CPU virtualization support verification (Intel VT-x / AMD-V)
- KVM packages and libvirtd installation (`common-kvm` role)
- NAT and routed bridge networks
- VM storage pool configuration
- Post-deployment verification of libvirt stack

**Usage:**

```bash
# Syntax check
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml --syntax-check

# Dry-run
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml --check --diff

# Deploy
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml
```

**Target group:** `cloud_servers`

**Requires:**
- `cloud_server_admin_user` defined in `group_vars`
- Nested virtualization or bare-metal host with VT-x/AMD-V

### `test-nested-virtualization.yml`

Cross-platform nested virtualization support test. Works on both Linux (OCI cloud server) and Windows (Docker Desktop / WSL2). Determines whether a host can run KVM-accelerated nested VMs (critical for services like garnix-ci that need `/dev/kvm`).

**Linux path:** Checks CPU flags (vmx/svm), KVM module, and nested parameter (Intel/AMD). Can attempt to enable nested virt via `modprobe`.

**Windows path:** Checks Windows version (11+ required, build >= 22000), CPU firmware virtualization, Virtual Machine Platform feature, WSL2 `nestedVirtualization` setting in `.wslconfig`, and `/dev/kvm` availability inside WSL2.

**Key finding:** WSL2 nested virtualization is ON BY DEFAULT on Windows 11 amd64 (since WSL build 20175). Does NOT require Enterprise — works on Home and Pro. Windows 10 does NOT support it.

**Usage:**

```bash
# Linux only (OCI cloud server):
just ansible-test-nested-virt

# Windows only (dtop202311):
just ansible-test-nested-virt-windows

# Both platforms:
just ansible-test-nested-virt-all
```

**Target groups:** `cloud_servers` (Linux play), `windows_docker_hosts` (Windows play)

**Output:** Sets `nested_virtualization_supported` fact and displays a summary report with recommendation.

### `deploy-nix-cache-and-garnix.yml`

Deploys the Nix cache chain (Harmonia + ncps + ncro) and garnix-ci CI builder on the Windows Docker host (dtop202311, nl region). All services share the nix-sidecar's `/nix/store` volume for maximum package reuse — Nix builds in garnix-ci use already-downloaded packages instead of re-downloading from cache.nixos.org.

**Architecture (ADR-20260708001):**
- **Harmonia** (`127.0.0.1:4523`) — serves local `/nix/store` read-only (sub-millisecond hits)
- **ncro** (`127.0.0.1:4525`) — parallel racing proxy, races all upstream caches in parallel
- **ncps** (`cache.nl.levonk.com:4524`) — NAR caching proxy, front door for Nix clients
- **garnix-ci** (`ci.nl.levonk.com:4526/4527`) — Nix CI builder with `/dev/kvm` + shared nix store

**Usage:**
```bash
# Deploy everything (cache chain + garnix-ci):
just ansible-deploy-nix-cache-garnix

# Deploy only the cache chain (skip garnix-ci):
just ansible-deploy-nix-cache

# Deploy only garnix-ci (skip cache chain):
just ansible-deploy-garnix-ci
```

**Target group:** `windows_docker_hosts`

**Prerequisites:**
- nix-sidecar running on dtop202311 (manages the shared `/nix/store`)
- Traefik Windows deployed (routes `cache.nl.levonk.com` and `ci.nl.levonk.com`)
- WSL2 KVM enabled (for garnix-ci `/dev/kvm`): `just ansible-enable-wsl2-kvm`
- DNS CNAMEs configured: `just ansible-deploy-dns`
- Container images built and available on the Windows Docker host

### `vpn-stack.yml`

Deploys the VPN stack.
