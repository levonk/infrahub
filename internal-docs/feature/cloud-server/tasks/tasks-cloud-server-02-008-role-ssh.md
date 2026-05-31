---
story_id: "02-008"
story_title: "Role: ssh-hardening"
story_name: "role-ssh"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 8
branch: "feature/current/cloud-server/story-02-008-role-ssh"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "security"]
priority: "MUST"
risk_level: "high"
tags: ["ansible", "role", "security", "ssh"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `ssh-hardening` Ansible role that hardens SSH configuration on the cloud server. This role must be applied ONLY after confirming passwordless login works, per the PRD Step 2.5 requirements.

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/common-ssh-hardening/`
- [ ] Create `defaults/main.yml` with SSH config variables (port, algorithms, timeouts, etc.)
- [ ] Create `tasks/main.yml` with tasks for:
  - Verify passwordless SSH login works (pre-condition check)
  - Set `PermitRootLogin no`
  - Set `PasswordAuthentication no`
  - Set `AuthenticationMethods publickey`
  - Restrict to ed25519 keys (`PubkeyAcceptedAlgorithms`, `HostKeyAlgorithms`)
  - Set `MaxAuthTries 3`
  - Set `ClientAliveInterval 300`
  - Set `ClientAliveCountMax 2`
  - Optionally set non-standard port (variable-driven)
  - Validate SSH config before applying (`sshd -t`)
  - Restart SSH service only if config is valid
- [ ] Create `handlers/main.yml` for SSH service restart
- [ ] Create `meta/main.yml` with role metadata
- [ ] Create `README.md` documenting role variables and the WARNING about lockout
- [ ] Add `tests/` with test playbook
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/common-ssh-hardening/` — role directory
- `shared/active/02-config/ansible/roles/common-ssh-hardening/defaults/main.yml`
- `shared/active/02-config/ansible/roles/common-ssh-hardening/tasks/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — SSH port and algorithm variables

## Acceptance Criteria

- [ ] Passwordless SSH login is verified before hardening
- [ ] `PermitRootLogin` is set to `no`
- [ ] `PasswordAuthentication` is set to `no`
- [ ] Only ed25519 keys are accepted
- [ ] `MaxAuthTries`, `ClientAliveInterval`, `ClientAliveCountMax` are set correctly
- [ ] SSH config validates with `sshd -t` before restart
- [ ] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/common-ssh-hardening/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/common-ssh-hardening/tests/test.yml`
- Manual: Verify SSH connectivity after hardening; have console fallback

## Observability

- Log SSH hardening status and any connection warnings
- Monitor SSH login attempts (pre-fail2ban)

## Compliance

- Pre-condition check before applying hardening
- Config validation before service restart
- No hardcoded ports or algorithms

## Risks & Mitigations

- Risk: Lockout if passwordless auth not configured — Mitigation: Explicit pre-condition check with `fail` module
- Risk: Invalid SSH config breaks access — Mitigation: Run `sshd -t` before applying; keep a backup config

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-002 (VPN playbook), 05-002 (deploy VPN layer)

## Definition of Done

- Role hardens SSH without causing lockout
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add common-ssh-hardening role`
- `test(ansible): add common-ssh-hardening role tests`

## Changelog

- 2026-05-29: initialized story file
