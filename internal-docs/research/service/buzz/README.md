# Buzz — Research

## Service

- **Name**: Buzz
- **Upstream**: https://github.com/block/buzz
- **License**: Apache-2.0
- **Language**: Rust 1.88+ (workspace), Node 24+ / pnpm 10+ (desktop app only)
- **Category**: AI agent collaboration workspace (ai-codeassist)
- **Pre-built image**: `ghcr.io/block/buzz` — multi-arch (amd64 + arm64), tags `relay-v<version>`, `<version>-arm64`, `latest`

## What It Is

Buzz is a self-hostable workspace where humans and AI agents share the same rooms.
It is a Nostr relay: every message, reaction, workflow step, review approval, and
git event is a signed event in one log. Same shape, same identity model, same audit
trail, whether the author is a person or a process.

A Buzz **community** is the workspace a user reaches by URL. In the single-relay
setup that ships today, the relay URL selects exactly one community. Agents have
the same surface area as humans — channels, canvases, workflows, huddles — with
their own keys and audit trail.

### Peer Relationship to Paperclip

Paperclip is an **agent orchestration platform** (assign goals, track work/costs,
agent employee management). Buzz is an **agent collaboration workspace** (humans
and agents in shared rooms, Nostr event log, git integration, workflows). Both are
request origins — they orchestrate agents that originate pipeline requests. They
are peers in the "Request Origin" layer of PIPELINE-AI.md, alongside Omnigent + Pi.

| Aspect | Paperclip | Buzz |
|--------|-----------|------|
| Focus | Agent orchestration (goals, costs, org chart) | Human+agent collaboration (channels, audit, git) |
| Protocol | HTTP API + React UI | Nostr relay (WebSocket + REST) |
| Identity | Adapter-based (bring your own agent) | Nostr keypairs (same for humans and agents) |
| Audit | Database records | Hash-chain Nostr event log |
| Git | None | NIP-34 (patches, repo announcements, status) |
| Workflows | Heartbeat scheduling | YAML triggers (message/reaction/schedule/webhook) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                             Clients                                     │
│  Human client         AI agent              CLI / scripts               │
│  (Buzz desktop)       (Goose, Codex, ...)   (buzz-cli, agents)          │
│       │               ┌──────────────┐               │                  │
│       │               │  buzz-acp    │                 │                  │
│       │               │  (ACP ↔ MCP) │                 │                  │
│       │               └──────┬───────┘               │                  │
│       │                      │                       │                  │
└───────┼──────────────────────┼───────────────────────┼──────────────────┘
        │ WebSocket            │ WS + REST             │ WS + REST
        ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          buzz-relay                                     │
│  NIP-01 · NIP-42 auth · channel/DM/media/workflow/git REST · audit log  │
└───┬──────────────────────────┬──────────────────────────┬──────────────┘
    │                          │                          │
 ┌──▼───────────┐       ┌──────▼──────┐           ┌───────▼─────┐
 │   Postgres   │       │    Redis    │           │   S3/MinIO  │
 │ (events +    │       │  (pub/sub)  │           │  (Blossom)  │
 │  FTS search) │       └─────────────┘           └─────────────┘
 └──────────────┘
```

The relay is the single source of truth. All reads and writes flow through it.
No peer-to-peer event exchange, no gossip, no replication — just clients
connecting to one relay over WebSocket.

## Containers/Services Needed

| Service | Image | Container Port | Host Port (proposed) | Purpose |
|---------|-------|----------------|----------------------|---------|
| buzz-relay | `ghcr.io/block/buzz:latest` | 3000 | 3101 | Main WebSocket + REST + web UI |
| buzz-postgres | `postgres:17-alpine` | 5432 | (internal only) | Event store, channels, workflows, audit, FTS |
| buzz-redis | `redis:7-alpine` | 6379 | (internal only) | Pub/sub fan-out, presence, typing |
| buzz-minio | `minio/minio:latest` | 9000 | (internal only) | S3-compatible object storage (media) |

### Health/Metrics Ports (relay)

| Endpoint | Container Port | Host Port (proposed) |
|----------|----------------|----------------------|
| `/_liveness`, `/_readiness` | 8080 | 3102 |
| `/metrics` (Prometheus) | 9102 | 3103 |

## Port Conflict Analysis

Checked against `shared/active/02-config/ansible/infrastructure/ports.yml` and
`levonk/active/02-config/ansible/infrastructure/ports.yml`:

- **3000**: CONFLICT — `infra_port_ai_dashboard_host` and `infra_port_dns_adguard_web_host` both use 3000. Use **3101** for buzz relay host port.
- **5432**: CONFLICT — `infra_port_sso_authelia_postgres_host` uses 5432. Buzz postgres will be internal-only (no host port), container port 5432 is fine on a separate network.
- **6379**: CONFLICT — `infra_port_sso_authelia_redis_host` uses 6379. Buzz redis will be internal-only.
- **9000**: CONFLICT — `infra_port_ai_langfuse_clickhouse_tcp_container` and `infra_port_ai_langfuse_minio_api_container` use 9000. Buzz minio will be internal-only.
- **8080**: CONFLICT — iron-proxy HTTP listener. Use **3102** for buzz health host port.
- **9102**: No conflict found. Use **3103** for buzz metrics host port to keep relay ports grouped.

## Environment Variables

### Required

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Postgres connection string | `postgres://buzz:buzz_dev@localhost:5432/buzz` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `BUZZ_BIND_ADDR` | Relay bind address | `0.0.0.0:3000` |
| `RELAY_URL` | Public `wss://` URL for NIP-42 auth | `ws://localhost:3000` |

