# OCI Cloud Server Host Requirements

**Date**: 2026-06-19  
**Updated**: 2026-06-19  
**Source**: Updated from `20260529-cloud-server.md` with current deployment state  
**Approach**: Phased rollout — each step builds on the previous, deployable independently.

---

## Architecture Overview

**Layer 1: Oracle Cloud Infrastructure** (Physical hardware - Oracle's responsibility)
  - **Layer 2: OCI Cloud Server Host** (VM we rent from Oracle, accessed via SSH)
    - Docker containers (most workloads: VPN, proxy, DNS, etc.)
    - **Layer 3: Isolation VM** (Nested QEMU VM for AI agent isolation)
      - Refer to `20260619-isolation-vm.md` for details

---

## Current Deployment State

**Already Installed on OCI Cloud Server Host:**
- Docker and Docker Compose
- NordVPN (WireGuard)
- Tailscale
- iron-proxy (egress firewall)
- RustDesk (remote desktop)
- NetBird client
- Tor proxy
- SSH hardening
- fail2ban
- Basic firewall rules

---

## Step 1: Host Foundation (COMPLETED)

**Goal**: Hardened, reproducible base system ready for container workloads.

### OS / Bootstrap
- [x] Fresh host provisioning
- [x] Refresh packages index
- [x] `openssh` — SSH server
- [x] Make sure passwordless root auth works with ed25519 keys
- [x] Upgrade existing packages
- [x] Enforce UTC timezone (`timedatectl set-timezone UTC`)
- [x] Create non-root user account (`cuser` or designated admin)
- [x] Configure sudo with passwordless escalation for admin user
- [x] Make sure passwordless cuser auth works with ed25519 keys
- [x] Configure automatic security updates (unattended-upgrades or equivalent)

### Tools Installation
- [x] `zsh` — default shell
- [x] `tmux` — terminal multiplexer
- [x] `curl`/`wget` — download tools
- [x] `git` — version control
- [x] CLI tools (eza, fd, fzf) via apt
- [x] Docker + Docker Compose (via traditional package manager)

### Container Runtime Hardening
- [x] Hardened `daemon.json`:
  - [x] `userns-remap` or rootless mode
  - [x] `no-new-privileges: true`
  - [x] `live-restore: true`

---

## Step 2: VPN Mesh Layer (Host) (COMPLETED)

**Goal**: Secure inbound/outbound connectivity with redundant VPN paths.

- [x] `tailscale` — overlay mesh VPN (host daemon)
- [x] `nordvpn` — WireGuard VPN (host daemon)
- [x] `netbird` client — gateway agent with WireGuard (host instance)
- [x] WireGuard kernel module / `wireguard-tools` present

### Host Security Layer
- [x] Host-level firewall (`nftables` or `ufw`) — default-deny, allow all VPN, ssh, and mosh connections
- [x] Log rotation (`logrotate` with Docker-aware policies)
- [x] Swap/file limits tuning (`vm.swappiness`, `fs.file-max`, `nofile` limits)
- [x] Firewall rules for VPN subnet routing (forwarding enabled, masquerade rules)

---

## Step 2.5: SSH Lockdown (COMPLETED)

**Goal**: Harden SSH immediately after confirming passwordless login works.

- [x] Verify passwordless SSH login works for the new user account (Step 1)
- [x] `PermitRootLogin no`
- [x] `PasswordAuthentication no`
- [x] `AuthenticationMethods publickey`
- [x] Restrict to `ed25519` keys (`PubkeyAcceptedAlgorithms`, `HostKeyAlgorithms`)
- [x] `MaxAuthTries 3`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`
- [x] Optional: non-standard port (variable-driven)
- [x] `fail2ban` — SSH brute-force protection (ban time, retry limits as variables)

---

## Step 3: Netbird Control Plane (Docker) (COMPLETED)

**Goal**: Self-hosted Netbird control plane for fully owned identity + routing.

- [x] `netbird-management` — Management Server container
- [x] `netbird-signal` — Signal / NAT traversal helper Server container
- [x] `netbird-turn` — TURN fallback relay Server container
- [x] Shared persistence volume(s) for SQLite/Postgres backend
- [x] OIDC / IdP integration (or local dummy IdP for bootstrap)
- [x] TLS termination (reverse proxy or container-native certs)

---

## Step 4: Infrastructure Services (Docker) (COMPLETED)

**Goal**: DNS, proxy, time, and identity services for downstream consumers.

### Network / Discovery
- [x] `dns` — Authoritative/caching DNS (see stack elsewhere)

### Proxy / Security
- [x] `iron-proxy` — Egress firewall for API access control
- [x] `nordvpn` — VPN container with WireGuard support
- [x] `tor` — Tor relay or onion service bridge
- [x] Reverse proxy capabilities

### Remote Access
- [x] `rustdesk` — Remote desktop access (hbbs/hbbr relay servers)

---

## Step 5: Isolation VM Foundation (IN PROGRESS)

**Goal**: Nested virtualization for AI agent isolation.

**Refer to**: `20260619-isolation-vm.md` for complete Isolation VM requirements.

### Hypervisor Setup
- [ ] KVM/libvirt/QEMU stack installation
- [ ] Test nested virtualization support on OCI hardware
- [ ] Fallback to QEMU without KVM if nested virtualization not supported
- [ ] Create bridge networks for VM networking
- [ ] Configure storage pools for VM images

### VM Networking
- [ ] NAT bridge for isolated VM network
- [ ] Routed bridge for VM-to-outside communication
- [ ] VPN integration for VM traffic routing

---

## Security Hardening (Cross-Cutting)

Items that span multiple steps and should be revisited at each phase:

- [ ] **IDS/IPS**: `snort` or `suricata` (host or VM-tapped interface)
- [ ] **Endpoint Detection**: `osquery` or `wazuh-agent` (lightweight)
- [ ] **Secrets Management**: SOPS, `age`, or HashiCorp Vault (container or VM)
- [ ] **Certificate Rotation**: Automated ACME + internal CA renewal
- [ ] **Backup Verification**: Periodic restore tests of container volumes

---

## Decisions / Questions

| Topic | Question | Status |
|-------|----------|--------|
| Nested Virtualization | Does OCI support nested KVM? If not, use QEMU without KVM | In Progress |
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
- `cloud_server_nordvpn_wireguard_host_port`
- `cloud_server_nordvpn_wireguard_container_port`
- `cloud_server_nordvpn_socks_host_port`
- `cloud_server_nordvpn_socks_container_port`
- `cloud_server_iron_proxy_dns_host_port`
- `cloud_server_iron_proxy_http_host_port`
- `cloud_server_iron_proxy_https_host_port`
- `cloud_server_rustdesk_hbbs_nat_test_host_port`
- `cloud_server_rustdesk_hbbs_id_reg_host_port`
- `cloud_server_rustdesk_hbbr_relay_host_port`
- `cloud_server_tor_socks_host_port`
- `cloud_server_tor_socks_container_port`

---

## Dependencies

- **Isolation VM**: Refer to `20260619-isolation-vm.md` for nested VM requirements
- **Container Services**: All container definitions in `shared/active/03-container/services/`
- **Ansible Roles**: All roles in `shared/active/02-config/ansible/roles/`
- **Guidelines**: 
  - `/AGENTS.md` - Root project guidelines (IP/port rules, security audits)
  - `shared/active/02-config/ansible/AGENTS.md` - Ansible-specific guidelines
  - `shared/active/03-container/AGENTS.md` - Container-specific guidelines

---

## Success Criteria

- [ ] All host services running in Docker containers
- [ ] VPN mesh operational (Tailscale + NordVPN + NetBird)
- [ ] SSH hardening verified
- [ ] Egress firewall (iron-proxy) functional
- [ ] Remote desktop (RustDesk) accessible via VPN
- [ ] Isolation VM can be created and managed
- [ ] All security hardening measures in place
- [ ] No hardcoded IPs or ports in configuration

---

*Updated from 20260529-cloud-server.md to reflect current deployment state and clarify architecture layers*