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

### `vpn-stack.yml`

Deploys the VPN stack.
