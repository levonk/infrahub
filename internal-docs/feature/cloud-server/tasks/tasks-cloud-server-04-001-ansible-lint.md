---
story_id: "04-001"
story_title: "ansible-lint configuration & role linting"
story_name: "ansible-lint"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 4
parallel_id: 1
branch: "feature/current/cloud-server/story-04-001-ansible-lint"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003", "02-004", "02-005", "02-006", "02-007", "02-008", "02-009", "02-010", "02-011", "02-012", "02-013", "02-014"]
parallel_safe: true
modules: ["ansible", "lint"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "lint", "ci"]
due: "2026-06-26"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Configure `ansible-lint` for the cloud server project and run it against all roles, playbooks, and variable files. Ensure all cloud server artifacts pass linting before deployment. This must be runnable via `devbox run ansible-lint`.

## Sub-Tasks

- [ ] Create or update `.ansible-lint.yml` in the project root
- [ ] Configure rules to match infrahub standards (no hardcoded IPs, proper naming, etc.)
- [ ] Add `ansible-lint` to devbox environment or ensure it's available
- [ ] Run lint against all cloud server roles:
  - `devbox run ansible-lint shared/active/02-config/ansible/roles/host-os-bootstrap/`
  - `devbox run ansible-lint shared/active/02-config/ansible/roles/nix-installation/`
  - ... (all 14 roles)
- [ ] Run lint against all playbooks:
  - `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-*.yml`
- [ ] Run lint against variable files:
  - `devbox run ansible-lint levonk/active/02-config/ansible/group_vars/`
  - `devbox run ansible-lint levonk/active/02-config/ansible/host_vars/`
- [ ] Fix any lint violations
- [ ] Add lint step to CI pipeline (GitHub Actions or equivalent)

## Relevant Files

- `.ansible-lint.yml` — lint configuration
- `devbox.json` — ensure ansible-lint is in packages
- All role directories under `shared/active/02-config/ansible/roles/`
- All playbooks under `shared/active/02-config/ansible/playbooks/`
- Variable files under `levonk/active/02-config/ansible/group_vars/` and `host_vars/`

## Acceptance Criteria

- [ ] `ansible-lint` configuration exists and is version controlled
- [ ] All 14 cloud server roles pass lint
- [ ] All playbooks pass lint
- [ ] All variable files pass lint
- [ ] CI pipeline includes ansible-lint step
- [ ] `devbox run ansible-lint` works without extra setup

## Test Plan

- Run: `devbox run ansible-lint shared/active/02-config/ansible/roles/*cloud*/`
- Run: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-*.yml`
- Run: `devbox run ansible-lint levonk/active/02-config/ansible/group_vars/`

## Observability

- Log lint results per role/playbook
- Track lint violation counts over time

## Compliance

- Enforce AGENTS.md IP/port variable rules via custom lint rules if needed
- No exceptions without documented justification

## Risks & Mitigations

- Risk: Lint violations in existing shared roles — Mitigation: Scope lint to cloud server roles only initially
- Risk: False positives from ansible-lint — Mitification: Configure skip_list for known acceptable patterns

## Dependencies & Sequencing

- Depends on: All Phase 02 roles
- Unblocks: 04-003 (syntax check), 05-001 (deploy bootstrap)

## Definition of Done

- All cloud server Ansible artifacts pass lint
- CI is configured to enforce linting
- Story file updated to `done`

## Commit Conventions

- `ci(ansible): add ansible-lint configuration for cloud server`
- `fix(ansible): resolve lint violations in cloud server roles`

## Changelog

- 2026-05-29: initialized story file
