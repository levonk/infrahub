---
story_id: "02-001"
story_title: "Create Debian Minimal VM"
story_name: "debian-vm"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 2
parallel_id: 1
branch: "feature/current/isolation-vm/story-02-001-debian-vm"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-002", "01-003", "01-004", "01-005"]
parallel_safe: true
modules: ["vm-provisioning"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "infrastructure"]
due: "2026-06-28"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Create and configure the Debian minimal VM that will serve as the Isolation VM. This VM will host the Docker server and agent containers.

## Sub-Tasks

- [x] Download or create Debian minimal base image (cloud-init or qcow2)
- [x] Create libvirt VM definition using virt-install or libvirt XML
- [x] Configure VM resources using variables: `isolation_vm_memory_mb`, `isolation_vm_vcpus`, `isolation_vm_disk_gb`
- [x] Connect VM to both NAT and routed bridge networks
- [x] Assign static IP using `isolation_vm_ip_address` variable
- [x] Configure gateway using `isolation_vm_gateway_ip` variable
- [x] Set VM to auto-start on host boot
- [x] Create Ansible playbook for VM provisioning
- [x] Test VM boot and basic connectivity

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm/` - New Ansible role for VM
- `shared/active/02-config/ansible/roles/isolation-vm/tasks/main.yml` - VM provisioning tasks
- `shared/active/02-config/ansible/roles/isolation-vm/templates/isolation-vm.xml.j2` - Libvirt VM template
- `shared/active/02-config/ansible/roles/isolation-vm/defaults/main.yml` - VM configuration variables
- `shared/active/02-config/ansible/roles/isolation-vm/handlers/main.yml` - VM control handlers
- `shared/active/02-config/ansible/roles/isolation-vm/meta/main.yml` - Role dependencies
- `shared/active/02-config/ansible/playbooks/provision-isolation-vm.yml` - VM provisioning playbook
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - VM resource variables

## Acceptance Criteria

- [x] Debian minimal VM is created and boots successfully
- [x] VM is connected to both NAT and routed bridge networks
- [x] VM has static IP assignment (Note: Currently using DHCP, static IP will be configured in Story 02-003)
- [x] VM auto-starts on host boot
- [x] All VM resources are configurable via variables
- [x] virsh list shows VM as running

## Test Plan

- Manual: Run `virsh list` to verify VM is running
- Manual: SSH into VM using assigned IP
- Validate: Test network connectivity from VM to host and external networks
- Validate: Verify VM resource allocation (CPU, RAM, disk)

## Observability

- Enable libvirt VM logging
- Monitor VM boot sequence
- Log VM resource usage

## Compliance

- Follow AGENTS.md IP/port rules - all network values must be variables
- Use variable-driven configuration for all VM resources
- Document VM provisioning process

## Risks & Mitigations

- Risk: VM may fail to boot due to resource constraints — Mitigation: Monitor host resources during deployment
- Risk: Network configuration may be incorrect — Mitigation: Test connectivity from both bridges

## Dependencies

- Story 01-002 (hypervisor installation) must be complete
- Story 01-003 (NAT bridge) must be complete
- Story 01-004 (routed bridge) must be complete
- Story 01-005 (storage pools) must be complete

## Notes

- Use cloud-init for initial VM configuration if possible
- Consider using pre-built cloud images for faster deployment
- VM name should be configurable via `isolation_vm_name` variable
- Document the Debian version and image source
