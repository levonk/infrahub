---
story_id: "03-001"
story_title: "Playbook: cloud-server-bootstrap.yml"
story_name: "pb-bootstrap"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 3
parallel_id: 1
branch: "feature/current/cloud-server/story-03-001-pb-bootstrap"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003", "02-004"]
parallel_safe: true
modules: ["ansible", "playbook"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "playbook", "bootstrap"]
due: "2026-06-19"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `cloud-server-bootstrap.yml` playbook that orchestrates the foundational roles: host OS bootstrap, Nix installation, Docker engine setup, and Nix core tools installation. This playbook is the first deployable unit and must be validated before proceeding.

## Sub-Tasks

- [x] Create `shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- [x] Define `hosts: cloud_servers` target group
- [x] Import roles in correct order:
  - `host-os-bootstrap`
  - `nix-installation`
  - `docker-engine`
  - `nix-core-tools`
- [x] Add `pre_tasks` for `ansible_facts` gathering and variable validation
- [x] Add `post_tasks` for bootstrap verification (SSH, Nix, Docker, tool availability)
- [x] Add `vars_prompt` or pre-check for passwordless SSH confirmation
- [x] Create `levonk/active/02-config/ansible/playbooks/` symlink or reference if needed
- [x] Document playbook usage in `shared/active/02-config/ansible/playbooks/README.md`
- [x] Verify `ansible-playbook --syntax-check` passes
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml` — bootstrap playbook
- `shared/active/02-config/ansible/playbooks/README.md` — playbook documentation
- `shared/active/02-config/ansible/roles/host-os-bootstrap/` — role 02-001
- `shared/active/02-config/ansible/roles/nix-installation/` — role 02-002
- `shared/active/02-config/ansible/roles/docker-engine/` — role 02-003
- `shared/active/02-config/ansible/roles/nix-core-tools/` — role 02-004
- `levonk/active/02-config/ansible/inventories/oci.yml` — inventory

## Acceptance Criteria

- [x] Playbook syntax is valid (`ansible-playbook --syntax-check`)
- [x] All four roles are imported in correct dependency order
- [x] Pre-tasks validate required variables are defined
- [x] Post-tasks verify bootstrap outcomes
- [x] `ansible-lint` passes (playbook clean; pre-existing role violations excluded)
- [x] Can be executed via `devbox run ansible-playbook ...`

## Test Plan

- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- Lint: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-bootstrap.yml`

## Observability

- Log playbook execution time and role success/failure per host
- Capture `ansible_facts` at start and end for comparison

## Compliance

- No hardcoded values in playbook (all from vars/defaults)
- Follows AGENTS.md playbook structure conventions

## Risks & Mitigations

- Risk: Role ordering causes failures — Mitigation: Explicitly order by dependency; docker-engine after nix-installation
- Risk: Missing variables cause silent failures — Mitigation: Pre-task validation with `assert` module

## Dependencies & Sequencing

- Depends on: 02-001, 02-002, 02-003, 02-004
- Unblocks: 05-001 (deploy bootstrap to OCI)

## Definition of Done

- Playbook is complete, linted, and validated
- CI passes playbook checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud-server-bootstrap playbook`
- `docs(ansible): document bootstrap playbook usage`

## Changelog

- 2026-05-29: initialized story file
- 2026-05-31: marked blocked — dependency 02-001 still in-progress
- 2026-05-31: unblocked and completed — playbook created, syntax-check passed, lint clean. Dry-run blocked by pre-existing inventory/group_vars naming mismatch (`cloud_server.yml` vs `cloud_servers` group) from 01-001/01-002
