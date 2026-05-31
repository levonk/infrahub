---
story_id: "06-001"
story_title: "Validate host bootstrap (SSH, Nix, Docker)"
story_name: "validate-bootstrap"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 6
parallel_id: 1
branch: "feature/current/cloud-server/story-06-001-validate-bootstrap"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["05-001"]
parallel_safe: true
modules: ["test", "validation"]
priority: "MUST"
risk_level: "low"
tags: ["test", "validation", "bootstrap"]
due: "2026-07-10"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Validate that the bootstrap deployment succeeded by running a comprehensive health check playbook against the OCI host. This must be runnable via `devbox run ansible-playbook` and should report clear pass/fail status for each component.

## Sub-Tasks

- [ ] Create `shared/active/02-config/ansible/playbooks/validate-bootstrap.yml`
- [ ] Add tasks to verify:
  - SSH connectivity with ed25519 key for `cuser`
  - `nix --version` returns expected version
  - `docker ps` works without sudo for `cuser`
  - `zsh` is default shell (`echo $SHELL` returns `/run/current-system/sw/bin/zsh` or similar)
  - `neovim --version` works
  - `devbox --version` works
  - `timedatectl` shows UTC
  - `cuser` UID/GID is 1000
  - OpenSSH service is active
  - Unattended upgrades are configured
- [ ] Run validation playbook: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-bootstrap.yml`
- [ ] Document any failures and create follow-up tickets
- [ ] Update deployment runbook with validation steps

## Relevant Files

- `shared/active/02-config/ansible/playbooks/validate-bootstrap.yml` — validation playbook
- `levonk/active/02-config/ansible/inventories/oci.yml`

## Acceptance Criteria

- [ ] Validation playbook exists and runs without errors
- [ ] All bootstrap components report healthy
- [ ] Any failures are documented with root cause
- [ ] Validation can be re-run at any time

## Test Plan

- Run: `devbox run ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/validate-bootstrap.yml`
- Manual: Spot-check 3-4 components via SSH

## Observability

- Log validation results with timestamps
- Store results in a structured format (JSON or YAML) for tracking

## Compliance

- Validation must be objective and automated where possible
- No manual checks that can't be scripted

## Risks & Mitigations

- Risk: Validation playbook has false negatives — Mitigation: Cross-check with manual SSH verification
- Risk: Some checks require root — Mitigation: Use `become: true` with validation tasks

## Dependencies & Sequencing

- Depends on: 05-001 (bootstrap deployed)
- Unblocks: 06-005 (final audit)

## Definition of Done

- Bootstrap validation passes cleanly
- All components confirmed healthy
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add bootstrap validation playbook`
- `test(ansible): validate bootstrap deployment on OCI`

## Changelog

- 2026-05-29: initialized story file
