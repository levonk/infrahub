# Isolation VM Task Index

**PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`  
**Feature**: Isolation VM for AI Agent Isolation  
**Created**: 2026-06-19  

## Overview

This document provides an index of all tasks for implementing the Isolation VM feature. Tasks are organized by sequential phases, with parallel stories within each phase that can be developed simultaneously using Git worktrees.

## Phase Summary

- **Phase 01**: Hypervisor Setup (5 parallel stories) - Foundation for VM operations
- **Phase 02**: VM Provisioning (3 parallel stories) - Create and configure the Isolation VM
- **Phase 03**: Agent Stack Deployment (4 parallel stories) - Deploy agent containers and integration
- **Phase 04**: Integration Testing (4 stories, last is sequential) - Validate functionality and performance

## Task Index

| Story ID | Story Title | Branch | Dependencies | Parallel-safe | Modules | Status |
| -------- | ----------- | ------ | ------------ | ------------- | ------- | ------ |
| 01-001 | Test Nested Virtualization Support | feature/current/isolation-vm/story-01-001-test-nested-virtualization | None | Parallel-safe: true | host-system | [x] Done |
| 01-002 | Install KVM/libvirt/QEMU Stack | feature/current/isolation-vm/story-01-002-install-hypervisor | None | Parallel-safe: true | host-system | [x] Done |
| 01-003 | Configure NAT Bridge Network | feature/current/isolation-vm/story-01-003-nat-bridge-network | None | Parallel-safe: true | networking | [x] Done |
| 01-004 | Configure Routed Bridge Network | feature/current/isolation-vm/story-01-004-routed-bridge-network | None | Parallel-safe: true | networking | [x] Done |
| 01-005 | Configure Storage Pools | feature/current/isolation-vm/story-01-005-storage-pools | None | Parallel-safe: true | storage | [x] Done |
| 02-001 | Create Debian Minimal VM | feature/current/isolation-vm/story-02-001-debian-vm | 01-001, 01-002, 01-003, 01-004, 01-005 | Parallel-safe: true | vm-provisioning | [x] Done |
| 02-002 | Install Docker Server in VM | feature/current/isolation-vm/story-02-002-docker-server | 02-001 | Parallel-safe: true | vm-services | [x] Done |
| 02-003 | Configure VM Networking and User Access | feature/current/isolation-vm/story-02-003-vm-networking-users | 02-001 | Parallel-safe: true | vm-config | [x] Done |
| 03-001 | Deploy Nix Sidecar Container | feature/current/isolation-vm/story-03-001-nix-sidecar | 02-002, 02-003 | Parallel-safe: true | containers | [x] Done |
| 03-002 | Deploy Base KaliNix Container | feature/current/isolation-vm/story-03-002-base-kalinix | 03-001 | Parallel-safe: true | containers | [x] Done |
| 03-003 | Deploy Hermes Agent Container | feature/current/isolation-vm/story-03-003-hermes-agent | 03-001, 03-002 | Parallel-safe: true | containers | [x] Done |
| 03-004 | Configure Volume Mounts and Networking | feature/current/isolation-vm/story-03-004-volume-network-config | 03-001, 03-002, 03-003 | Parallel-safe: true | container-config | [x] Done |
| 04-001 | Test Agent Container Docker Access | feature/current/isolation-vm/story-04-001-docker-access-test | 03-004 | Parallel-safe: true | testing | [!] Blocked |
| 04-002 | Verify Network Routing Through VPN | feature/current/isolation-vm/story-04-002-vpn-routing-test | 03-004 | Parallel-safe: true | testing | [x] Done |
| 04-003 | Test Isolation and Security Boundaries | feature/current/isolation-vm/story-04-003-isolation-security-test | 03-004 | Parallel-safe: true | testing | [~] In-Progress |
| 04-004 | Performance Testing and Optimization | feature/current/isolation-vm/story-04-004-performance-test | 04-001, 04-002, 04-003 | Parallel-safe: false | testing | [ ] Todo |

## Development Workflow

### Phase 01: Hypervisor Setup
All 5 stories can be developed in parallel using Git worktrees:
- 01-001: Test nested virtualization (decision point for KVM vs QEMU)
- 01-002: Install hypervisor stack
- 01-003: Configure NAT bridge network
- 01-004: Configure routed bridge network  
- 01-005: Configure storage pools

### Phase 02: VM Provisioning
All 3 stories can be developed in parallel after Phase 01 is complete:
- 02-001: Create Debian VM (depends on all Phase 01 stories)
- 02-002: Install Docker server (depends on 02-001)
- 02-003: Configure VM networking and users (depends on 02-001)

### Phase 03: Agent Stack Deployment
All 4 stories can be developed in parallel after Phase 02 is complete:
- 03-001: Deploy nix-sidecar (depends on 02-002, 02-003)
- 03-002: Deploy base-kalinix (depends on 03-001)
- 03-003: Deploy Hermes agent (depends on 03-001, 03-002)
- 03-004: Configure volumes and networking (depends on 03-001, 03-002, 03-003)

### Phase 04: Integration Testing
First 3 stories can be developed in parallel, last story is sequential:
- 04-001: Test Docker access (depends on 03-004)
- 04-002: Test VPN routing (depends on 03-004)
- 04-003: Test security isolation (depends on 03-004)
- 04-004: Performance testing (depends on 04-001, 04-002, 04-003) - sequential

## Key Dependencies

- **Story 01-001** is a critical decision point that affects subsequent hypervisor configuration
- **Phase 02** depends on completion of all Phase 01 stories
- **Phase 03** depends on completion of Phase 02, specifically Docker installation and VM configuration
- **Phase 04** depends on completion of Phase 03, with story 04-004 depending on all other Phase 04 stories

## Module Impact

- **host-system**: Hypervisor installation and configuration
- **networking**: Bridge network configuration and routing
- **storage**: Storage pool configuration for VM images
- **vm-provisioning**: VM creation and initial configuration
- **vm-services**: Docker server installation inside VM
- **vm-config**: VM networking, user access, and CLI tools
- **containers**: Agent container deployment (nix-sidecar, base-kalinix, Hermes)
- **container-config**: Volume mounts and networking integration
- **testing**: Integration, security, and performance testing

## Compliance Notes

All tasks must comply with:
- `/AGENTS.md` - Root project guidelines (IP/port rules, security audits)
- `shared/active/02-config/ansible/AGENTS.md` - Ansible-specific guidelines
- `shared/active/03-container/AGENTS.md` - Container-specific guidelines

All IP addresses, ports, and configuration values must be variable-driven per AGENTS.md requirements.

## Related Documentation

- **PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`
- **OCI Cloud Server Host PRD**: `shared/active/08-docs/reqs/2026/20260619-oci-cloud-server-host.md`
- **Task Index**: `internal-docs/feature/cloud-server/tasks/index-cloud-server.md`
