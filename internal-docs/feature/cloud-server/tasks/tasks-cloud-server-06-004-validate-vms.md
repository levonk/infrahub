---
story_id: "06-004"
story_title: "Validate VM workloads & routing"
story_name: "validate-vms"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 6
parallel_id: 4
branch: "feature/current/cloud-server/story-06-004-validate-vms"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["05-004"]
parallel_safe: true
modules: ["test", "validation"]
priority: "COULD"
risk_level: "low"
tags: ["test", "validation", "vm"]
due: "2026-07-10"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Validate that the QEMU hypervisor and VM networking are operational on the OCI host. This is a foundational validation before creating actual workload VMs. Using QEMU software virtualization since ARM Neoverse-N1 CPU lacks KVM hardware extensions.

## Sub-Tasks

- [x] Create `shared/active/02-config/ansible/playbooks/validate-vms.yml`
- [x] Add tasks to verify:
  - QEMU is installed and functional (software virtualization mode)
  - `libvirtd` is active
  - NAT bridge network is active (`virsh net-info <nat-network>`)
  - Routed bridge network is active
  - Storage pool is active and has available space
  - `virt-install --print-xml` works (dry-run VM creation)
- [ ] Optionally create a test VM and verify it boots
- [x] Run validation playbook: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vms.yml`
- [x] Document any failures and create follow-up tickets

## Relevant Files

- `shared/active/02-config/ansible/playbooks/validate-vms.yml` — validation playbook
- `levonk/active/02-config/ansible/inventories/oci.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml`

## Acceptance Criteria

- [x] Validation playbook exists and runs without errors
- [x] QEMU is operational (software virtualization mode)
- [x] libvirtd is active
- [x] Both bridge networks are active
- [x] Storage pool has available space
- [x] VM creation tooling works

## Test Plan

- Run: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-vms.yml`
- Manual: Verify `virsh` commands from host

## Observability

- Log KVM capability and network status
- Capture storage pool usage

## Compliance

- Bridge names and subnets must be variables
- No hardcoded VM specs

## Risks & Mitigations

- Risk: Test VM creation consumes resources — Mitigation: Use minimal test VM; destroy after test
- Risk: Nested virtualization not supported — Mitigation: Check CPU flags first; abort gracefully

## Dependencies & Sequencing

- Depends on: 05-004 (VM layer deployed)
- Unblocks: 06-005 (final audit)

## Definition of Done

- VM layer validation passes cleanly
- Hypervisor confirmed operational
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add VM validation playbook`
- `test(ansible): validate VM layer on OCI`

## Changelog

- 2026-05-29: initialized story file
- 2026-06-07: Updated to use QEMU software virtualization (ARM compatible)
- 2026-06-07: Created validate-vms.yml playbook
- 2026-06-07: All validation checks passed - QEMU, libvirtd, networks, storage pool, virt-install all functional
