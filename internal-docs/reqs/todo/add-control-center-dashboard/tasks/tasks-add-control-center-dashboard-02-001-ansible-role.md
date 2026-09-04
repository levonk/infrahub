---
story_id: "02-001"
story_title: "Create Ansible role for control-center"
story_name: "ansible-role"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 2
parallel_id: 1
branch: "feature/current/add-control-center-dashboard/story-02-001-ansible-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["shared/roles/dashboard-control-center"]
priority: "MUST"
risk_level: "low"
tags: ["ansible", "role", "docker", "deploy"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Create the `dashboard-control-center` Ansible role following the dashboard-directory-empire pattern. Includes defaults/main.yml, tasks/main.yml, handlers/main.yml, meta/main.yml, README.md.

## Current State

- `shared/active/02-config/ansible/roles/dashboard-directory-empire/` — reference role for dtop202311 deployment (defaults, tasks, handlers, meta)
- Windows Docker hosts use `delegate_to: localhost` + `DOCKER_HOST: ssh://` (community.docker modules fail on Windows)
- No dashboard-control-center role exists yet

## Scope

- Create role directory structure under `shared/active/02-config/ansible/roles/dashboard-control-center/`
- defaults/main.yml with all variables referencing `infra_*` variables
- tasks/main.yml: validate vars, ensure volume, pull image, deploy container, healthcheck
- handlers/main.yml: restart container (state: started, restart: true — NEVER state: restarted)
- meta/main.yml with role_name: dashboard_control_center
- README.md with backup/restore documentation

## Sub-Tasks

- [ ] Read `shared/active/02-config/ansible/roles/dashboard-directory-empire/` as reference (defaults, tasks, handlers, meta)
- [ ] Create `defaults/main.yml` with all variables referencing `infra_*` variables, healthcheck config, env vars (CONTROL_CENTER_ALLOWED_HOSTS, CONTROL_CENTER_DATA_DIR)
- [ ] Create `tasks/main.yml`: validate vars, ensure volume exists, pull image, deploy container (docker via DOCKER_HOST ssh:// delegate_to localhost), healthcheck
- [ ] Create `handlers/main.yml`: restart container (state: started, restart: true — NEVER state: restarted)
- [ ] Create `meta/main.yml` with role_name: dashboard_control_center
- [ ] Create `README.md` with backup/restore documentation

## Relevant Files

- `shared/active/02-config/ansible/roles/dashboard-directory-empire/` — reference role
- `shared/active/02-config/ansible/roles/dashboard-control-center/defaults/main.yml` — new
- `shared/active/02-config/ansible/roles/dashboard-control-center/tasks/main.yml` — new
- `shared/active/02-config/ansible/roles/dashboard-control-center/handlers/main.yml` — new
- `shared/active/02-config/ansible/roles/dashboard-control-center/meta/main.yml` — new
- `shared/active/02-config/ansible/roles/dashboard-control-center/README.md` — new

## Acceptance Criteria

- Given the role, When `ansible-lint` runs, Then it passes with no new violations
- Given the role defaults, When inspecting, Then all variables reference `infra_*` vars (no hardcoded ports/IPs)
- Given the tasks, When inspecting container deployment, Then `DOCKER_HOST: ssh://` + `delegate_to: localhost` is used
- Given the handler, When inspecting, Then `state: started` + `restart: true` (not `state: restarted`)
- Given the healthcheck, When inspecting, Then it uses `curl -sf /api/health`
- Given the container config, When inspecting, Then `restart_policy: unless-stopped`
- Given the env vars, When inspecting, Then `CONTROL_CENTER_ALLOWED_HOSTS` and `CONTROL_CENTER_DATA_DIR` are set
- Verify: `just ansible-lint` passes for the new role

## Test Plan

- `just ansible-lint` passes for the new role
- `just ansible-syntax` passes
- `ansible-playbook --check` against windows-docker inventory (dry run) passes

## Observability

- Healthcheck uses `curl -sf /api/health` endpoint
- Container restart_policy: unless-stopped
- Task reports container status after deployment

## Compliance

- All IPs/ports/domains reference `infra_*` variables (no hardcoding)
- Windows Docker pattern: `delegate_to: localhost` + `DOCKER_HOST: ssh://`
- Handler uses `state: started` + `restart: true` (never `state: restarted`)
- Healthcheck durations are strings with unit suffixes
- project-lint compliant (no magic numbers)

## Risks & Mitigations

- **community.docker modules fail on Windows**: Use `ansible.builtin.shell` with `DOCKER_HOST: ssh://` and `delegate_to: localhost`
- **Healthcheck false positives**: Use `curl -sf /api/health` which returns 503 if DB unhealthy

## Dependencies & Sequencing

- **Dependencies**: 01-001 (infra variables must exist for the role to reference)
- **Dependants**: 03-001 (playbook includes this role)
- **Parallel-safe**: true (can run alongside 02-002, 02-003)

## Definition of Done

- Role passes ansible-lint
- All variables reference `infra_*` vars, no hardcoded ports/IPs
- Handler uses state: started + restart: true
- README.md includes backup/restore documentation

## STOP Conditions

- ansible-lint violations cannot be resolved
- project-lint violations cannot be resolved with legitimate disable comments

## Maintenance Notes

- Image rebuild: run `just build-control-center-image` after fork updates, then redeploy
- Data backup: rsync the SQLite volume to backup location (documented in role README)
- First user registration: visit /register after Authelia auth to create the first tenant

## Commit Conventions

- Commit subject: `feat(ansible): add dashboard-control-center role`
- Body: describe role structure, defaults, tasks, handlers

## Changelog

- 2026-08-30: Story created
