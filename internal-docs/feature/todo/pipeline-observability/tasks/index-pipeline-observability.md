# Task Index: pipeline-observability

**PRD**: `internal-docs/feature/todo/pipeline-observability/prd.md`
**ADR**: `shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`
**Research**: `internal-docs/research/service/pipeline-observability/`

## Stories

| ID | Title | Status | Depends | Branch |
|----|-------|--------|---------|--------|
| 01-001 | monitoring-prometheus role | [x] Done | — | master |
| 01-002 | monitoring-alertmanager role | [x] Done | — | master |
| 01-003 | monitoring-loki role (Loki + Promtail) | [x] Done | — | master |
| 01-004 | monitoring-grafana role | [x] Done | — | master |
| 01-005 | monitoring-uptime-kuma role | [x] Done | — | master |
| 01-006 | monitoring-synthetic-probes role | [x] Done | — | master |
| 01-007 | Traefik dynamic config templates | [x] Done | 01-001..006 | master |
| 01-008 | Deploy + validation playbook + justfile | [x] Done | 01-001..007 | master |
| 01-009 | Grafana dashboards | [x] Done | 01-004 | master |
| 01-010 | Vault secrets handoff | [~] In-Progress | — | — |

## Execution Order

**Batch 1 (parallel)**: 01-001, 01-002, 01-003, 01-004, 01-005, 01-006, 01-010
**Batch 2**: 01-007 (after batch 1)
**Batch 3 (parallel)**: 01-008, 01-009 (after batch 2)

## Notes

- All 7 roles created (6 monitoring + node-exporter) and committed.
- Traefik templates, playbooks, dashboards, and justfile recipes committed.
- Story 01-010 (vault handoff) is in progress — waiting for user to add secrets.
- Pre-existing uncommitted changes (values.yml, deploy-verdaccio.yml, npmjs/hister templates) were NOT touched.
