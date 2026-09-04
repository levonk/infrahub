---
story_id: "01-001"
story_title: "Allocate infrastructure variables"
story_name: "infra-variables"
prd_name: "add-control-center-dashboard"
prd_file: "internal-docs/feature/todo/add-control-center-dashboard/feat-20260830-control-center-dashboard.md"
phase: 1
parallel_id: 1
branch: "feature/current/add-control-center-dashboard/story-01-001-infra-variables"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared/infrastructure", "levonk/infrastructure"]
priority: "MUST"
risk_level: "low"
tags: ["infra", "ansible", "yaml", "ports", "domains", "storage"]
due: "2026-08-30"
created_at: "2026-08-30"
updated_at: "2026-08-30"
---

## Summary

Add port, domain, storage, and hostname variables for control-center to the shared and levonk infrastructure files. Check for port conflicts before allocating. This is the foundation that all subsequent stories depend on.

## Current State

- `shared/active/02-config/ansible/infrastructure/ports.yml` — existing port allocations; no control-center entry yet
- `shared/active/02-config/ansible/infrastructure/domains.yml` — shared domain defaults; no control-center entry yet
- `shared/active/02-config/ansible/infrastructure/storage.yml` — storage allocations; no control-center entry yet
- `levonk/active/02-config/ansible/infrastructure/domains.yml` — client domain overrides; no control-center override yet
- Container listens on port 3000 (Next.js default); host port needs allocation in ports.yml

## Scope

- Add port variables (host + container) to shared ports.yml
- Add domain variables (default + nl) to shared domains.yml
- Add hostname variable to shared domains.yml
- Add storage volume variable to shared storage.yml
- Override both domains in levonk domains.yml to dashboard.levonk.com and dashboard.nl.levonk.com
- Verify no port conflicts before allocating host port

## Sub-Tasks

- [ ] Check ports.yml for an unused port (container port 3000, host port needs allocation). Verify no conflict with existing entries.
- [ ] Add `infra_port_dashboard_control_center_host` and `infra_port_dashboard_control_center_container` to `shared/active/02-config/ansible/infrastructure/ports.yml`
- [ ] Add `infra_domain_dashboard_control_center` and `infra_domain_dashboard_control_center_nl` to `shared/active/02-config/ansible/infrastructure/domains.yml` (defaults: dashboard.example.com, dashboard.nl.example.com)
- [ ] Override both domains in `levonk/active/02-config/ansible/infrastructure/domains.yml` to dashboard.levonk.com and dashboard.nl.levonk.com
- [ ] Add `infra_hostname_dashboard_control_center` to shared domains.yml (default: localnet-dashboard-control-center)
- [ ] Add `infra_storage_control_center_data_volume` to `shared/active/02-config/ansible/infrastructure/storage.yml`

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/ports.yml` — add host/container port vars
- `shared/active/02-config/ansible/infrastructure/domains.yml` — add domain + hostname vars
- `shared/active/02-config/ansible/infrastructure/storage.yml` — add data volume var
- `levonk/active/02-config/ansible/infrastructure/domains.yml` — client domain overrides

## Acceptance Criteria

- Given the shared ports.yml, When rendered, Then `infra_port_dashboard_control_center_host` and `infra_port_dashboard_control_center_container` are defined
- Given the shared domains.yml, When rendered, Then `infra_domain_dashboard_control_center`, `infra_domain_dashboard_control_center_nl`, and `infra_hostname_dashboard_control_center` are defined
- Given the shared storage.yml, When rendered, Then `infra_storage_control_center_data_volume` is defined
- Given the levonk domains.yml, When rendered, Then both domains resolve to dashboard.levonk.com and dashboard.nl.levonk.com
- Given the ports.yml, When checking for conflicts, Then no existing entry uses the allocated host port
- Verify: `grep infra_port_dashboard_control_center shared/active/02-config/ansible/infrastructure/ports.yml` shows both host and container vars

## Test Plan

- `grep infra_port_dashboard_control_center shared/active/02-config/ansible/infrastructure/ports.yml` shows both vars
- `grep infra_domain_dashboard_control_center shared/active/02-config/ansible/infrastructure/domains.yml` shows all domain vars
- `grep infra_storage_control_center_data_volume shared/active/02-config/ansible/infrastructure/storage.yml` shows the volume var
- `grep dashboard.levonk.com levonk/active/02-config/ansible/infrastructure/domains.yml` shows both overrides
- `just ansible-syntax` passes

## Observability

- Port allocation is recorded in ports.yml as the single source of truth
- Domain allocation is recorded in domains.yml as the single source of truth
- No runtime metrics (this story only defines variables)

## Compliance

- All variables follow `infra_{category}_{service}_{context}_{attribute}` naming convention
- No hardcoded IPs or ports in downstream consumers
- Shared directory contains only defaults; client overrides live in levonk submodule

## Risks & Mitigations

- **Port conflict**: Check ports.yml before allocating; STOP if conflict found (do not silently pick another port)
- **Domain collision**: Verify dashboard.levonk.com and dashboard.nl.levonk.com are not already allocated

## Dependencies & Sequencing

- **Dependencies**: None (this is the foundation story)
- **Dependants**: 02-001, 02-002, 02-003, 03-001 (all depend on these variables)
- **Parallel-safe**: true (can run alongside 01-002)

## Definition of Done

- All infra variables defined with `infra_` naming convention
- No port conflicts in ports.yml
- levonk overrides present for both domains
- `just ansible-syntax` passes

## STOP Conditions

- Port conflict found in ports.yml (do not silently pick another port)
- Domain already allocated to another service

## Maintenance Notes

- To change the host port, edit only `infra_port_dashboard_control_center_host` in ports.yml
- To change domains, edit only the levonk domains.yml overrides

## Commit Conventions

- Commit subject: `feat(infra): add control-center infrastructure variables`
- Body: list each variable added and its file

## Changelog

- 2026-08-30: Story created
