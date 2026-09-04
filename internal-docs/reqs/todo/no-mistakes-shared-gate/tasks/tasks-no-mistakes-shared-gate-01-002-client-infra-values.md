---
story_id: "01-002"
story_title: "Client infrastructure values + DNS"
story_name: "client-infra-values"
prd_name: "no-mistakes-shared-gate"
prd_file: "internal-docs/feature/todo/no-mistakes-shared-gate/feat-202608231257-no-mistakes-shared-gate.md"
phase: 1
parallel_id: 2
branch: "feature/current/no-mistakes-shared-gate/story-01-002-client-infra-values"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001"]
parallel_safe: true
modules: ["infrastructure", "dns"]
priority: "MUST"
risk_level: "low"
tags: ["infra", "client", "dns"]
due: "2026-08-23"
create-date: "2026-08-23"
update-date: "2026-08-23"
---

## Summary

Override the shared defaults with client-specific values in `levonk/active/02-config/ansible/infrastructure/` and add the Cloudflare DNS CNAME record.

## Sub-Tasks

- [ ] Add domain override to `levonk/active/02-config/ansible/infrastructure/domains.yml`:
  - `infra_domain_devops_no_mistakes: "no-mistakes.nl.levonk.com"` (nl = dtop202311 region)
- [ ] Add DNS CNAME record to `levonk/active/02-config/ansible/inventories/group_vars/all.yml` (or wherever `cloudflare_dns_records` is defined):
  - `no-mistakes.nl.levonk.com` → CNAME → `dtop202311.tale-grouper.ts.net`
- [ ] Verify the domain follows the `nl.levonk.com` convention (nl = dtop202311 Windows Docker Desktop)

## Relevant Files

- `levonk/active/02-config/ansible/infrastructure/domains.yml` — Client domain override
- `levonk/active/02-config/ansible/inventories/group_vars/all.yml` — DNS records

## Acceptance Criteria

- Given the client domains file, When referencing `infra_domain_devops_no_mistakes`, Then it resolves to "no-mistakes.nl.levonk.com"
- Given the DNS records, When deployed, Then `no-mistakes.nl.levonk.com` CNAMEs to `dtop202311.tale-grouper.ts.net`

## Test Plan

- `devbox run -- just ansible-lint-internal` passes
- YAML syntax valid

## Definition of Done

Domain override added, DNS record added, lint passes.

## Implementation Guide Reference

Follows `infrahub-add-new-service.md` Phase 2 (2c Domains, 2e DNS Record).
