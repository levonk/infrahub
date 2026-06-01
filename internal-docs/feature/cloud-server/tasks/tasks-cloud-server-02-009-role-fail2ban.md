---
story_id: "02-009"
story_title: "Role: fail2ban"
story_name: "role-fail2ban"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 9
branch: "feature/current/cloud-server/story-02-009-role-fail2ban"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "security"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "role", "security", "fail2ban"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `fail2ban` Ansible role that installs and configures fail2ban for SSH brute-force protection. Ban time and retry limits must be variable-driven per the PRD requirements.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/common-fail2ban/`
- [x] Create `defaults/main.yml` with ban time, retry limits, and ignore IP variables
- [x] Create `tasks/main.yml` with tasks for:
  - Install fail2ban (via OS package manager)
  - Configure `jail.local` with SSH jail settings
  - Set `bantime` from `cloud_server_fail2ban_bantime` variable
  - Set `maxretry` from variable
  - Set `findtime` from variable
  - Configure `ignoreip` for management/VPN networks
  - Start and enable fail2ban service
  - Verify fail2ban status and active jails
- [x] Create `handlers/main.yml` for fail2ban restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [~] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/common-fail2ban/` — role directory
- `shared/active/02-config/ansible/roles/common-fail2ban/defaults/main.yml`
- `shared/active/02-config/ansible/roles/common-fail2ban/tasks/main.yml`
- `shared/active/02-config/ansible/roles/common-fail2ban/templates/jail.local.j2`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — fail2ban variables

## Acceptance Criteria

- [x] fail2ban is installed and running
- [x] SSH jail is active and configured
- [x] Ban time matches `cloud_server_fail2ban_bantime`
- [x] Max retry and findtime are variable-driven
- [x] `ansible-lint` passes (YAML validated)

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/common-fail2ban/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/common-fail2ban/tests/test.yml`

## Observability

- Log active jails and banned IPs after deployment
- Monitor fail2ban log for banned hosts

## Compliance

- No hardcoded ban times or retry limits
- Ignore IPs should include VPN/management ranges from variables

## Risks & Mitigations

- Risk: fail2ban bans legitimate VPN IPs — Mitigation: Add VPN CIDRs to ignoreip via variables
- Risk: Service conflicts with existing log monitoring — Mitigation: Configure log backend (systemd-journal or file)

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-002 (VPN playbook), 05-002 (deploy VPN layer)

## Definition of Done

- Role installs and configures fail2ban correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add common-fail2ban role`
- `test(ansible): add common-fail2ban role tests`

## Changelog

- 2026-05-29: initialized story file
