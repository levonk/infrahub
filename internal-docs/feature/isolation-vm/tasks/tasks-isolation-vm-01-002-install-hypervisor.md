---
story_id: "01-002"
story_title: "Install KVM/libvirt/QEMU Stack"
story_name: "install-hypervisor"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 1
parallel_id: 2
branch: "feature/current/isolation-vm/story-01-002-install-hypervisor"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["host-system"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "infrastructure"]
due: "2026-06-26"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Install and configure the KVM/libvirt/QEMU hypervisor stack on the OCI Cloud Server Host. This provides the foundation for creating and managing the Isolation VM.

## Sub-Tasks

- [x] Create Ansible role for KVM/libvirt/QEMU installation
- [x] Install required packages: qemu-kvm, libvirt-daemon-system, libvirt-clients, virtinst, bridge-utils
- [x] Enable and start libvirtd service
- [x] Add user to libvirt/kvm groups
- [x] Configure libvirt network and storage defaults
- [x] Test virsh connectivity and basic virsh commands
- [x] Create variables for hypervisor configuration (CPU mode, disk format, etc.)

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/` - New Ansible role
- `shared/active/02-config/ansible/roles/common-kvm/tasks/main.yml` - Installation tasks with Debian/RedHat support
- `shared/active/02-config/ansible/roles/common-kvm/defaults/main.yml` - Default variables including CPU mode configuration
- `shared/active/02-config/ansible/roles/common-kvm/handlers/main.yml` - Service restart handlers
- `shared/active/02-config/ansible/playbooks/test-kvm-installation.yml` - Test playbook for KVM installation
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Host-specific variables with QEMU CPU mode

## Acceptance Criteria

- [x] KVM/libvirt/QEMU packages are installed
- [x] libvirtd service is running and enabled
- [x] User can run virsh commands without sudo
- [x] virsh list returns empty list (no VMs yet)
- [x] All configuration is variable-driven per AGENTS.md requirements

## Test Plan

- Manual: SSH to host and run `virsh version`
- Manual: Run `virsh node-info` to verify host capabilities
- Validate: Check service status with `systemctl status libvirtd`

## Observability

- Enable libvirt logging for troubleshooting
- Monitor libvirtd service health

## Compliance

- Follow Ansible best practices from AGENTS.md
- Ensure no hardcoded IP addresses or ports
- Use variable-driven configuration

## Risks & Mitigations

- Risk: Package installation may conflict with existing services — Mitigation: Test on staging environment first
- Risk: Service startup may fail due to missing kernel modules — Mitigation: Story 01-001 validates kernel support first

## Dependencies

- Story 01-001 (nested virtualization test) should inform CPU mode configuration

## Notes

- This role should be reusable for other KVM setups
- Consider creating a common-kvm role in the levonk-ansible-galaxy repository
- Package versions should be pinned for reproducibility
