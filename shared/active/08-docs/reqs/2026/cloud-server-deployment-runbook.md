# Cloud Server Deployment Runbook

## Overview

This runbook documents the complete process for deploying cloud server infrastructure to Oracle Cloud Infrastructure (OCI) hosts. It covers bootstrap, VPN, infrastructure services, VM layer, and security hardening.

## Prerequisites

### Local Environment

- Devbox environment configured (`devbox.json`)
- Ansible installed via devbox
- SSH access to OCI host with appropriate key
- OCI host IP address and SSH key path

### OCI Host Requirements

- Oracle Linux 9 (or compatible RedHat family OS)
- Minimum 2 CPU cores, 8GB RAM (for VM workloads)
- ARM Neoverse-N1 or x86_64 architecture
- Internet connectivity for package downloads

## Deployment Phases

### Phase 01: Variables & Inventory

**Purpose**: Define all configuration variables and inventory for the target host.

**Steps**:
1. Create/update inventory file: `levonk/active/02-config/ansible/inventories/oci.yml`
2. Define host variables in `levonk/active/02-config/ansible/host_vars/<hostname>.yml`
3. Define group variables in `levonk/active/02-config/ansible/inventories/group_vars/cloud_servers.yml`

**Key Variables**:
```yaml
# Host-specific
ansible_host: "161.153.91.163"
ansible_user: "opc"  # Bootstrap user
ansible_ssh_private_key_file: "~/.ssh/lzkmbp2016-micro-oracle"

# Group variables
cloud_server_admin_user: "cuser"
cloud_server_admin_group: "wheel"  # RedHat uses wheel, Debian uses sudo
```

### Phase 02: Role Development

**Purpose**: Develop Ansible roles for each component (already completed in this project).

**Roles**:
- `host-os-bootstrap` - System bootstrap (users, timezone, updates)
- `nix-installation` - Nix package manager installation
- `docker-engine` - Docker and Docker Compose
- `nix-core-tools` - Neovim, devbox via Nix
- `vpn-tailscale` - Tailscale VPN client
- `vpn-netbird` - Netbird VPN client
- `proxy-firewall` - Firewall configuration (firewalld/ufw)
- `common-ssh-hardening` - SSH hardening
- `common-fail2ban` - Fail2ban intrusion prevention
- `dns-coredns` - CoreDNS service
- `forward-proxy` - Proxy stack (Tor, Squid, Traefik)
- `vpn-netbird-control` - Netbird control plane (optional)

### Phase 03: Playbook Creation

**Purpose**: Create playbooks that orchestrate role deployment.

**Playbooks**:
- `cloud-server-bootstrap.yml` - Bootstrap deployment
- `cloud-server-vpn.yml` - VPN and security hardening
- `cloud-server-infra.yml` - Infrastructure services
- `cloud-server-vms.yml` - VM hypervisor layer
- `cloud-server-site.yml` - Complete site deployment

### Phase 04: Lint & Test

**Purpose**: Validate Ansible code quality and configuration.

**Commands**:
```bash
# Lint all roles and playbooks
just ansible-lint

# Check playbook syntax
just ansible-syntax

# Run Molecule tests (Docker-backed)
just ansible-test
```

### Phase 05: Deploy to OCI

**Purpose**: Execute deployment playbooks on the target OCI host.

**Important**: Always use `devbox run` for Ansible operations.

#### 5.1: Bootstrap Deployment

**Command**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml"
```

**What it does**:
- Creates admin user with sudo access
- Configures timezone (UTC)
- Installs Docker and Docker Compose
- Configures automatic security updates (dnf-automatic)
- Installs Nix package manager (multi-user mode)
- Installs Nix tools (neovim, devbox)

**Oracle Linux Specifics**:
- SELinux must be set to permissive mode for Nix multi-user installation
- Use `setenforce 0` temporarily and update `/etc/selinux/config` for persistence
- Add SELinux configuration to `host-os-bootstrap` role

**Validation**:
```bash
# Run validation playbook
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-bootstrap.yml"
```

#### 5.2: VPN & Security Deployment

**Command**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml"
```

**What it does**:
- Installs Tailscale VPN client
- Installs Netbird VPN client
- Configures firewall (firewalld for RedHat, ufw for Debian)
- Applies SSH hardening (PermitRootLogin prohibit-password, PasswordAuthentication no)
- Configures fail2ban with SSH jail

**Pre-Deployment Checks**:
- Verify passwordless SSH login works before applying hardening
- Copy authorized_keys from bootstrap user to admin user
- Test SSH connectivity with new admin user

**Validation**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vpn.yml"
```

#### 5.3: Infrastructure Services Deployment

**Command**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml"
```

**What it does**:
- Deploys CoreDNS service
- Deploys proxy stack (Tor, Squid, Traefik)
- Optionally deploys Netbird control plane (management, signal, relay)
- Configures Docker networks for service communication

**Configuration Requirements**:
- Define infrastructure directory variables in group_vars
- Configure service ports as variables (no hardcoded ports)
- Set up proper volume mounts for persistent data

