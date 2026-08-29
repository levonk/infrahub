---
story_id: "02-001"
story_title: "Service catalog entry + regeneration"
story_name: "service-catalog"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 2
parallel_id: 1
branch: "feature/current/no-mistakes-shared-gate/story-02-001-service-catalog"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["catalog"]
priority: "MUST"
risk_level: "low"
tags: ["catalog", "docs"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Add the no-mistakes service entry to `services.yml` and regenerate both service catalogs (client + repo-root).

## Sub-Tasks

- [ ] Add entry to `shared/active/02-config/ansible/infrastructure/services.yml` under the `services:` key:
  ```yaml
  - name: "no-mistakes Gate"
    container: "localnet-no-mistakes"
    machine: "dtop202311"
    category: "infra"
    description: "Shared AI-driven git gate proxy — validates pushes before GitHub PR"
    source_repo: "https://github.com/kunchenguid/no-mistakes"
    domains:
      - "infra_domain_devops_no_mistakes"
    ports:
      - host: "infra_port_devops_no_mistakes_ssh_host"
        container: "infra_port_devops_no_mistakes_ssh_container"
        label: "SSH Git"
    network: "traefik-windows-network"
  ```
- [ ] Run `devbox run -- just generate-service-catalog` (regenerates levonk/SERVICES.md)
- [ ] Run `devbox run -- just generate-service-catalog-shared` (regenerates SERVICES.md)
- [ ] Verify the generator reports "✓ All services have source_repo links"

## Relevant Files

- `shared/active/02-config/ansible/infrastructure/services.yml` — Add service entry
- `levonk/SERVICES.md` — Generated (do not edit manually)
- `SERVICES.md` — Generated (do not edit manually)

## Acceptance Criteria

- Given services.yml, When the generator runs, Then no-mistakes appears in both SERVICES.md files
- Given the generator output, When checking source_repo, Then "✓ All services have source_repo links" is printed

## Test Plan

- `devbox run -- just generate-service-catalog-all` succeeds
- Both SERVICES.md files contain the no-mistakes entry

## Definition of Done

Service entry added, both catalogs regenerated, source_repo validation passes.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 2 (2f Service Catalog, 2g Regenerate).