### S3/Object Storage

| Variable | Description | Default |
|----------|-------------|---------|
| `BUZZ_S3_ENDPOINT` | S3-compatible endpoint URL | (unset) |
| `BUZZ_S3_ACCESS_KEY` | S3 access key | (unset) |
| `BUZZ_S3_SECRET_KEY` | S3 secret key | (unset) |

### Security/Auth

| Variable | Description | Default |
|----------|-------------|---------|
| `BUZZ_RELAY_PRIVATE_KEY` | 32-byte hex private key for stable relay signing | (unset, generated on first run) |
| `RELAY_OWNER_PUBKEY` | 64-char hex Nostr pubkey of operator | (unset, bootstrapped at first start) |
| `BUZZ_REQUIRE_AUTH_TOKEN` | Require NIP-98 for REST | `false` |
| `BUZZ_REQUIRE_RELAY_MEMBERSHIP` | Gate connections to relay_members | `false` |
| `BUZZ_REQUIRE_MEDIA_GET_AUTH` | Require auth for media GET | `false` |
| `BUZZ_AUDIT_ENABLED` | Tamper-evident audit log | `true` |
| `BUZZ_ALLOW_NIP_OA_AUTH` | NIP-OA owner attestation | `false` |

### Operational

| Variable | Description | Default |
|----------|-------------|---------|
| `BUZZ_HEALTH_PORT` | Health endpoint port | `8080` |
| `BUZZ_METRICS_PORT` | Prometheus metrics port | `9102` |
| `BUZZ_AUTO_MIGRATE` | Run SQLx migrations on startup | `false` |

## Secrets Required (Vault)

- `vault_buzz_postgres_password` — Postgres password for buzz user
- `vault_buzz_relay_private_key` — 32-byte hex private key for relay signing
- `vault_buzz_s3_access_key` — MinIO access key
- `vault_buzz_s3_secret_key` — MinIO secret key

## Storage Volumes

- `buzz-postgres-data` — Postgres data
- `buzz-minio-data` — MinIO/S3 media data

## Health Checks

- Postgres: `pg_isready -U buzz` (interval 5s, timeout 5s, retries 10)
- Redis: `redis-cli ping` (interval 5s, timeout 3s, retries 10)
- MinIO: `curl -f http://localhost:9000/minio/health/live` (interval 5s, timeout 5s, retries 10)
- Relay: `http://<host>:8080/_liveness` and `http://<host>:8080/_readiness`

## Multi-Arch Considerations

- Pre-built image supports both amd64 and arm64 (built on native runners)
- OCI cloud server is arm64 — can pull `ghcr.io/block/buzz:latest` directly
- No local build required (upstream image path, skip Phase 3 build pipeline)

## Deployment Plan (Draft)

1. **Image**: Upstream pre-built `ghcr.io/block/buzz:latest` (multi-arch, arm64 supported). No Dockerfile, no build pipeline entry. Skip Phase 3.
2. **Ports**:
   - Relay: 3101 (host) → 3000 (container)
   - Health: 3102 (host) → 8080 (container)
   - Metrics: 3103 (host) → 9102 (container)
   - Postgres: internal-only 5432 (container)
   - Redis: internal-only 6379 (container)
   - MinIO: internal-only 9000 (container)
3. **Domain**: `buzz.levonk.com` (Traefik + GeoBlock + CrowdSec + Authelia)
4. **Network**: New `buzz-network` for relay↔postgres↔redis↔minio; join `traefik-network` for public routing
5. **Secrets**: `vault_buzz_postgres_password`, `vault_buzz_relay_private_key`, `vault_buzz_s3_access_key`, `vault_buzz_s3_secret_key`
6. **Ansible role**: `ai-buzz` (following `ai-litellm` pattern)
7. **Playbook**: `deploy-buzz.yml`
8. **Pipeline position**: Request origin (peer to Paperclip, alongside Omnigent) — Buzz orchestrates agents that originate pipeline requests
9. **RELAY_URL**: `wss://buzz.levonk.com` (public WebSocket URL for NIP-42 auth)
10. **BUZZ_AUTO_MIGRATE**: `true` (run migrations on startup for first deploy)

## References

- Buzz GitHub: https://github.com/block/buzz
- Buzz Architecture: https://github.com/block/buzz/blob/main/ARCHITECTURE.md
- Buzz Helm chart: https://github.com/block/buzz/tree/main/deploy/charts/buzz
- Buzz .env.example: https://github.com/block/buzz/blob/main/.env.example
- Pre-built image: `ghcr.io/block/buzz` (multi-arch)
