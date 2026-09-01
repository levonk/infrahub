---
story_id: "01-001"
story_title: "Shared infrastructure schemas for copyparty"
story_name: "shared-infra-schemas"
prd_name: "copyparty-deploy"
prd_file: "internal-docs/feature/todo/copyparty-deploy/feat-202608312209-copyparty-deploy.md"
phase: 1
parallel_id: 1
branch: "feature/current/copyparty-deploy/story-01-001-shared-infra-schemas"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["shared-infra"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "infrastructure", "shared"]
due: "2026-08-31"
create-date: "2026-08-31"
update-date: "2026-08-31"
---

## Summary

Add the variable **schema** (neutral defaults) for copyparty to the shared
infrastructure files: `ports.yml`, `domains.yml`, and `storage.yml`. These are
defaults that any client can override. No client-specific values here.

## Sub-Tasks

- [ ] Add port variables to `shared/active/02-config/ansible/infrastructure/ports.yml`:
  - `infra_port_storage_copyparty_host: "3923"`
  - `infra_port_storage_copyparty_container: "3923"`
  - Add a comment header `# copyparty (File Sharing Server)`
- [ ] Add domain variable to `shared/active/02-config/ansible/infrastructure/domains.yml`:
  - `infra_domain_storage_copyparty: "files.{{ infra_domain_base }}"`
  - Add a comment header `# copyparty (File Sharing Server)`
- [ ] Add storage variables to `shared/active/02-config/ansible/infrastructure/storage.yml`:
  - `infra_storage_copyparty_data_volume: "localnet-copyparty-data-volume"`
  - `infra_storage_copyparty_config_volume: "localnet-copyparty-config-volume"`
  - `infra_storage_copyparty_config_dir: "{{ infra_storage_services_dir }}/copyparty"`
  - Add a comment header `# copyparty (File Sharing Server)`
- [ ] Verify no port conflicts: scan `ports.yml` AND
  `levonk/active/02-config/ansible/infrastructure/ports.yml` for port 3923

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/ports.yml` — add port schema
- `shared/active/02-config/ansible/infrastructure/domains.yml` — add domain schema
- `shared/active/02-config/ansible/infrastructure/storage.yml` — add storage schema
- `levonk/active/02-config/ansible/infrastructure/ports.yml` — check for conflicts (read-only)

## Acceptance Criteria (Gherkin)

- Given the shared `ports.yml`, When a client references `infra_port_storage_copyparty_host`, Then it resolves to `"3923"`
- Given the shared `domains.yml`, When a client references `infra_domain_storage_copyparty`, Then it resolves to `"files.{{ infra_domain_base }}"`
- Given the shared `storage.yml`, When a client references `infra_storage_copyparty_data_volume`, Then it resolves to `"localnet-copyparty-data-volume"`
- Given all infrastructure files, When searching for port `3923`, Then no conflicts exist with other services

## Test Plan

- Manual: `grep -r "3923" shared/active/02-config/ansible/infrastructure/ levonk/active/02-config/ansible/infrastructure/` returns only the new copyparty entries
- Manual: YAML is valid (no syntax errors)

## Definition of Done

- All three shared infrastructure files have copyparty entries with comment headers
- No port conflicts
- YAML syntax is valid
