---
story_id: "03-001"
story_title: "Create deploy/validate playbooks, just recipes, service catalog"
story_name: "playbooks-catalog"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 3
parallel_id: 1
branch: "feature/current/add-control-center-dashboard/story-03-001-playbooks-catalog"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002", "02-001", "02-002", "02-003"]
parallel_safe: false
modules: ["shared/playbooks", "justfile", "services.yml"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "playbook", "justfile", "catalog", "deploy"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Create deploy-control-center.yml and validate-control-center.yml playbooks, add just recipes, add service catalog entry, regenerate SERVICES.md.

## Current State

- `shared/active/02-config/ansible/playbooks/deploy-directory-empire.yml` — reference deploy playbook pattern
- `shared/active/02-config/ansible/infrastructure/services.yml` — service catalog
- `shared/active/02-config/ansible/scripts/generate_service_catalog.py` — catalog generator
- `justfile` — contains directory-empire deploy/validate recipes as reference
- Windows Docker host playbook (harden-windows-host.yml or equivalent) — where the role needs to be included
- All prerequisite stories (01-001, 01-002, 02-001, 02-002, 02-003) must be complete

## Scope

- Create deploy-control-center.yml playbook (includes dashboard-control-center role, targets windows_docker_hosts)
- Create validate-control-center.yml playbook (health checks, domain checks, container status)
- Add just recipes: ansible-deploy-control-center, ansible-validate-control-center
- Add service catalog entry to services.yml
- Regenerate SERVICES.md via generate_service_catalog.py
- Add control-center role to Windows Docker host playbook

## Sub-Tasks

- [ ] Create `shared/active/02-config/ansible/playbooks/deploy-control-center.yml` (include the dashboard-control-center role, target windows_docker_hosts)
- [ ] Create `shared/active/02-config/ansible/playbooks/validate-control-center.yml` (health checks, domain checks, container status)
- [ ] Add just recipes: `ansible-deploy-control-center`, `ansible-validate-control-center` (following directory-empire pattern in justfile)
- [ ] Add service catalog entry to `shared/active/02-config/ansible/infrastructure/services.yml`
- [ ] Regenerate SERVICES.md: `python3 shared/active/02-config/ansible/scripts/generate_service_catalog.py`
- [ ] Add the control-center role to the Windows Docker host playbook (harden-windows-host.yml or equivalent)

## Relevant Files

- `shared/active/02-config/ansible/playbooks/deploy-directory-empire.yml` — reference playbook
- `shared/active/02-config/ansible/playbooks/deploy-control-center.yml` — new
- `shared/active/02-config/ansible/playbooks/validate-control-center.yml` — new
- `justfile` — add recipes
- `shared/active/02-config/ansible/infrastructure/services.yml` — add catalog entry
- `shared/active/02-config/ansible/scripts/generate_service_catalog.py` — run to regenerate
- Windows Docker host playbook (harden-windows-host.yml or equivalent) — add role

## Acceptance Criteria

- Given the deploy playbook, When `ansible-syntax` runs, Then it passes
- Given the validate playbook, When `ansible-syntax` runs, Then it passes
- Given the justfile, When `just ansible-deploy-control-center --check` runs, Then it executes without recipe errors
- Given the services.yml, When parsed, Then a control-center entry exists with monitoring metadata
- Given the SERVICES.md, When regenerated, Then it includes the control-center entry
- Given the Windows Docker host playbook, When inspecting, Then the dashboard-control-center role is included
- Verify: `just ansible-syntax` passes, `just ansible-deploy-control-center --check` runs

## Test Plan

- `just ansible-syntax` passes
- `just ansible-deploy-control-center --check` runs (dry run)
- `just ansible-validate-control-center --check` runs (dry run)
- `python3 shared/active/02-config/ansible/scripts/generate_service_catalog.py` succeeds
- SERVICES.md (root + levonk/) contains control-center entry

## Observability

- Deploy playbook reports container status after deployment
- Validate playbook checks health endpoint, domain resolution, container status
- Service catalog entry includes monitoring metadata

## Compliance

- Playbooks follow existing directory-empire pattern
- Generated catalogs (SERVICES.md) are NOT edited manually
- Service catalog entry includes source_repo link
- Just recipes follow existing naming convention

## Risks & Mitigations

- **SERVICES.md not regenerated**: Always run generate_service_catalog.py after editing services.yml
- **Role not included in host playbook**: Container won't deploy on host refresh; verify inclusion

## Dependencies & Sequencing

- **Dependencies**: 01-001 (infra vars), 01-002 (build script), 02-001 (role), 02-002 (traefik), 02-003 (DNS)
- **Dependants**: 04-001 (validation needs playbooks to exist)
- **Parallel-safe**: false (integration story, depends on all phase 1 and 2 stories)

## Definition of Done

- Playbooks exist, just recipes work, SERVICES.md regenerated
- `just ansible-syntax` passes
- `just ansible-deploy-control-center --check` runs
- Service catalog entry present with source_repo

## STOP Conditions

- Any prerequisite story is incomplete
- Service catalog generator fails
- Playbook syntax errors cannot be resolved

## Maintenance Notes

- SERVICES.md is generated — never edit manually
- To update the catalog, edit services.yml then re-run the generator
- Just recipes follow the `ansible-{action}-{service}` naming convention

## Commit Conventions

- Commit subject: `feat(ansible): add control-center deploy/validate playbooks and catalog`
- Body: list playbooks, just recipes, catalog entry, SERVICES.md regeneration

## Changelog

- 2026-08-30: Story created
