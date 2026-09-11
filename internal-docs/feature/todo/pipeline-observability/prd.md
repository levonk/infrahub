---
slug: pipeline-observability
title: Pipeline Observability Strategy — Topology-Aware Monitoring with Alert Inhibition
adr: adr-202608270001
client: levonk
status: in-progress
created: 2026-08-27
tech-context: |
  ## Tech Context (Binding Constraint)
  - Package manager: Nix (Determinate Nix) + Devbox
  - Ad-hoc runner: devbox run -- rtk <command>
  - Build system: Just (justfile)
  - Test runner: ansible-playbook --syntax-check, --check mode
  - Linter: ansible-lint, yamllint
  - Container runtime: Docker (via community.docker Ansible modules)
  - CI/CD: (none for this task)
  System tools run via: devbox run -- <command>
  Never use: npm, npx, yarn, jest, biome, docker compose
---

# PRD: Pipeline Observability Strategy

## Goal

Implement the topology-aware, per-client monitoring stack described in ADR-202608270001 for the Levonk client. Central collection on `oci-cloud-server`; other hosts submit instrumentation. Alertmanager identifies root causes and suppresses cascading downstream alerts. Synthetic probes validate end-to-end AI, DNS, web-proxy, and VPN/egress pipelines.

## Background

The ADR (`shared/active/08-docs/adr/adr-202608270001-pipeline-observability-strategy.md`) is the final decision. No alternative comparison. Research is at `internal-docs/research/service/pipeline-observability/`.

## Architecture

### Current State
- Infrastructure variables (ports, domains, hostnames, storage) already defined in `shared/active/02-config/ansible/infrastructure/`.
- `services.yml` already has catalog entries for all 6 monitoring services.
- No monitoring Ansible roles exist.
- No deploy playbook exists.
- No validation playbook exists.
- Reference compose exists but is documentation-only (not for production).

### Target Architecture
```
                    ┌─────────────────────────────────────────┐
                    │         oci-cloud-server                 │
                    │  ┌──────────┐  ┌──────┐  ┌──────────┐   │
                    │  │Prometheus│→│Grafana│  │Alertmgr  │   │
                    │  └────┬─────┘  └──┬───┘  └────┬─────┘   │
                    │       │           │            │         │
                    │  ┌────▼─────┐  ┌──▼───┐  ┌────▼─────┐   │
                    │  │node_exp  │  │ Loki  │  │UptimeKuma│  │
                    │  └────┬─────┘  └──┬───┘  └──────────┘   │
                    │       │           │                      │
                    │  ┌────▼───────────▼──────────────┐     │
                    │  │  Synthetic Probes (cron)       │     │
                    │  │  → textfile collector          │     │
                    │  └────────────────────────────────┘     │
                    └─────────────────────────────────────────┘
                                     ↑
                    ┌────────────────┼────────────────┐
                    │                │                │
              other hosts      Traefik ingress    ntfy/SMTP
              (submit metrics  (Grafana,         (notifications)
               via Prometheus  Alertmanager,
               scrape)         Uptime Kuma)
```

### Pipeline Topology (from ADR)

1. **AI**: Omnigent → Pi → LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN
2. **DNS**: AdGuard → dnsdist → CoreDNS → DNSCrypt/Tor → upstream resolvers
3. **Web proxy**: MITM → Privoxy → Varnish → Gost → Tor
4. **VPN/egress**: NordVPN / WireGuard / Tor / host-direct exit nodes

## Scope

### In Scope
- 6 Ansible roles: monitoring-prometheus, monitoring-loki, monitoring-grafana, monitoring-alertmanager, monitoring-uptime-kuma, monitoring-synthetic-probes
- Deploy playbook: deploy-monitoring-stack.yml
- Validation playbook: validate-monitoring-stack.yml
- Traefik dynamic config templates for Grafana, Alertmanager, Uptime Kuma
- Prometheus scrape config + alert rules
- Alertmanager config with topology-aware inhibition rules
- Loki single-node config + Promtail for Docker log collection
- Grafana datasource + dashboard provisioning
- Synthetic probe scripts (AI, DNS, web, VPN) + cron container
- node_exporter with textfile collector
- Just recipes: ansible-deploy-monitoring, ansible-validate-monitoring
- Vault secret handoff for 6 secrets
- Grafana dashboards (per-pipeline)

### Out of Scope
- Jaeger (excluded by ADR)
- Langfuse (already exists, not part of this stack)
- External Upptime monitoring (separate)
- Docker Compose deployment (deprecated)
- Alternative tool comparison (ADR is final)

## Success Criteria

1. `just ansible-validate-monitoring` passes (syntax + check mode)
2. All 6 monitoring containers start healthy on `oci-cloud-server`
3. Prometheus scrapes all existing metrics endpoints (Traefik, Authelia, CrowdSec, CoreDNS, dnsdist, node_exporter)
4. Loki receives Docker container logs
5. Grafana renders dashboards with live data
6. Alertmanager routes notifications to ntfy
7. Uptime Kuma is reachable via Traefik
8. Synthetic probes run on schedule and produce textfile metrics
9. Per-node alerts fire when a service is down
10. Inhibition suppresses downstream alerts when the root cause is identified
11. AI probes return token counts
12. No hardcoded ports, IPs, or domains in any role or template

## Implementation Plan

### Story Breakdown

| Story | Title | Size | Dependencies |
|------|-------|------|-------------|
| 01 | monitoring-prometheus role | M | — |
| 02 | monitoring-alertmanager role | M | — |
| 03 | monitoring-loki role (Loki + Promtail) | M | — |
| 04 | monitoring-grafana role | M | — |
| 05 | monitoring-uptime-kuma role | S | — |
| 06 | monitoring-synthetic-probes role | M | — |
| 07 | Traefik dynamic config templates | S | 01-06 |
| 08 | Deploy + validation playbook + justfile | M | 01-07 |
| 09 | Grafana dashboards | M | 04 |
| 10 | Vault secrets handoff | S | — |

Stories 01-06 and 10 can run in parallel. Story 07 depends on 01-06. Story 08 depends on 01-07. Story 09 depends on 04.

## Constraints

- All ports, IPs, domains, network values must be variable-driven (`infra_*` variables)
- Use `community.docker.docker_container`, `docker_network`, `docker_volume`, `docker_image` — never `docker compose`
- Healthcheck durations must be string units ("30s", not 30)
- Handlers use `state: started` + `restart: true`, never `state: restarted`
- Image pulls use `source: pull`, never `source: build`
- Container names follow `localnet-monitoring-{component}` pattern
- Secrets in client vault only — agent provides docker run command, user performs vault edit
- Pre-existing uncommitted changes in the repo must not be touched
- `levonk/` is a git submodule — changes committed there, then parent ref updated
