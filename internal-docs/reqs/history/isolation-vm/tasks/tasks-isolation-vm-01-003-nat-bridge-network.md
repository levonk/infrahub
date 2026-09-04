---
story_id: "01-003"
story_title: "Configure NAT Bridge Network"
story_name: "nat-bridge-network"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 1
parallel_id: 3
branch: "feature/current/isolation-vm/story-01-003-nat-bridge-network"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["networking"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "networking"]
due: "2026-06-26"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Configure a NAT bridge network for VM isolation. This provides internal network connectivity for VMs while isolating them from the host network.

## Sub-Tasks

- [x] Create libvirt network definition for NAT bridge (kvm-nat-br0)
- [x] Define network subnet using variable `isolation_vm_nat_bridge_subnet` (default: 192.168.100.0/24)
- [x] Configure DHCP settings for the NAT network
- [x] Create Ansible task to deploy network definition
- [x] Activate the NAT bridge network
- [x] Test network connectivity from host to bridge
- [x] Document network topology and IP allocation scheme

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/templates/network-nat.xml.j2` - Libvirt network template
- `shared/active/02-config/ansible/roles/common-kvm/tasks/main.yml` - Network configuration tasks
- `shared/active/02-config/ansible/roles/common-kvm/defaults/main.yml` - Network configuration variables
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Host-specific network variables

## Acceptance Criteria

- [x] NAT bridge network is defined in libvirt
- [x] Network is active and persistent
- [x] DHCP is functional on the bridge
- [x] Network subnet is configurable via variable
- [x] virsh net-list shows the NAT bridge as active

## Test Plan

- Manual: Run `virsh net-list --all` to verify network exists
- Manual: Run `virsh net-dumpxml kvm-nat-br0` to verify configuration
- Validate: Test DHCP with a temporary VM or network namespace

## Observability

- Enable libvirt network logging
- Monitor DHCP lease assignments

## Compliance

- Follow AGENTS.md IP/port rules - all network values must be variables
- Document IP allocation scheme for future reference

## Risks & Mitigations

- Risk: NAT bridge may conflict with existing host networking — Mitigation: Use non-overlapping subnet
- Risk: DHCP may conflict with other services — Mitigation: Use dedicated subnet for VMs

## Dependencies

- Story 01-002 (hypervisor installation) must be complete

## Notes

- NAT bridge provides outbound connectivity via host NAT
- This network is for VM-to-VM communication and outbound access
- Subnet should be documented in network topology diagram

## Network Topology Documentation

### NAT Bridge Network (kvm-nat-br0)
- **Purpose**: Internal VM network with outbound NAT access
- **Subnet**: 192.168.100.0/24
- **Gateway**: 192.168.100.1
- **DHCP Range**: 192.168.100.128 - 192.168.100.254 (126 addresses)
- **Bridge Name**: kvm-nat-br0
- **Mode**: NAT (Network Address Translation)
- **Features**: 
  - VM-to-VM communication within the subnet
  - Outbound internet access via host NAT
  - DHCP for automatic IP assignment
  - STP (Spanning Tree Protocol) enabled for loop prevention

### IP Allocation Scheme
- **192.168.100.1**: Gateway (bridge interface)
- **192.168.100.2-127**: Reserved for static assignments (future use)
- **192.168.100.128-254**: DHCP pool for dynamic VM assignments
- **192.168.100.255**: Network broadcast address

### Variable Configuration
All network parameters are configurable via Ansible variables:
- `common_kvm_nat_bridge_name`: Bridge name (default: kvm-nat-br0)
- `common_kvm_nat_bridge_subnet`: Network subnet (default: 192.168.100.0/24)
- `common_kvm_nat_bridge_gateway`: Gateway IP (default: 192.168.100.1)
- `common_kvm_nat_bridge_dhcp_start`: DHCP start (default: 192.168.100.128)
- `common_kvm_nat_bridge_dhcp_end`: DHCP end (default: 192.168.100.254)
