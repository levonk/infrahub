---
story: 01-001
name: shared-infra-schemas
status: "Todo"
depends: []
branch: feature/current/verdaccio-dual-deployment/story-01-001-shared-infra-schemas
---

# Story 01-001: Shared Infrastructure Schemas

## Goal

Add verdaccio variable schemas (neutral defaults) to shared infrastructure files.

## Tasks

1. **Ports** — `shared/active/02-config/ansible/infrastructure/ports.yml`
   - Add `infra_port_artifact_verdaccio_host: "4873"` and `infra_port_artifact_verdaccio_container: "4873"`
   - Check for port 4873 conflicts in shared + levonk ports.yml

2. **Domains** — `shared/active/02-config/ansible/infrastructure/domains.yml`
   - Add `infra_domain_artifact_verdaccio_cno: "npmjs.cno.levonk.com"`
   - Add `infra_domain_artifact_verdaccio_nl: "npmjs.nl.levonk.com"`

3. **Storage** — `shared/active/02-config/ansible/infrastructure/storage.yml`
   - Add `infra_storage_verdaccio_volume: "localnet-verdaccio-data-volume"`
   - Add `infra_storage_verdaccio_config_dir: "{{ infra_storage_services_dir }}/verdaccio"`

4. **Networks** — No new network needed (joins `traefik-network` on cno; standalone on nl)

## Acceptance Criteria

- [ ] ports.yml has verdaccio port variables
- [ ] domains.yml has both cno and nl domain variables
- [ ] storage.yml has verdaccio volume + config dir variables
- [ ] No port conflicts (4873 not already assigned)
- [ ] All variables follow `infra_{CATEGORY}_{SERVICE}_{CONTEXT}_{ATTRIBUTE}` naming

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 1 (Shared Infrastructure Schemas).
