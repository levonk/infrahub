---
story_id: "02-014"
story_title: "Role: kvm-hypervisor"
story_name: "role-kvm"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 14
branch: "feature/current/cloud-server/story-02-014-role-kvm"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "vm"]
priority: "COULD"
risk_level: "medium"
tags: ["ansible", "role", "vm", "kvm"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `kvm-hypervisor` Ansible role that installs and configures the KVM/libvirt/QEMU stack on the cloud server. This role enables virtualization for compartmentalized workloads (Netbird gateway VM, Hermes/Paperclip workload VMs, Kali security VM).

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/common-kvm/`
- [x] Create `defaults/main.yml` with KVM bridge subnet, VM storage path, and network variables
- [x] Create `tasks/main.yml` with tasks for:
  - Check CPU virtualization support (Intel VT-x / AMD-V)
  - Install `qemu-kvm`, `libvirt-daemon-system`, `virt-manager` (or `virt-install`/`virsh`)
  - Start and enable libvirtd service
  - Create NAT bridge network for isolated guests
  - Create routed bridge network for VM-to-outside routing
  - Configure VM storage pool (directory or LVM-thin)
  - Verify `virsh` CLI works
- [x] Create `handlers/main.yml` for libvirtd restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/common-kvm/` — role directory
- `shared/active/02-config/ansible/roles/common-kvm/defaults/main.yml`
- `shared/active/02-config/ansible/roles/common-kvm/tasks/main.yml`
- `shared/active/02-config/ansible/roles/common-kvm/templates/network-nat.xml.j2`
- `shared/active/02-config/ansible/roles/common-kvm/templates/network-routed.xml.j2`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — KVM bridge and VM variables

## Acceptance Criteria

- [x] KVM kernel modules are loaded (`kvm`, `kvm_intel` or `kvm_amd`)
- [x] libvirtd is running and enabled
- [x] NAT bridge network is defined and active
- [x] Routed bridge network is defined and active
- [x] Storage pool is created and active
- [x] `virsh list --all` works without errors
- [x] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/common-kvm/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/common-kvm/tests/test.yml`
- Functional: `virsh capabilities | grep kvm` on target host

## Observability

- Log KVM capability detection and bridge network status
- Monitor libvirtd service health

## Compliance

- Bridge subnets must be variables
- No hardcoded storage paths

## Risks & Mitigations

- Risk: Cloud provider doesn't support nested virtualization — Mitigation: Check CPU flags before install; document alternative (containers only)
- Risk: Network bridge conflicts with existing interfaces — Mitigation: Use variable-driven bridge names and subnets

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-004 (VM playbook), 09-001..09-004 (VM workload stories)

## Definition of Done

- Role installs and configures KVM stack correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add common-kvm role`
- `test(ansible): add common-kvm role tests`

## Changelog

- 2026-05-29: initialized story file
