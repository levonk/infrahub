---
slug: web-proxy-chain
title: "Web Proxy Chain — Task Index"
prd: internal-docs/feature/2026/08/web-proxy-chain/prd-web-proxy-chain.md
last_updated: "2026-08-10"
---

# Task Index — Web Proxy Chain

| Story | Title | Phase | Status | Depends On |
|-------|-------|-------|--------|------------|
| [01-001](story-01-001-shared-infrastructure-schemas.md) | Shared infrastructure schemas (ports, networks, IPs, domains, storage) | 1 | [x] Done | — |
| [02-001](story-02-001-client-infrastructure-values.md) | Client infrastructure values (levonk overrides, DNS CNAMEs, services.yml, SERVICES.md) | 2 | [x] Done | 01-001 |
| [03-001](story-03-001-build-pipeline-gost.md) | Build pipeline for Gost image | 3 | [x] Done | 01-001 |
| [05-001](story-05-001-ansible-role-proxy-web.md) | Ansible role proxy-web (defaults, tasks, templates) | 5 | [x] Done | 01-001, 03-001 |
| [06-001](story-06-001-traefik-routing.md) | Traefik dynamic config for proxy-web dashboards + CA cert download | 6 | [x] Done | 05-001 |
| [07-001](story-07-001-playbook-inventory.md) | Playbook + inventory wiring + just recipes | 7 | [x] Done | 05-001, 06-001 |
| [08-001](story-08-001-documentation.md) | Documentation (AGENTS.md, SERVICES.md, role README) | 8 | [x] Done | 07-001 |

## Notes

- Phase 4 (Vault Secrets) was skipped — no secrets needed for the proxy chain
- The MITM CA is generated at runtime, not a vault secret
- Gost is the only locally-built image (MITM, Privoxy, Varnish use upstream images)
- Pre-existing Gost Dockerfile bug: download URL for gost v3.0.0-rc8 returns 404 — needs fix before deployment
