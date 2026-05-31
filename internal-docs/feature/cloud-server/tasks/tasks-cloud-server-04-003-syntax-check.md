---
story_id: "04-003"
story_title: "Playbook syntax check & dry-run"
story_name: "syntax-check"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 4
parallel_id: 3
branch: "feature/current/cloud-server/story-04-003-syntax-check"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-005"]
parallel_safe: true
modules: ["ansible", "test"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "test", "syntax"]
due: "2026-06-26"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Run `ansible-playbook --syntax-check` and `--check --diff` (dry-run) against all cloud server playbooks to catch errors before deployment. This is the final validation gate before any code touches the OCI host.

## Sub-Tasks

- [ ] Run syntax check on all playbooks:
  - `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
  - `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml`
  - `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
  - `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-vms.yml`
  - `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml`
- [ ] Run dry-run on each playbook:
  - `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml <playbook>`
- [ ] Document any `--check` limitations (e.g., tasks that always report changed)
- [ ] Fix any syntax or dry-run errors
- [ ] Add syntax check to CI pipeline

## Relevant Files

- All playbooks under `shared/active/02-config/ansible/playbooks/cloud-server-*.yml`
- `levonk/active/02-config/ansible/inventories/oci.yml`

## Acceptance Criteria

- [ ] All five playbooks pass `--syntax-check`
- [ ] All playbooks complete `--check --diff` without fatal errors
- [ ] CI pipeline includes syntax check step
- [ ] `devbox run ansible-playbook --syntax-check` works for all playbooks

## Test Plan

- Run: `devbox run ansible-playbook --syntax-check ...` for each playbook
- Run: `devbox run ansible-playbook --check --diff ...` for each playbook
- Verify: No syntax errors, no undefined variable errors in dry-run

## Observability

- Log syntax check results per playbook
- Track dry-run warnings and skipped tasks

## Compliance

- Syntax check must pass before any deploy story can proceed
- Document any expected dry-run warnings

## Risks & Mitigations

- Risk: Dry-run fails on tasks that require runtime state — Mitigation: Document expected behavior; use `check_mode: no` where appropriate
- Risk: Inventory variables not resolved in syntax check — Mitigation: Ensure inventory is complete and valid

## Dependencies & Sequencing

- Depends on: 03-005 (site playbook), 04-001 (lint)
- Unblocks: 05-001..05-004 (all deploy stories)

## Definition of Done

- All playbooks pass syntax check and dry-run
- CI enforces syntax validation
- Story file updated to `done`

## Commit Conventions

- `ci(ansible): add playbook syntax checks to CI`
- `fix(ansible): resolve syntax and dry-run errors`

## Changelog

- 2026-05-29: initialized story file
