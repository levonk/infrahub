# Cloud Server Requirements (ARCHIVED)

**Date**: 2026-05-29  
**Archived**: 2026-06-19  
**Reason**: Split into separate PRDs for clarity - see `20260619-oci-cloud-server-host.md` and `20260619-isolation-vm.md`  
**Source**: `shared/active/03-container/internal-docs/todo/todo-priorities.md` (Cloud Server section)  
**Approach**: Phased rollout — each step builds on the previous, deployable independently.

---

## ⚠️ ARCHIVED DOCUMENT

This PRD has been split into two separate documents for better clarity:

1. **OCI Cloud Server Host**: `20260619-oci-cloud-server-host.md`
   - Focuses on the Oracle Cloud VM host
   - Docker containers for VPN, proxy, DNS, etc.
   - Current deployment state and completed items

2. **Isolation VM**: `20260619-isolation-vm.md`
   - Focuses on the nested QEMU VM for AI agent isolation
   - Docker-in-Docker capabilities for agent workloads
   - Kali + Nix + Hermes agent stack

Please refer to the updated documents for current requirements.

---

## Dependencies

- **Updated PRDs**: Refer to `20260619-oci-cloud-server-host.md` and `20260619-isolation-vm.md`
- **Guidelines**: 
  - `/AGENTS.md` - Root project guidelines (IP/port rules, security audits)
  - `shared/active/02-config/ansible/AGENTS.md` - Ansible-specific guidelines
  - `shared/active/03-container/AGENTS.md` - Container-specific guidelines

---

## Step 1: Host Foundation

**Goal**: Hardened, reproducible base system ready for container workloads.

### OS / Bootstrap
- [ ] Fresh host provisioning
- [ ] Refresh packages index
- [ ] `openssh` — SSH server
- [ ] Make sure passwordless root auth works with ed25519 keys
- [ ] Upgrade existing packages
- [ ] Enforce UTC timezone (`timedatectl set-timezone UTC`)
- [ ] Create non-root user account (`cuser` or designated admin)
- [ ] Configure sudo with passwordless escalation for admin user
- [ ] Make sure passwordless cuser auth works with ed25519 keys
- [ ] Configure automatic security updates (unattended-upgrades or equivalent)