**Validation**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-infra.yml"
```

#### 5.4: VM Layer Deployment

**Command**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml"
```

**What it does**:
- Installs QEMU/libvirt for virtualization
- Configures bridge networks for VM networking
- Sets up libvirt storage pools
- Creates VM templates (if defined)

**Architecture Considerations**:
- x86_64: Uses KVM (hardware virtualization)
- ARM (aarch64): Uses QEMU (software virtualization)
- Playbook automatically detects architecture and skips KVM checks on ARM

**Validation**:
```bash
~/.nix-profile/bin/devbox run --config ~/p/gh/levonk/infrahub/devbox.json sh -c "cd ~/p/gh/levonk/infrahub && ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vms.yml"
```

### Phase 06: Validation & Final Audit

**Purpose**: Validate all deployments and perform security audit.

**Validation Playbooks**:
```bash
# Validate bootstrap
just ansible-validate-bootstrap

# Validate VPN
just ansible-validate-vpn

# Validate infrastructure
just ansible-validate-infra

# Validate VMs
just ansible-validate-vms
```

**Final Security Audit**:
```bash
just ansible-final-audit
```

**Audit Checks**:
- SSH connectivity and configuration
- No hardcoded IPs/ports in deployed configs
- SSH hardening (PermitRootLogin, PasswordAuthentication, key types)
- Firewall default-deny policy
- fail2ban service and jail status
- Docker daemon hardening
- Automatic security updates
- Container image ages

## Troubleshooting

### Common Issues

**1. SELinux blocking Nix installation**
- Symptom: Nix installer fails with permission denied
- Solution: Set SELinux to permissive mode (`setenforce 0` and update `/etc/selinux/config`)

**2. SSH lockout after hardening**
- Symptom: Cannot SSH after applying SSH hardening
- Prevention: Copy authorized_keys from bootstrap user to admin user before hardening
- Recovery: Use OCI console to access host via serial console

**3. Docker iptables/firewalld conflict**
- Symptom: Docker networking fails after firewall configuration
- Solution: Restart Docker service after firewall changes

**4. ACL permission errors on Oracle Linux**
- Symptom: `become_user` fails with permission errors
- Solution: Replace `become_user` with `sudo -u` commands in Ansible roles

**5. ARM architecture KVM issues**
- Symptom: KVM checks fail on ARM hosts
- Solution: Playbook automatically detects architecture and uses QEMU instead

### Debug Commands

```bash
# Check Ansible connectivity
ansible -i levonk/active/02-config/ansible/inventories/oci.yml cloud_servers -m ping

# Check Docker status
ansible -i levonk/active/02-config/ansible/inventories/oci.yml cloud_servers -m shell -a "docker ps" -b

# Check service status
ansible -i levonk/active/02-config/ansible/inventories/oci.yml cloud_servers -m systemd -a "name=docker"

# Check firewall rules
ansible -i levonk/active/02-config/ansible/inventories/oci.yml cloud_servers -m shell -a "firewall-cmd --list-all" -b
```

## Best Practices

### Variable Management

- **Always use variables** for IPs, ports, and configuration values
- Define variables in `group_vars` for shared settings
- Define variables in `host_vars` for host-specific settings
- Never hardcode IPs or ports in playbooks or roles

### Security

- Use SSH key authentication only (disable password auth)
- Apply SSH hardening early in deployment
- Configure fail2ban to prevent brute-force attacks
- Keep container images updated
- Run final security audit before declaring deployment complete

### Oracle Linux Specifics

- Use `wheel` group instead of `sudo` for admin users
- Use `dnf` instead of `apt` for package management
- Use `dnf-automatic` for automatic security updates
- Set SELinux to permissive mode for Nix compatibility
- Use `sshd` instead of `ssh` for service name

### Git Workflow

- Create feature branches for each deployment phase
- Commit changes after each successful phase
- Use descriptive commit messages with conventional commit format
- Push changes to remote after completion

## Rollback Procedures

### Bootstrap Rollback

If bootstrap deployment fails:
1. SSH to host with bootstrap user (opc)
2. Remove admin user: `userdel -r cuser`
3. Remove Docker: `dnf remove docker docker-compose`
4. Remove Nix: `/nix/nix-installer uninstall`
5. Re-run bootstrap playbook

### VPN Rollback

If VPN deployment causes lockout:
1. Access host via OCI console serial console
2. Disable fail2ban: `systemctl stop fail2ban`
3. Restore SSH config from backup
4. Re-run VPN playbook

### Infrastructure Rollback

If infrastructure services fail:
1. Stop all containers: `docker stop $(docker ps -aq)`
2. Remove containers: `docker rm $(docker ps -aq)`
3. Remove volumes: `docker volume rm $(docker volume ls -q)`
4. Re-run infrastructure playbook

## References

- PRD: `shared/active/08-docs/reqs/2026/20260529-cloud-server.md`
- Task Index: `internal-docs/feature/cloud-server/tasks/index-cloud-server.md`
- AGENTS.md: Project guidelines and conventions
- Justfile: Available commands and recipes

## Version History

- 2026-06-07: Initial runbook created based on cloud-server deployment experience
