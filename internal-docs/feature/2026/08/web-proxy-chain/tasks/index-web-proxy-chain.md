---
slug: web-proxy-chain
title: "Web Proxy Chain — Task Index"
prd: internal-docs/feature/2026/08/web-proxy-chain/prd-web-proxy-chain.md
last_updated: "2026-08-10"
---

# Task Index — Web Proxy Chain

| Story | Title | Phase | Status | Depends On |
|-------|-------|-------|--------|------------|
| [01-001](story-01-001-shared-infrastructure-schemas.md) | Shared infrastructure schemas (ports, networks, IPs, domains, storage) | 1 | [ ] Todo | — |
| [02-001](story-02-001-client-infrastructure-values.md) | Client infrastructure values (levonk overrides, DNS CNAMEs, services.yml, SERVICES.md) | 2 | [ ] Todo | 01-001 |
| [03-001](story-03-001-build-pipeline-gost.md) | Build pipeline for Gost image | 3 | [ ] Todo | 01-001 |
| [05-001](story-05-001-ansible-role-proxy-web.md) | Ansible role proxy-web (defaults, tasks, templates) | 5 | [ ] Todo | 01-001, 03-001 |
| [06-001](story-06-001-traefik-routing.md) | Traefik dynamic config for proxy-web dashboards + CA cert download | 6 | [ ] Todo | 05-001 |
| [07-001](story-07-001-playbook-inventory.md) | Playbook + inventory wiring + just recipes | 7 | [ ] Todo | 05-001, 06-001 |
| [08-001](story-08-001-documentation.md) | Documentation (AGENTS.md, SERVICES.md, role README) | 8 | [ ] Todo | 07-001 |

## Execution Order

1. **01-001** (shared schemas) — no dependencies, start first
2. **02-001** (client values) + **03-001** (build pipeline) — both depend on 01-001, can run in parallel
3. **05-001** (Ansible role) — depends on 01-001 and 03-001
4. **06-001** (Traefik routing) — depends on 05-001
5. **07-001** (playbook + inventory) — depends on 05-001 and 06-001
6. **08-001** (documentation) — depends on 07-001

## Notes

- Phase 4 (Vault Secrets) is skipped — no secrets needed for the proxy chain
- The MITM CA is generated at runtime, not a vault secret
- Gost is the only locally-built image (MITM, Privoxy, Varnish use upstream images)
