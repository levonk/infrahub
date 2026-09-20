---
story_id: "02-001"
story_title: "Shared + levonk infra vars, services.yml, catalogs"
story_name: "infra-vars-catalog"
prd_name: "acrm-deployment"
prd_file: "internal-docs/feature/todo/acrm-deployment/feat-202609191733-acrm-deployment.md"
phase: 2
parallel_id: 1
branch: "feature/current/acrm-deployment/story-02-001-infra-vars-catalog"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrastructure", "service-catalog"]
priority: "MUST"
risk_level: "low"
tags: ["infra", "ports", "domains", "networks", "storage", "services-yml", "shared", "levonk"]
due: "2026-09-19"
create-date: "2026-09-19"
update-date: "2026-09-19"
---

## Summary

Add the ACRM variable **schema** (neutral defaults) to the shared
infrastructure files and the concrete levonk values in the client submodule,
plus `infra_value_*` fallbacks and `services.yml` catalog entries. Ports
4538 (web host) and 5440 (postgres host) are verified free in both shared
and levonk `ports.yml`.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/infrastructure/ports.yml` — add an
  ACRM block near the other `ai_`/`nl` entries:
  - `infra_port_ai_acrm_host: "4538"`, `infra_port_ai_acrm_container: "3000"`
  - `infra_port_ai_acrm_postgres_host: "5440"`,
    `infra_port_ai_acrm_postgres_container: "5432"`
  - Re-scan both ports.yml files for 4538/5440/3000 conflicts before commit
- [ ] `shared/active/02-config/ansible/infrastructure/domains.yml`:
  - `infra_domain_ai_acrm: "acrm.nl.{{ infra_domain_base }}"`
  - `infra_domain_ai_acrm_api: "acrm-api.nl.{{ infra_domain_base }}"`
  - `infra_hostname_acrm_web: "localnet-acrm-web"`
  - `infra_hostname_acrm_postgres: "localnet-acrm-postgres"`
- [ ] `shared/active/02-config/ansible/infrastructure/networks.yml`:
  - `infra_network_ai_acrm_network_name: "acrm-network"`
- [ ] `shared/active/02-config/ansible/infrastructure/storage.yml`:
  - `infra_storage_acrm_postgres_data_volume: "localnet-acrm-postgres-data-volume"`
- [ ] `shared/active/02-config/ansible/infrastructure/values.yml` — add
  `infra_value_acrm_*` fallbacks (empty domains, `localnet-acrm-*` names,
  `"change-me"` postgres password, `"UTC"` tz) matching existing entries
- [ ] `levonk/active/02-config/ansible/infrastructure/domains.yml`
  (submodule — enter `levonk/` to edit):
  - `infra_domain_ai_acrm: "acrm.nl.levonk.com"`
  - `infra_domain_ai_acrm_api: "acrm-api.nl.levonk.com"`
  - (hostnames/network/ports need no client overrides — shared defaults are
    already correct)
- [ ] `shared/active/02-config/ansible/infrastructure/services.yml` — add
  "ACRM Web" (`machine: "dtop202311"`, `category: "api"`, `traefik: true`,
  `network: "traefik-windows-network"`, `health_endpoint: "/"`,
  `metrics_path: null`, `pipeline: "none"`, alert_labels, domains:
  `infra_domain_ai_acrm` + `infra_domain_ai_acrm_api`,
  `source_repo: "https://github.com/levonk/acrm"`) and "ACRM Postgres"
  (`category: "passive"`, `network: "acrm-network"`, no traefik/domains,
  `source_repo: "https://github.com/postgres/postgres"`) — exact field set
  in `internal-docs/research/service/acrm/deployment-design.md` §5
- [ ] Regenerate catalogs: `just generate-service-catalog` +
  `just generate-service-catalog-shared`; confirm
  `✓ All services have source_repo links`

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/{ports,domains,networks,storage,values,services}.yml`
- `levonk/active/02-config/ansible/infrastructure/domains.yml`
- `SERVICES.md`, `levonk/SERVICES.md` (generated)

## Acceptance Criteria

- Given the shared files, when loaded by a playbook, then all
  `infra_*_acrm*` vars resolve without client overrides
- Given the levonk domains.yml, when loaded, then `infra_domain_ai_acrm` =
  `acrm.nl.levonk.com` and `infra_domain_ai_acrm_api` =
  `acrm-api.nl.levonk.com`
- Given services.yml, when the generator runs, then both new entries appear
  in both catalogs with `source_repo` links and no missing-source warnings
- Given ports 4538/5440, when both ports.yml files are scanned, then no
  other service claims them

## Implementation Notes

- Follow the `infra_{category}_{service}_{context}_{attribute}` convention;
  category prefix is `ai` (role will be `ai-acrm`).
- The levonk submodule must be committed inside `levonk/` first, then the
  parent repo's submodule reference updated (submodule workflow rules).
- Do NOT add `infra_*` vars to group_vars/host_vars — infrastructure files
  only.

## Definition of Done

- All vars committed; catalogs regenerated clean; no port conflicts
