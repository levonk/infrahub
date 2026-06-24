# Isolation VM Requirements

**Date**: 2026-06-19  
**Source**: New requirement for AI agent isolation on OCI cloud server  
**Approach**: Nested virtualization for secure AI agent workloads with Docker-in-Docker capabilities.

---

## Architecture Overview

**Layer 1: Oracle Cloud Infrastructure** (Physical hardware - Oracle's responsibility)
  - **Layer 2: OCI Cloud Server Host** (VM we rent from Oracle)
    - Docker containers (VPN, proxy, DNS, etc.)
    - **Layer 3: Isolation VM** (Nested QEMU VM for AI agent isolation)
      - Docker server for agent-managed containers
      - AI agent containers (Kali + Nix + Hermes)

**Refer to**: `20260619-oci-cloud-server-host.md` for Layer 2 (OCI Cloud Server Host) requirements.

---

## Introduction / Overview

- **Feature name**: Isolation VM
- **Summary**: Nested virtualization environment for AI agent isolation with Docker-in-Docker capabilities
- **Context**:
  - AI agents need isolated environment to prevent interference with host services
  - Agents require ability to create and manage their own Docker containers
  - Security isolation between agent workloads and production services
  - Network isolation with controlled egress paths

---

## Goals

- Provide isolated environment for AI agent workloads
- Enable agents to create and manage Docker containers independently
- Maintain network isolation with controlled VPN/proxy routing
- Support Kali Linux + Nix + Hermes agent stack
- Ensure reproducible agent environment via containerization

---

## User Stories

- As a system administrator, I want to run AI agents in an isolated VM so they cannot affect production services
- As an AI agent, I want to create Docker containers for my projects so I can manage my own dependencies
- As a security engineer, I want network isolation for agent workloads so I can control egress paths
- As a developer, I want reproducible agent environments so I can test and debug agent behavior

---

## Functional Requirements

### Hypervisor Layer
- Install KVM/libvirt/QEMU stack on OCI Cloud Server Host
- Test nested virtualization support (fallback to QEMU without KVM if unsupported)
- Create NAT bridge network for VM isolation
- Create routed bridge network for VM-to-outside communication
- Configure storage pools for VM images

### Isolation VM Configuration
- Deploy Debian minimal base image to Isolation VM
- Install Docker server inside Isolation VM
- Configure Docker socket access for agent containers
- Install basic CLI tools (zsh, tmux, curl, git)
- Configure non-root user (cuser) with sudo access

### Agent Container Stack
- Deploy nix-sidecar container for Nix package management
- Deploy base-kalinix container for Kali Linux + Nix environment
- Deploy Hermes agent container with Docker socket access
- Configure volume mounts for Nix store sharing
- Configure network isolation and routing rules

### Network Integration
- Connect Isolation VM to VPN mesh via routed bridge
- Configure egress routing through host VPN/proxy stack
- Enable split-tunneling for agent workloads
- Configure firewall rules for VM network isolation

---

## Non-Functional Requirements

### Security
- VM must be isolated from host services
- Agent containers must not have access to host Docker socket
- Network egress must be controlled via VPN/proxy
- Root access must be restricted and audited

### Performance
- VM must have sufficient CPU/RAM for agent workloads
- Docker operations inside VM must perform adequately
- Network latency through VPN must be acceptable for agent operations

### Reliability
- VM must auto-start on host boot
- Docker daemon inside VM must be reliable
- Agent containers must be restartable without data loss
- VM snapshots/backups must be supported

### Maintainability
- VM provisioning must be automated via Ansible
- Container updates must be manageable without VM rebuild
- Debugging access must be available via VPN
- Logs must be accessible from host

---

## Technical Considerations

### Hypervisor Choice
- **Primary**: QEMU without KVM acceleration (nested virtualization NOT supported on OCI ARM aarch64)
- **Test Result**: OCI ARM instance (aarch64) does not support nested KVM virtualization
- **Performance Impact**: QEMU without KVM will have reduced performance but is functionally adequate
- **Test Date**: 2026-06-19
- **Test Details**: CPU architecture aarch64, KVM module not loaded, nested virtualization disabled

### VM Storage
- Use qcow2 images for VM disks
- Consider LVM-thin for better performance if supported
- Storage path: `/var/lib/libvirt/images` (configurable via variable)

### Networking
- NAT bridge: `kvm-nat-br0` (192.168.100.0/24)
- Routed bridge: `kvm-route-br0` (192.168.101.0/24)
- VM must be able to reach host VPN services
- Host must be able to route VM traffic through VPN

### Docker-in-Docker
- Docker server runs inside Isolation VM
- Agent containers mount Docker socket from VM
- No Docker-in-Docker (dind) - use socket binding instead
- Agent containers share VM's Docker daemon

### Nix Sidecar Pattern
- nix-sidecar provides Nix store to agent containers
- Volume mounts: `/nix` (read-only), `/nix-var-profiles` (read-only)
- Agent containers consume Nix from sidecar, not host
- Independent Nix environment per deployment

---

## Success Metrics

- Isolation VM can be created and started successfully
- Docker daemon inside VM is functional
- Agent containers can create and manage containers
- Network routing through VPN works correctly
- Agent workloads are isolated from host services
- VM performance is acceptable for agent operations
- VM can be recreated without data loss (persistent volumes)

---

## Open Questions

| Topic | Question | Status |
|-------|----------|--------|
| Nested Virtualization | Does OCI hardware support nested KVM? | Tested - NOT SUPPORTED (ARM aarch64) |
| VM Resources | CPU/RAM allocation for Isolation VM? | Open |
| Storage Backend | qcow2, LVM-thin, or other? | Decided - qcow2 (simplicity, compatibility, sparse allocation) |
| Backup Strategy | How to backup VM state and agent data? | Open |
| Monitoring | How to monitor VM and agent health? | Open |

---

## Dependencies

- **OCI Cloud Server Host**: `20260619-oci-cloud-server-host.md` must be completed first
- **Hypervisor Role**: `common-kvm` Ansible role must be installed on host
- **Network Configuration**: VPN and proxy services must be operational on host
- **Container Images**: base-kalinix, nix-sidecar must be built and available
- **Guidelines**: 
  - `/AGENTS.md` - Root project guidelines (IP/port rules, security audits)
  - `shared/active/02-config/ansible/AGENTS.md` - Ansible-specific guidelines
  - `shared/active/03-container/AGENTS.md` - Container-specific guidelines

---

## Timeline / Milestones

### Phase 1: Hypervisor Setup
- Test nested virtualization support on OCI hardware
- Install KVM/libvirt/QEMU stack
- Configure bridge networks and storage pools

### Phase 2: VM Provisioning
- Create Debian minimal VM image
- Install Docker server inside VM
- Configure basic networking and user access

### Phase 3: Agent Stack Deployment
- Deploy nix-sidecar container
- Deploy base-kalinix container
- Deploy Hermes agent container
- Configure volume mounts and networking

### Phase 4: Integration Testing
- Test agent container Docker access
- Verify network routing through VPN
- Test isolation and security boundaries
- Performance testing and optimization

---

## Variable Checklist (Ansible)

Per `/AGENTS.md` IP/port rules — all values below **must** be variables, never hardcoded:

- `isolation_vm_name`
- `isolation_vm_memory_mb`
- `isolation_vm_vcpus`
- `isolation_vm_disk_gb`
- `isolation_vm_nat_bridge_subnet`
- `isolation_vm_routed_bridge_subnet`
- `isolation_vm_ip_address`
- `isolation_vm_gateway_ip`

---

## Security Considerations

- VM must not have access to host Docker socket
- Agent containers must be isolated from host networks
- VPN credentials must not be exposed to agent containers
- Root access inside VM must be monitored and audited
- VM network must be firewalled from host services

---

*Generated from PRD template for Isolation VM requirements*