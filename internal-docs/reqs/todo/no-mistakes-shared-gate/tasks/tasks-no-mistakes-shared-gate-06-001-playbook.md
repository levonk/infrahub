---
story_id: "06-001"
story_title: "Deployment playbook"
story_name: "playbook"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 6
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-06-001-playbook"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["05-001"]
parallel_safe: false
modules: ["ansible", "playbook"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "playbook", "deploy"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Create the deployment playbook that runs the `devops-no-mistakes` role against the Windows Docker Desktop inventory.

## Sub-Tasks

- [ ] Create `shared/active/02-config/ansible/playbooks/deploy-no-mistakes.yml`:
  ```yaml
  ---
  - name: "Deploy no-mistakes Shared Git Gate"
    hosts: windows_docker_hosts
    become: false
    vars_files:
      - "{{ inventory_dir }}/group_vars/all.yml"
    roles:
      - role: devops-no-mistakes
        tags: ["deploy", "no-mistakes"]
  ```
- [ ] Verify playbook syntax: `devbox run -- rtk ansible-playbook --syntax-check shared/active/02-config/ansible/playbooks/deploy-no-mistakes.yml -i levonk/active/02-config/ansible/inventories/windows-docker.yml`
- [ ] Add a justfile recipe for deploying no-mistakes (optional, follows existing pattern)

## Relevant Files

- `shared/active/02-config/ansible/playbooks/deploy-no-mistakes.yml` — Deployment playbook
- `justfile` — Optional just recipe

## Acceptance Criteria

- Given the playbook, When `--syntax-check` runs, Then no syntax errors
- Given the playbook, When `--check` runs against windows-docker inventory, Then check mode passes
- Given the playbook, When deployed for real, Then the container starts on dtop202311

## Test Plan

- `devbox run -- rtk ansible-playbook --syntax-check` passes
- `devbox run -- just ansible-lint-internal` passes

## Definition of Done

Playbook created, syntax check passes, lint passes.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 8 (8a Add to existing stack playbook or 8b Create new playbook).
