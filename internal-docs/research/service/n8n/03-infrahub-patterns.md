# Infrahub Patterns for n8n Deployment

Date: 2026-08-05

## Role Structure

```
roles/ai-n8n/
├── defaults/main.yml    # All variables with sensible defaults
├── tasks/main.yml       # Deployment tasks (validate → volumes → networks → pull → postgres → valkey → n8n → runners → worker → wait → report)
├── handlers/main.yml    # Container restart handlers
└── templates/           # Jinja2 templates (prometheus.yml, grafana provisioning, init-data.sh)
```

## Variable Naming

- `{service}_enabled`, `{service}_container_name`, `{service}_image`
- `{service}_postgres_*` for postgres-specific
- `{service}_valkey_*` for valkey-specific
- Ports: `{{ infra_port_{category}_{service}_{context}_{host|container} }}`
- Domain: `{{ infra_domain_{category}_{service} }}`
- Network: `{{ infra_network_{category}_{service}_network_name }}`
- Secrets: `{{ vault_{service}_{secret} | default('') }}`

## Free Ports (verified against existing allocations)

| Service | Host Port | Container Port |
|---------|-----------|----------------|
| n8n Web UI | 3106 | 5678 |
| n8n Postgres | 5437 | 5432 |
| n8n Valkey | 6380 | 6379 |
| n8n Prometheus | 3107 | 9090 |
| n8n Grafana | 3108 | 3000 |

## Domain

`n8n.levonk.com` (CNAME → `oci.tale-grouper.ts.net`)

## Network

`n8n-network` — all n8n containers on same network for service discovery.
Prometheus needs to reach n8n container by name, so observability containers join `n8n-network` too.

## Deploy Playbook Pattern

Single-host deployment (n8n + Traefik both on OCI):
- Phase 1: Deploy all containers on `cloud_servers`
- Phase 2: Deploy Traefik dynamic config for `n8n.levonk.com` on `cloud_servers`

## Vault Secrets Needed

```yaml
vault_n8n_encryption_key: "<openssl rand -base64 32>"
vault_n8n_runners_auth_token: "<openssl rand -base64 32>"
vault_n8n_postgres_admin_password: "<openssl rand -hex 32>"
vault_n8n_postgres_user_password: "<openssl rand -hex 32>"
vault_n8n_valkey_password: "<openssl rand -hex 32>"
vault_n8n_grafana_admin_password: "<openssl rand -hex 16>"
```

## Container Architecture (Queue Mode + Observability)

1. **n8n-postgres** — PostgreSQL 16
2. **n8n-valkey** — Valkey (Redis-compatible)
3. **n8n** — main app (web UI + API + webhooks)
4. **n8n-runner** — external task runner for main
5. **n8n-worker** — queue worker
6. **n8n-worker-runner** — external task runner for worker
7. **n8n-prometheus** — metrics scraper
8. **n8n-grafana** — dashboards (behind Traefik)

## Traefik Routing

- `n8n.levonk.com` → n8n:5678 (main app, behind Authelia)
- `n8n-grafana.levonk.com` → n8n-grafana:3000 (dashboards, behind Authelia)