### Nix Foundation (Install First)
- [ ] Nix multi-user installation (daemon mode)
  - **Note**: On RedHat family systems (e.g., Oracle Linux), SELinux must be set to permissive mode for multi-user Nix to work. Nix does not support SELinux enforcing mode yet (see https://github.com/NixOS/nix/issues/2374)
- [ ] Add admin user to `nixbld` group
- [ ] Enable flakes: `experimental-features = nix-command flakes` in `/etc/nix/nix.conf`
- [ ] Verify `nix` CLI works for admin user

### Tools via Nix
- [ ] `zsh` — default shell (from nixpkgs)
- [ ] `neovim` — editor (from nixpkgs)
- [ ] `mosh` — mobile/lossy shell alternative (from nixpkgs)
  - [ ] Install but do not configure restrictive firewall rules until after Step 2.5
- [ ] `docker` + `docker-compose` plugin (from nixpkgs or Docker's Nix expression)
- [ ] `chrony` or `systemd-timesyncd` — time sync (from nixpkgs or OS package manager if preferred)
- [ ] `devbox` — per-project environment management (from nixpkgs or official installer)

### Container Runtime Hardening
- [ ] Hardened `daemon.json`:
  - [ ] `userns-remap` or rootless mode
  - [ ] `no-new-privileges: true`
  - [ ] `live-restore: true`
- [ ] `ddns` — Docker-based dynamic DNS updater (cloudflare, porkbun, or registrar API)

### Missing / To Confirm
- [ ] Kernel hardening (`sysctl` knobs: `kernel.unprivileged_bpf_disabled`, `net.ipv4.conf.all.rp_filter`, etc.)
- [ ] Audit framework (`auditd`) or `auditd`-less alternative
- [ ] Disk encryption at rest (if cloud provider supports it)
- [ ] Backup target configuration (restic/rclone to offsite)

---

## Step 2: VPN Mesh Layer (Host)

**Goal**: Secure inbound/outbound connectivity with redundant VPN paths.

- [ ] `tailscale` — overlay mesh VPN (host daemon)
- [ ] `netbird` client — gateway agent with WireGuard (host instance)
  - [ ] Join to self-hosted control plane (Step 3) or managed Netbird initially
- [ ] WireGuard kernel module / `wireguard-tools` present

### Host Security Layer
- [ ] Host-level firewall (`nftables` or `ufw`) — default-deny, allow all VPN, ssh, and mosh connections
- [ ] One by one, remove allow from remote access and test until ssh is the only publically ingress allow
- [ ] Log rotation (`logrotate` with Docker-aware policies)
- [ ] Swap/file limits tuning (`vm.swappiness`, `fs.file-max`, `nofile` limits)
- [ ] Basic node monitoring (`node_exporter` from nixpkgs, or equivalent, minimal)

- [ ] Firewall rules for VPN subnet routing (forwarding enabled, masquerade rules)

---

## Step 2.5: SSH Lockdown

**Goal**: Harden SSH immediately after confirming passwordless login works.

- [ ] Verify passwordless SSH login works for the new user account (Step 1)
- [ ] `PermitRootLogin no`
- [ ] `PasswordAuthentication no`
- [ ] `AuthenticationMethods publickey`
- [ ] Restrict to `ed25519` keys (`PubkeyAcceptedAlgorithms`, `HostKeyAlgorithms`)
- [ ] `MaxAuthTries 3`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`
- [ ] Optional: non-standard port (variable-driven)
- [ ] `fail2ban` — SSH brute-force protection (ban time, retry limits as variables)

---

## Step 3: Netbird Control Plane (Docker)

**Goal**: Self-hosted Netbird control plane for fully owned identity + routing.

- [ ] `netbird-management` — Management Server container
- [ ] `netbird-signal` — Signal / NAT traversal helper Server container
- [ ] `netbird-turn` — TURN fallback relay Server container
- [ ] Shared persistence volume(s) for SQLite/Postgres backend
- [ ] OIDC / IdP integration (or local dummy IdP for bootstrap)
- [ ] TLS termination (reverse proxy or container-native certs)

---

## Step 4: Infrastructure Services (Docker)

**Goal**: DNS, proxy, time, and identity services for downstream consumers.

### Network / Discovery
- [ ] `dns` — Authoritative/caching DNS (see stack elsewhere)

### Time
- [ ] `ntp` / `chrony` container — stratum-2 or stratum-3 time source for internal network

### Identity / Access
- [ ] `sso` — Redundant Single Sign-On (Authelia, Keycloak, or Authentik)

### Proxy / Security
- [ ] `caching-proxy` — Squid or Envoy with cache tier
- [ ] `reverse-proxy` — Traefik or Envoy with automatic cert discovery
- [ ] `tor` — Tor relay or onion service bridge (as needed)
- [ ] `cert-authority` — Internal ACME-compatible CA or step-ca for mTLS

---

## Step 5: Virtualization + Isolated Workloads

**Goal**: KVM/libvirt VMs for compartmentalized/isolated environments.

### Hypervisor
- [ ] `kvm` / `libvirt` / `qemu` stack
- [ ] `virt-manager` or `virsh` CLI tooling
- [ ] VM networking: NAT + bridge for isolated and routed guests

### VM: Netbird Gateway
- [ ] VM guest running Netbird Gateway Agent (WireGuard)
- [ ] Separate from host Netbird client for isolation

### Docker Guest ("Paperclip" / Workload VM)
- [ ] Nested Docker inside VM (or containerd/podman for lighter footprint)
- [ ] Services inside VM guest:
  - [ ] `paperclip` — (TBD service)
  - [ ] Dedicated GitHub account automation / bot runner
  - [ ] Dedicated Google Account automation / API consumer
  - [ ] Routing paths:
    - [ ] `Outside -> VPN + Tor -> Outside` (anonymized egress)
    - [ ] `Inside -> VPN -> Outside` (split tunnel / trusted path)
  - [ ] `rustdesk` — Remote help / desktop access container

### Security Tools VM
- [ ] `kali-linux` — Security assessment / penetration testing VM
- [ ] Network isolation: restricted bridge or routed VLAN

### VM: Docker Guest ("Hermes" / Workload VM)
- [ ] Nested Docker inside VM (or containerd/podman for lighter footprint)
- [ ] Services inside VM guest:
  - [ ] `hermes-agent` — (TBD service)
  - [ ] Dedicated GitHub account automation / bot runner
  - [ ] Dedicated Google Account automation / API consumer
  - [ ] `openfang` 
  - [ ] Routing paths:
    - [ ] `Outside -> VPN + Tor -> Outside` (anonymized egress)
    - [ ] `Inside -> VPN -> Outside` (split tunnel / trusted path)

---

## Security Hardening (Cross-Cutting)

Items that span multiple steps and should be revisited at each phase:

- [ ] **IDS/IPS**: `snort` or `suricata` (host or VM-tapped interface)
- [ ] **Endpoint Detection**: `osquery` or `wazuh-agent` (lightweight)
- [ ] **Secrets Management**: SOPS, `age`, or HashiCorp Vault (container or VM)
- [ ] **Certificate Rotation**: Automated ACME + internal CA renewal
- [ ] **Backup Verification**: Periodic restore tests of VM snapshots and container volumes

---

## Decisions / Questions

| Topic | Question | Status |
|-------|----------|--------|
| Terminal multiplexer | `tmux` + AI plugins, `zellij`, or both? | Open |
| Netbird hosting | Self-hosted control plane immediately, or migrate from managed later? | Open |
| DNS software | AdGuard Home, CoreDNS, dnsdist, or stacked? | Open |
| SSO backend | Authelia, Keycloak, Authentik, or levonk custom? | Open |
| Proxy stack | Traefik + Envoy hybrid, or single tool? | Open |
| VM storage | LVM-thin, ZFS, or qcow2 on ext4? | Open |

---

## Variable Checklist (Ansible / Compose)

Per `/AGENTS.md` IP/port rules — all values below **must** be variables, never hardcoded:

- `cloud_server_ansible_host_ip`
- `cloud_server_ssh_host_port`
- `cloud_server_ssh_container_port`
- `cloud_server_fail2ban_bantime`
- `cloud_server_tailscale_port`
- `cloud_server_netbird_mgmt_host_port`
- `cloud_server_netbird_mgmt_container_port`
- `cloud_server_netbird_signal_host_port`
- `cloud_server_netbird_signal_container_port`
- `cloud_server_netbird_turn_host_port`
- `cloud_server_netbird_turn_container_port`
- `cloud_server_dns_host_port`
- `cloud_server_dns_container_port`
- `cloud_server_proxy_http_host_port`
- `cloud_server_proxy_http_container_port`
- `cloud_server_proxy_https_host_port`
- `cloud_server_proxy_https_container_port`
- `cloud_server_tor_socks_host_port`
- `cloud_server_tor_socks_container_port`
- `cloud_server_ddns_update_interval`
- `cloud_server_kvm_bridge_subnet`
- `cloud_server_vm_netbird_gateway_ip`
