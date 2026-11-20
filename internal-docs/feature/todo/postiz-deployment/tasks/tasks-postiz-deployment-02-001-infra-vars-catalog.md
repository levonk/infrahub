---
story_id: "02-001"
story_title: "Shared + levonk infra vars, services.yml, catalogs for Postiz"
story_name: "infra-vars-catalog"
prd_name: "postiz-deployment"
prd_file: "internal-docs/feature/todo/postiz-deployment/feat-202611131708-postiz-deployment.md"
phase: 2
parallel_id: 1
branch: "levonk/20261113-postiz"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrastructure", "ansible-vars", "services-catalog"]
priority: "MUST"
risk_level: "low"
tags: ["infrastructure", "ports", "domains", "networks", "storage", "services-yml", "postiz"]
due: "2026-11-13"
create-date: "2026-11-13"
update-date: "2026-11-13"
---

## Summary

Add all `infra_*` schema variables for Postiz to the shared infrastructure
files (ports, networks, domains, storage, values fallbacks) and the service
catalog (`services.yml`) entries for the six containers, then regenerate
both service catalogs. Follow impl guide Phases 1-2 exactly; acrm is the
precedent block to copy.

## Sub-Tasks

- [ ] `shared/active/02-config/ansible/infrastructure/ports.yml` — Postiz
  section:
  - `infra_port_tools_postiz_host: "4539"` (web, tailnet debug; Traefik
    routes by container name — this is not the public path)
  - `infra_port_tools_postiz_container: "5000"`
  - `infra_port_tools_postiz_postgres_host: "5441"` (tailnet debug only)
  - `infra_port_tools_postiz_postgres_container: "5432"`
  - `infra_port_tools_postiz_temporal_postgres_host: "5442"` (debug only)
  - `infra_port_tools_postiz_temporal_postgres_container: "5432"`
  (ports 4539/5441/5442 verified free against both ports.yml files)
- [ ] `shared/.../networks.yml` — `infra_network_tools_postiz_network_name:
  "postiz-network"`, `infra_network_tools_postiz_temporal_network_name:
  "postiz-temporal-network"`
- [ ] `shared/.../domains.yml` — nl region section:
  `infra_domain_tools_postiz: "postiz.nl.{{ infra_domain_base }}"` +
  `infra_hostname_postiz: "localnet-postiz"`,
  `infra_hostname_postiz_postgres: "localnet-postiz-postgres"`,
  `infra_hostname_postiz_redis: "localnet-postiz-redis"`,
  `infra_hostname_postiz_temporal: "localnet-postiz-temporal"`,
  `infra_hostname_postiz_temporal_postgres: "localnet-postiz-temporal-postgres"`
- [ ] `shared/.../storage.yml` —
  `infra_storage_postiz_uploads_volume: "localnet-postiz-uploads-volume"`,
  `infra_storage_postiz_postgres_data_volume: "localnet-postiz-postgres-data-volume"`,
  `infra_storage_postiz_redis_data_volume: "localnet-postiz-redis-data-volume"`,
  `infra_storage_postiz_temporal_postgres_data_volume: "localnet-postiz-temporal-postgres-data-volume"`,
  `infra_storage_postiz_temporal_dynamicconfig_volume: "localnet-postiz-temporal-dynamicconfig-volume"`
- [ ] `shared/.../values.yml` — `infra_value_postiz_*` fallbacks matching
  the acrm fallback pattern (domain, container names, docker host, tz)
- [ ] `shared/.../services.yml` — five entries (Postiz app, Postiz
  Postgres, Postiz Redis, Postiz Temporal, Postiz Temporal Postgres) in
  the same schema as the ACRM entries: `name`, `container`, `machine:
  "dtop202311"`, `category`, `description`, `source_repo`,
  `domains`, `ports`, `traefik`, `network`, `storage`, `health_endpoint`,
  `alert_labels`. App entry: `traefik: true`, `network:
  "traefik-windows-network"`, `health_endpoint: "/"`, `source_repo:
  "https://github.com/gitroomhq/postiz-app"`.
- [ ] Levonk client overrides — add matching comment/vars in
  `levonk/active/02-config/ansible/infrastructure/*.yml` ONLY if a value
  differs from shared defaults (acrm needed none — likely none needed).
- [ ] Regenerate catalogs per impl guide 2g (`just` recipes for
  SERVICES.md + levonk/SERVICES.md).
- [ ] DNS record is story 04-001, not here.

## Acceptance Criteria

- `grep -rn postiz shared/active/02-config/ansible/infrastructure/` returns
  the new vars; `ansible-playbook --syntax-check` of any playbook still
  passes; catalogs regenerated without errors.
