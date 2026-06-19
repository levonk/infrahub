---
story_id: "01-003"
story_title: "Configure NAT Bridge Network"
story_name: "nat-bridge-network"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 1
parallel_id: 3
branch: "feature/current/isolation-vm/story-01-003-nat-bridge-network"
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

Configure a NAT bridge network for VM isolation. This provides internal network connectivity for VMs while isolating them from the host network.

## Sub-Tasks

- [ ] Create libvirt network definition for NAT bridge (kvm-nat-br0)
- [ ] Define network subnet using variable `isolation_vm_nat_bridge_subnet` (default: 192.168.100.0/24)
- [ ] Configure DHCP settings for the NAT network
- [ ] Create Ansible task to deploy network definition
- [ ] Activate the NAT bridge network
- [ ] Test network connectivity from host to bridge
- [ ] Document network topology and IP allocation scheme

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/templates/kvm-nat-br0.xml` - Libvirt network template
- `shared/active/02-config/ansible/roles/common-kvm/tasks/network.yml` - Network configuration tasks
- `shared/active/02-config/ansible/inventory/group_vars/oci_cloud_server_host.yml` - Network variables

## Acceptance Criteria

- [ ] NAT bridge network is defined in libvirt
- [ ] Network is active and persistent
- [ ] DHCP is functional on the bridge
- [ ] Network subnet is configurable via variable
- [ ] virsh net-list shows the NAT bridge as active

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
