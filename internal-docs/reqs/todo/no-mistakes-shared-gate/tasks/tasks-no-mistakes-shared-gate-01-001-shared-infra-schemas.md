---
story_id: "01-001"
story_title: "Shared infrastructure schemas"
story_name: "shared-infra-schemas"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 1
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-01-001-shared-infra-schemas"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrastructure"]
priority: "MUST"
risk_level: "low"
tags: ["infra", "shared"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Add the variable **schema** (neutral defaults) for the no-mistakes service to the shared infrastructure files: ports, domains, and storage. These are defaults that any client can override.

## Sub-Tasks

- [ ] Add port variables to `shared/active/02-config/ansible/infrastructure/ports.yml`:
  - `infra_port_devops_no_mistakes_ssh_host: "2222"`
  - `infra_port_devops_no_mistakes_ssh_container: "2222"`
- [ ] Add domain variable to `shared/active/02-config/ansible/infrastructure/domains.yml`:
  - `infra_domain_devops_no_mistakes: "no-mistakes.levonk.com"` (shared default; client overrides to nl.levonk.com)
- [ ] Add storage variables to `shared/active/02-config/ansible/infrastructure/storage.yml`:
  - `infra_storage_no_mistakes_volume: "localnet-no-mistakes-data"`
  - `infra_storage_no_mistakes_config_dir: "{{ infra_storage_services_dir }}/no-mistakes"`
- [ ] Verify no port conflicts (scan both shared and levonk port files for 2222)

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/ports.yml` — Add SSH port variables
- `shared/active/02-config/ansible/infrastructure/domains.yml` — Add domain variable
- `shared/active/02-config/ansible/infrastructure/storage.yml` — Add storage variables

## Acceptance Criteria

- Given the shared ports file, When a client references `infra_port_devops_no_mistakes_ssh_host`, Then it resolves to "2222"
- Given the shared domains file, When a client references `infra_domain_devops_no_mistakes`, Then it resolves to "no-mistakes.levonk.com"
- Given the shared storage file, When a client references `infra_storage_no_mistakes_volume`, Then it resolves to "localnet-no-mistakes-data"
- Given all port files, When scanning for port 2222, Then no conflicts exist

## Test Plan

- `devbox run -- just ansible-lint-internal` passes
- YAML syntax valid (no duplicate keys, proper indentation)

## Definition of Done

All sub-tasks complete, no port conflicts, lint passes.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 1 (1a Ports, 1c Domains, 1d Storage).
