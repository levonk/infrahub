---
story_id: "02-002"
story_title: "Create Traefik dynamic config template"
story_name: "traefik-config"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 2
parallel_id: 2
branch: "feature/current/add-control-center-dashboard/story-02-002-traefik-config"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["shared/roles/proxy_traefik_windows/templates"]
priority: "MUST"
risk_level: "low"
tags: ["traefik", "ansible", "templates", "routing"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Create Traefik dynamic config Jinja2 templates for both domains (dashboard.levonk.com and dashboard.nl.levonk.com) with Authelia middleware, following the de-nl.yml.j2 pattern.

## Current State

- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/de-nl.yml.j2` — reference Traefik dynamic config (Authelia-gated HTTPS router)
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/defaults/main.yml` — role defaults
- No control-center Traefik templates exist yet
- Authelia already deployed and configured for Windows Traefik

## Scope

- Create `cc-nl.yml.j2` for dashboard.nl.levonk.com (Authelia-gated HTTPS router)
- Create `cc-default.yml.j2` for dashboard.levonk.com (Authelia-gated HTTPS router)
- Add domain variables to proxy_traefik_windows defaults/main.yml
- Add template files to the proxy_traefik_windows role's task that deploys dynamic configs

## Sub-Tasks

- [ ] Read `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/de-nl.yml.j2` as reference
- [ ] Create `cc-nl.yml.j2` for dashboard.nl.levonk.com (Authelia-gated HTTPS router)
- [ ] Create `cc-default.yml.j2` for dashboard.levonk.com (Authelia-gated HTTPS router)
- [ ] Add `proxy_traefik_windows_control_center_domain` and `proxy_traefik_windows_control_center_domain_default` variables to proxy_traefik_windows `defaults/main.yml`
- [ ] Add the template files to the proxy_traefik_windows role's task that deploys dynamic configs

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/de-nl.yml.j2` — reference template
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/cc-nl.yml.j2` — new
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/cc-default.yml.j2` — new
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/defaults/main.yml` — add domain vars
- `shared/active/02-config/ansible/roles/proxy_traefik_windows/tasks/main.yml` — add template deployment

## Acceptance Criteria

- Given the cc-nl.yml.j2 template, When rendered, Then it produces valid YAML with an HTTPS router for dashboard.nl.levonk.com
- Given the cc-default.yml.j2 template, When rendered, Then it produces valid YAML with an HTTPS router for dashboard.levonk.com
- Given both templates, When inspecting, Then Authelia middleware is referenced
- Given the proxy_traefik_windows defaults, When inspecting, Then `proxy_traefik_windows_control_center_domain` and `proxy_traefik_windows_control_center_domain_default` are defined
- Given the role tasks, When inspecting, Then both templates are deployed
- Verify: `just ansible-syntax` passes

## Test Plan

- `just ansible-syntax` passes
- Render templates locally and validate YAML syntax
- Verify Authelia middleware chain is referenced in both templates

## Observability

- Traefik dashboard shows both routers when deployed
- Authelia logs show authentication attempts for both domains

## Compliance

- All domains reference `infra_*` or `proxy_traefik_windows_*` variables (no hardcoding)
- Authelia middleware provides outer SSO gate before app's own auth
- Templates follow existing de-nl.yml.j2 pattern

## Risks & Mitigations

- **Traefik Windows proxy not deployed on dtop202311**: STOP (per PRD STOP conditions)
- **Authelia not configured for Windows Traefik**: STOP (per PRD STOP conditions)
- **Template renders invalid YAML**: Validate locally before deploying

## Dependencies & Sequencing

- **Dependencies**: 01-001 (domain variables must exist)
- **Dependants**: 03-001 (playbook deploys these templates via the role)
- **Parallel-safe**: true (can run alongside 02-001, 02-003)

## Definition of Done

- Both templates render valid YAML
- Authelia middleware referenced in both
- `just ansible-syntax` passes
- Templates added to the role's dynamic config deployment task

## STOP Conditions

- Traefik Windows proxy is not deployed on dtop202311
- Authelia is not configured for the Windows Traefik

## Maintenance Notes

- To add a third domain, create another cc-*.yml.j2 template and add it to the deployment task
- Authelia middleware name must match the existing Authelia forward-auth configuration

## Commit Conventions

- Commit subject: `feat(traefik): add control-center dynamic config templates`
- Body: describe both templates, domain variables added

## Changelog

- 2026-08-30: Story created
