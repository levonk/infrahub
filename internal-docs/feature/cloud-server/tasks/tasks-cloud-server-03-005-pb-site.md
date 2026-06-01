---
story_id: "03-005"
story_title: "Site Playbook: cloud-server-site.yml"
story_name: "pb-site"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 3
parallel_id: 5
branch: "feature/current/cloud-server/story-03-005-pb-site"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["03-001", "03-002", "03-003", "03-004"]
parallel_safe: true
modules: ["ansible", "playbook"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "playbook", "site"]
due: "2026-06-19"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `cloud-server-site.yml` site playbook that imports all phase-specific playbooks (bootstrap, VPN, infrastructure, VMs) in the correct deployment order. This is the top-level entry point for deploying the entire cloud server stack.

## Sub-Tasks

- [x] Create `shared/active/02-config/ansible/playbooks/cloud-server-site.yml`
- [x] Add `import_playbook` directives in order:
  - `cloud-server-bootstrap.yml`
  - `cloud-server-vpn.yml`
  - `cloud-server-infra.yml`
  - `cloud-server-vms.yml`
- [x] Add top-level `pre_tasks` for global variable validation
- [x] Add top-level `post_tasks` for final system health check
- [x] Document deployment order and rollback strategy in README
- [x] Verify `ansible-playbook --syntax-check` passes
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-site.yml` — site playbook
- `shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml` — 03-001
- `shared/active/02-config/ansible/playbooks/cloud-server-vpn.yml` — 03-002
- `shared/active/02-config/ansible/playbooks/cloud-server-infra.yml` — 03-003
- `shared/active/02-config/ansible/playbooks/cloud-server-vms.yml` — 03-004
- `shared/active/02-config/ansible/playbooks/README.md` — documentation
- `levonk/active/02-config/ansible/inventories/oci.yml` — inventory

## Acceptance Criteria

- [x] Playbook syntax is valid
- [x] All four phase playbooks are imported in correct order
- [x] Global variable validation pre-tasks are present
- [x] Final health check post-tasks are present
- [x] `ansible-lint` passes
- [x] Can be executed via `devbox run ansible-playbook ...`

## Test Plan

- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-site.yml`
- Lint: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-site.yml`

## Observability

- Log overall playbook execution flow
- Capture final system health summary

## Compliance

- No hardcoded values in site playbook
- Follows AGENTS.md playbook conventions

## Risks & Mitigations

- Risk: Phase ordering incorrect — Mitigation: Document clear phase dependencies; validate with dry-run
- Risk: One phase failure blocks entire site deploy — Mitigation: Support `--start-at-task` for recovery

## Dependencies & Sequencing

- Depends on: 03-001, 03-002, 03-003, 03-004
- Unblocks: 04-003 (syntax check), 05-001..05-004 (deploy phases)

## Definition of Done

- Site playbook is complete, linted, and validated
- CI passes playbook checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud-server-site playbook`
- `docs(ansible): document site playbook deployment order`

## Changelog

- 2026-05-29: initialized story file
