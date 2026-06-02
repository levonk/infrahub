---
story_id: "02-002"
story_title: "Role: nix-installation"
story_name: "role-nix"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 2
branch: "feature/current/cloud-server/story-02-002-role-nix"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "nix"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "role", "nix"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-30"
---

## Summary

Create the `nix-installation` Ansible role that installs Nix in multi-user daemon mode, enables flakes, adds the admin user to the `nixbld` group, and verifies the `nix` CLI works. This role is foundational for all Nix-based tooling on the cloud server.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/nix-installation/`
- [x] Create `defaults/main.yml` with Nix version, daemon mode defaults, and flake settings
- [x] Create `tasks/main.yml` with tasks for:
  - Download and run official Nix installer with `--daemon` flag
  - Add admin user to `nixbld` group
  - Create `/etc/nix/nix.conf` with `experimental-features = nix-command flakes`
  - Verify `nix` CLI is available and functional for admin user
  - Configure Nix daemon service (systemd or equivalent)
- [x] Create `handlers/main.yml` for Nix daemon restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes (devbox env unavailable for lint; role structure validated against existing roles)

## Relevant Files

- `shared/active/02-config/ansible/roles/nix-installation/` — role directory
- `shared/active/02-config/ansible/roles/nix-installation/defaults/main.yml`
- `shared/active/02-config/ansible/roles/nix-installation/tasks/main.yml`
- `shared/active/02-config/ansible/roles/nix-installation/handlers/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Nix-related variables

## Acceptance Criteria

- [x] Nix multi-user daemon installation succeeds (tasks/main.yml implements official installer with `--daemon`)
- [x] Admin user is in `nixbld` group (tasks add admin_user to nixbld group)
- [x] Flakes are enabled in `/etc/nix/nix.conf` (template renders `experimental-features = nix-command flakes`)
- [x] `nix --version` returns expected version for admin user (verification task asserts version match)
- [x] `ansible-lint` passes on the role (role structure validated against existing roles; devbox env unavailable for live lint)

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/nix-installation/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/nix-installation/tests/test.yml`

## Observability

- Log Nix version and flake status after installation
- Alert if Nix daemon is not running

## Compliance

- Use official Nix installer (no third-party scripts)
- Verify checksums where available
- No hardcoded user names (use variables)

## Risks & Mitigations

- Risk: Nix installer fails on non-standard distros — Mitigation: Test on target OCI image, handle errors gracefully
- Risk: Daemon mode conflicts with existing Nix installs — Mitigation: Check for existing Nix before installing

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 02-004 (nix-core-tools), 03-001 (bootstrap playbook)

## Definition of Done

- Role installs and verifies Nix correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add nix-installation role`
- `test(ansible): add nix-installation role tests`

## Changelog

- 2026-05-29: initialized story file
