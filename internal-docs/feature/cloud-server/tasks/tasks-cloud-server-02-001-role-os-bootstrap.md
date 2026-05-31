---
story_id: "02-001"
story_title: "Role: host-os-bootstrap"
story_name: "role-os-bootstrap"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 1
branch: "feature/current/cloud-server/story-02-001-role-os-bootstrap"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "role", "os", "bootstrap"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `host-os-bootstrap` Ansible role in `shared/active/02-config/ansible/roles/` that handles fresh host provisioning: package refresh, OpenSSH setup, timezone enforcement, user creation, sudo configuration, and automatic security updates. Follows the Docker Service Standards naming and structure conventions.

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/host-os-bootstrap/`
- [ ] Create `defaults/main.yml` with neutral, overridable defaults (no localnet-specific paths)
- [ ] Create `tasks/main.yml` with tasks for:
  - Package index refresh (`apt update` or equivalent)
  - OpenSSH server installation and basic config
  - Timezone enforcement to UTC (`timedatectl set-timezone UTC`)
  - Non-root user creation (`cuser` with UID/GID 1000)
  - Passwordless sudo configuration for admin user
  - ed25519 SSH key auth for root and cuser
  - Automatic security updates (`unattended-upgrades` or equivalent)
- [ ] Create `handlers/main.yml` for SSH service restart
- [ ] Create `meta/main.yml` with role metadata and dependencies
- [ ] Create `README.md` documenting role variables and usage
- [ ] Create `tests/` directory with basic test playbook
- [ ] Verify `ansible-lint` passes on the role

## Relevant Files

- `shared/active/02-config/ansible/roles/host-os-bootstrap/` — role directory
- `shared/active/02-config/ansible/roles/host-os-bootstrap/defaults/main.yml` — role defaults
- `shared/active/02-config/ansible/roles/host-os-bootstrap/tasks/main.yml` — role tasks
- `shared/active/02-config/ansible/roles/host-os-bootstrap/handlers/main.yml` — role handlers
- `shared/active/02-config/ansible/roles/host-os-bootstrap/meta/main.yml` — role metadata
- `shared/active/02-config/ansible/roles/host-os-bootstrap/README.md` — role documentation
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — consumes group vars

## Acceptance Criteria

- [ ] Role executes without errors on target host
- [ ] `cuser` account exists with UID/GID 1000
- [ ] UTC timezone is set
- [ ] OpenSSH is installed and running
- [ ] Passwordless sudo works for admin user
- [ ] ed25519 key auth works for root and cuser
- [ ] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/host-os-bootstrap/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/host-os-bootstrap/tests/test.yml`
- Molecule (if configured): `devbox run molecule test -s default`

## Observability

- Add `ansible_facts` logging for OS version, kernel, and uptime
- Log package update status and any failures

## Compliance

- No hardcoded credentials or IPs
- Uses variables from group_vars exclusively
- Follows AGENTS.md naming conventions

## Risks & Mitigations

- Risk: SSH key auth fails on first run — Mitigation: Ensure password-based bootstrap is possible or use cloud-init
- Risk: Sudo configuration errors lock out admin — Mitigation: Validate sudo config before applying, use visudo equivalent

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-001 (bootstrap playbook)

## Definition of Done

- Role is complete, linted, and tested
- CI passes role checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add host-os-bootstrap role`
- `test(ansible): add host-os-bootstrap tests`

## Changelog

- 2026-05-29: initialized story file
