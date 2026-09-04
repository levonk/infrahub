---
story_id: "01-004"
story_title: "Configure Routed Bridge Network"
story_name: "routed-bridge-network"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 1
parallel_id: 4
branch: "feature/current/isolation-vm/story-01-004-routed-bridge-network"
status: "todo"
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

Configure a routed bridge network for VM-to-outside communication. This enables VMs to communicate with external networks through the host, including VPN services.

## Sub-Tasks

- [x] Create libvirt network definition for routed bridge (kvm-route-br0)
- [x] Define network subnet using variable `isolation_vm_routed_bridge_subnet` (default: 192.168.101.0/24)
- [x] Configure routing rules for VM external access
- [x] Create Ansible task to deploy network definition
- [x] Activate the routed bridge network
- [x] Configure host firewall rules to allow VM traffic
- [x] Test routing from VM subnet to external networks

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/templates/network-routed.xml.j2` - Libvirt routed network template
- `shared/active/02-config/ansible/roles/common-kvm/tasks/main.yml` - Network deployment and firewall tasks
- `shared/active/02-config/ansible/roles/common-kvm/defaults/main.yml` - Network configuration variables
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Host-specific network configuration

## Acceptance Criteria

- [x] Routed bridge network is defined in libvirt
- [x] Network is active and persistent
- [x] Host routing rules allow VM external access
- [x] Firewall rules permit VM traffic
- [x] Network subnet is configurable via variable
- [x] virsh net-list shows the routed bridge as active

## Test Plan

- Manual: Run `virsh net-list --all` to verify network exists
- Manual: Run `ip route` to verify routing table
- Validate: Test connectivity from a test VM to external networks

## Observability

- Enable libvirt network logging
- Monitor routing table changes
- Log firewall rule activations

## Compliance

- Follow AGENTS.md IP/port rules - all network values must be variables
- Document routing topology for security audits

## Risks & Mitigations

- Risk: Routed bridge may bypass VPN filtering — Mitigation: Configure strict firewall rules
- Risk: Routing may conflict with existing host routes — Mitigation: Use dedicated subnet

## Dependencies

- Story 01-002 (hypervisor installation) must be complete
- Story 01-003 (NAT bridge) should be complete to avoid conflicts

## Notes

- Routed bridge enables VMs to reach VPN services on host
- This is critical for agent container egress through VPN
- Firewall rules must enforce VPN/proxy routing for VM traffic
