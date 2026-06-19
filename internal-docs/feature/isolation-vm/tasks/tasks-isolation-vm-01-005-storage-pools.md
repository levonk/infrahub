---
story_id: "01-005"
story_title: "Configure Storage Pools"
story_name: "storage-pools"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 1
parallel_id: 5
branch: "feature/current/isolation-vm/story-01-005-storage-pools"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["storage"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "storage"]
due: "2026-06-26"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Configure libvirt storage pools for VM disk images. This provides the storage backend for the Isolation VM and future VMs.

## Sub-Tasks

- [ ] Create default libvirt storage pool directory
- [ ] Define storage pool path using variable (default: /var/lib/libvirt/images)
- [ ] Create libvirt storage pool definition
- [ ] Configure storage pool for auto-start
- [ ] Set appropriate permissions on storage directory
- [ ] Create Ansible task to deploy storage pool configuration
- [ ] Test storage pool creation and basic operations
- [ ] Document storage backend choice (qcow2 vs LVM-thin)

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/tasks/storage.yml` - Storage configuration tasks
- `shared/active/02-config/ansible/roles/common-kvm/defaults/main.yml` - Storage path variables
- `shared/active/02-config/ansible/inventory/group_vars/oci_cloud_server_host.yml` - Host-specific storage variables

## Acceptance Criteria

- [ ] Storage pool directory exists with correct permissions
- [ ] Storage pool is defined in libvirt
- [ ] Storage pool is active and persistent
- [ ] Storage path is configurable via variable
- [ ] virsh pool-list shows the storage pool as active
- [ ] Storage backend choice is documented

## Test Plan

- Manual: Run `virsh pool-list --all` to verify storage pool exists
- Manual: Run `virsh pool-info` to verify pool status
- Validate: Test creating a test volume in the pool

## Observability

- Monitor storage pool usage
- Log storage pool operations

## Compliance

- Follow AGENTS.md rules - all paths must be variables
- Document storage backend decision for future reference

## Risks & Mitigations

- Risk: Storage directory may have insufficient space — Mitigation: Monitor disk usage during deployment
- Risk: Permissions may prevent libvirt from accessing storage — Mitigation: Test with test volume creation

## Dependencies

- Story 01-002 (hypervisor installation) must be complete

## Notes

- Default to qcow2 format for simplicity and compatibility
- LVM-thin can be considered later if performance is inadequate
- Storage path should be on a disk with sufficient capacity
- Document the decision in PRD Open Questions section
