---
story_id: "03-004"
story_title: "Playbook: cloud-server-vms.yml"
story_name: "pb-vms"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 3
parallel_id: 4
branch: "feature/current/cloud-server/story-03-004-pb-vms"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["02-014"]
parallel_safe: true
modules: ["ansible", "playbook"]
priority: "COULD"
risk_level: "medium"
tags: ["ansible", "playbook", "vm"]
due: "2026-06-19"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `cloud-server-vms.yml` playbook that orchestrates the KVM hypervisor setup. This playbook imports the `common-kvm` role and provides a foundation for creating individual VM workloads in later phases.

## Sub-Tasks

- [x] Create `shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- [x] Define `hosts: cloud_servers` target group
- [x] Import `common-kvm` role
- [x] Add `pre_tasks` to verify host has virtualization support
- [x] Add `post_tasks` to verify libvirtd, bridge networks, and storage pool are active
- [x] Document playbook usage in README
- [ ] Verify `ansible-playbook --syntax-check` passes
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-vms.yml` — VM playbook
- `shared/active/02-config/ansible/roles/common-kvm/` — role 02-014
- `levonk/active/02-config/ansible/inventories/oci.yml` — inventory
- `shared/active/02-config/ansible/playbooks/README.md` — playbook documentation

## Acceptance Criteria

- [ ] Playbook syntax is valid
- [ ] `common-kvm` role is imported
- [ ] Pre-tasks check CPU virtualization support
- [ ] Post-tasks verify libvirt stack is operational
- [ ] `ansible-lint` passes
- [ ] Can be executed via `devbox run ansible-playbook ...`

## Test Plan

- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- Lint: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`

## Observability

- Log virtualization capability detection
- Capture libvirt network and pool status

## Compliance

- Bridge subnets must be variables
- No hardcoded storage paths

## Risks & Mitigations

- Risk: Host lacks virtualization support — Mitigation: Pre-task check with clear failure message
- Risk: Bridge network conflicts — Mitigation: Variable-driven names and subnets

## Dependencies & Sequencing

- Depends on: 02-014
- Unblocks: 05-004 (deploy VM layer to OCI)

## Definition of Done

- Playbook is complete, linted, and validated
- CI passes playbook checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud-server-vms playbook`
- `docs(ansible): document vm playbook usage`

## Changelog

- 2026-05-29: initialized story file
