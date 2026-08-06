# n8n Hosting — Deployment Research

Source: https://github.com/n8n-io/n8n-hosting
Date: 2026-08-05

## Official Deployment Options

### Docker Compose Configurations
- **withPostgres** — n8n + PostgreSQL (basic setup)
- **withPostgresAndWorker** — n8n + PostgreSQL + Redis + worker (queue mode)
- **subfolderWithSSL** — n8n behind SSL reverse proxy in subfolder
- **docker-caddy** — n8n with Caddy reverse proxy

### Kubernetes
- Helm Chart (OCI: `oci://ghcr.io/n8n-io/n8n-helm-chart/n8n`)
- Raw manifests for AWS/Azure/GCP

## Required Services and Default Ports

| Service | Default Port | Notes |
|---------|-------------|-------|
| PostgreSQL | 5432 | PostgreSQL 16 recommended |
| Redis/Valkey | 6379 | Queue mode only; Valkey is drop-in compatible |
| n8n Application | 5678 | Web UI + API |
| n8n Task Broker | 5679 | Internal, for external task runners |

## Environment Variables

### Core (Database)
```bash
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=secure_password
```

### Encryption (CRITICAL — never change after initial setup)
```bash
N8N_ENCRYPTION_KEY=<openssl rand -base64 32>
```

### Host/URL
```bash
N8N_HOST=n8n.example.com
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_WEBHOOK_URL=https://n8n.example.com/
N8N_PROXY_HOPS=1  # behind reverse proxy
```

### Queue Mode
```bash
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_BULL_REDIS_PASSWORD=redis_password
QUEUE_HEALTH_CHECK_ACTIVE=true
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
```

### Task Runners (required for n8n 2.0+)
```bash
N8N_RUNNERS_MODE=external
N8N_RUNNERS_AUTH_TOKEN=<openssl rand -base64 32>
N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
```

### Production / Metrics
```bash
NODE_ENV=production
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_SECURE_COOKIE=true
N8N_METRICS=true
N8N_ENDPOINT_HEALTH=health/live
```

## Docker Images

| Image | Registry | Tags |
|-------|----------|------|
| n8n main | `docker.n8n.io/n8nio/n8n` | `latest`, `stable`, `next`, `X.Y.Z` |
| n8n runners | `docker.n8n.io/n8nio/runners` | must match n8n version exactly |
| PostgreSQL | `postgres:16` | |
| Valkey | `valkey/valkey:latest` | Redis-compatible drop-in |

## Healthcheck Endpoints

- `/healthz` (or custom via `N8N_ENDPOINT_HEALTH`) — basic reachability
- `/healthz/readiness` — full readiness (DB connected + migrated)
- `/metrics` — Prometheus metrics (enable with `N8N_METRICS=true`)

## Queue Mode Architecture (withPostgresAndWorker)

Containers needed:
1. **postgres** — database
2. **redis/valkey** — queue backend
3. **n8n** (main) — web UI + API + webhook receiver
4. **n8n-runner** — external task runner for main
5. **n8n-worker** — queue worker (executes workflows)
6. **n8n-worker-runner** — external task runner for worker

## PostgreSQL init-data.sh

```bash
#!/bin/bash
set -e;
if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
    GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
EOSQL
fi
```

## Volumes

| Volume | Mount Path | Contents |
|--------|-----------|----------|
| n8n_data | `/home/node/.n8n` | Encryption key, settings, logs |
| postgres_data | `/var/lib/postgresql/data` | Database |
| redis_data | `/data` | Queue persistence (AOF) |
