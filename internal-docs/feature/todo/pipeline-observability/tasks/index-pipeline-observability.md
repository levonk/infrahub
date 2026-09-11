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
| 01-010 | Vault secrets handoff | [x] Done | — | — |

## Execution Order

**Batch 1 (parallel)**: 01-001, 01-002, 01-003, 01-004, 01-005, 01-006, 01-010
**Batch 2**: 01-007 (after batch 1)
**Batch 3 (parallel)**: 01-008, 01-009 (after batch 2)

## Deployment Notes

- Port conflicts resolved: Loki host port 3100 -> 3135, Uptime Kuma host port 3001 -> 3136
- Alertmanager 0.34.0: removed http_config.headers (not valid), using ntfy query params for priority
- Loki 3.7.0: upgraded from boltdb-shipper/v11 to tsdb/v13, added delete_request_store for retention
- Grafana: moved dashboards.yml into dashboards dir to fix mount conflict
- Email alerts disabled per user request (ntfy-only notifications)
- All 7 containers running and healthy on oci-cloud-server
- Prometheus scraping active targets, rules loaded
- Alertmanager config loaded with topology-aware inhibition rules
