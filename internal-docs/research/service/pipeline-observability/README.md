# Pipeline Observability Strategy — Research

Research for implementing ADR-202608270001: Pipeline Observability Strategy.

**ADR:** `shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`
**Status:** ADR is final — no alternative comparison. Research gathers deployment docs for chosen tools only.

## Research Files

| File | Scope |
|---|---|
| `prometheus-alertmanager.md` | Prometheus + Alertmanager images, config formats, inhibition rules, Ansible tasks, Promtail |
| `grafana-loki-uptime-kuma.md` | Grafana (datasource/dashboard provisioning), Loki (single-node config), Uptime Kuma (Socket.IO API), node_exporter |
| `synthetic-probes.md` | Probe execution patterns, blackbox_exporter, AI/DNS/web/VPN probe scripts, textfile collector, probe container |
| `infrahub-conventions.md` | Existing role patterns, Traefik dynamic config templates, playbook structure, justfile recipes, vault handoff |

## Key Findings

1. **Infrastructure variables already exist** — ports, domains, hostnames, storage volumes for all 6 monitoring services are defined in `shared/active/02-config/ansible/infrastructure/`. No client overrides needed for levonk.
2. **services.yml already has entries** for Prometheus, Grafana, Alertmanager, Loki, Uptime Kuma, node_exporter (lines 1208-1288).
3. **What's missing**: the 6 Ansible roles, the deploy playbook, the validation playbook, Traefik dynamic config templates, justfile recipes, vault secrets, and the actual probe scripts.
4. **Jaeger is excluded** — it appears in the old reference compose but is NOT part of the ADR.
5. **Textfile collector** is the recommended path for probe metrics (reuses node_exporter, no Pushgateway).
6. **Uptime Kuma has no REST API** — uses Socket.IO. Either configure via web UI or the `uptime-kuma-api` Python library.
7. **Vault handoff required** for 6 secrets: `vault_grafana_admin_password`, `vault_monitoring_ntfy_url`, `vault_monitoring_smtp_*`, `vault_monitoring_slack_webhook`, `vault_litellm_synthetic_probe_key`, `vault_omnigent_synthetic_probe_key`.

## Implementation Scope (6 ADR phases)

1. Infrastructure variables + Ansible roles (6 roles)
2. Per-node alert rules + Alertmanager inhibition
3. Synthetic probes (4 probe scripts + cron container)
4. Grafana dashboards (provisioning + JSON)
5. Vault secrets (6 secrets, user handoff)
6. Validation (deploy + verify inhibition + verify probes)
