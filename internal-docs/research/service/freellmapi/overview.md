# FreeLLMAPI — Service Research

## Summary

**FreeLLMAPI** aggregates free tiers from 34+ LLM providers behind a single
OpenAI-compatible `/v1` endpoint. A router picks the best available model for
each request, falls over to the next provider on 429/5xx, and tracks per-key
usage to stay under every free-tier cap. Keys are AES-256-GCM encrypted in
SQLite.

- **Source repo**: https://github.com/tashfeenahmed/freellmapi
- **License**: MIT
- **Stars**: 25.8k, 726 commits, active development
- **Product page**: https://freellmapi.co

## What It Does

- Exposes every OpenAI-style surface: `/v1/chat/completions`, `/v1/responses`,
  `/v1/completions`, `/v1/images/generations`, `/v1/videos/generations`,
  `/v1/audio/speech`, `/v1/audio/transcriptions`, `/v1/embeddings`, `/v1/models`
- Anthropic Messages API (`/v1/messages`) — Claude Code compatible
- Native Gemini surface (`/v1beta`) and Ollama emulation
- Smart routing with 6 strategies, automatic fallover with cooldowns
- Self-updating model catalog from signed feed (freellmapi.co)
- Admin dashboard (React UI) with analytics, playground, key management
- MCP server for agent introspection
- ~40 MB RSS at idle, runs on Node 20+

## Deployment Details

### Image

- **Upstream image**: `ghcr.io/tashfeenahmed/freellmapi:latest`
- **Multi-arch**: yes (ARM64 + AMD64) — works on OCI ARM64 cloud server
- **Decision**: upstream image, no local build needed (skip Phase 3 of
  implementation guide)

### Ports

- **Container port**: 3001 (default, hardcoded in image)
- **Host port**: 3003 (free in both shared and levonk port allocations)
- **Health endpoint**: `GET /api/ping` returns 200

### Volumes

- `freellmapi-data` → `/app/server/data` (SQLite database, encrypted keys,
  encryption key file, logs)
- Stateful: yes — SQLite database with provider keys, analytics, settings

### Environment Variables (key ones)

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `ENCRYPTION_KEY` | yes (prod) | auto-generated (dev) | 64-char hex, AES-256-GCM for provider keys |
| `PORT` | no | 3001 | Container listen port |
| `NODE_ENV` | no | production | |
| `HOST_BIND` | no | 127.0.0.1 | Docker host interface — NOT needed when behind Traefik |
| `TRUST_PROXY` | no | false | Set to `1` behind Traefik (single reverse proxy hop) |
| `PROXY_RATE_LIMIT_RPM` | no | 120 | Per-client-IP rate limit for /v1 |
| `REQUEST_ANALYTICS_RETENTION_DAYS` | no | 90 | Analytics retention |

### Secrets Required

| Vault variable | Purpose | Generation |
|----------------|---------|-------------|
| `vault_ai_freellmapi_encryption_key` | AES-256-GCM encryption for provider API keys stored in SQLite | `openssl rand -hex 32` (64 hex chars) |

### Health Check

```yaml
healthcheck:
  test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3001/api/ping').then((res) => { if (!res.ok) process.exit(1); }).catch(() => process.exit(1));"]
  interval: 30s
  timeout: 5s
  start_period: 15s
  retries: 3
```

### Docker Compose (reference, from upstream)

```yaml
services:
  freellmapi:
    image: ghcr.io/tashfeenahmed/freellmapi:latest
    env_file:
      - .env
    environment:
      NODE_ENV: production
      PORT: 3001
    ports:
      - "${HOST_BIND:-127.0.0.1}:${PORT:-3001}:3001"
    volumes:
      - freellmapi-data:/app/server/data
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:3001/api/ping').then((res) => { if (!res.ok) process.exit(1); }).catch(() => process.exit(1));"]
      interval: 30s
      timeout: 5s
      start_period: 15s
      retries: 3
```

## Infrahub Integration Plan

### Role

- **Name**: `ai-freellmapi` (follows `ai-` prefix convention for AI services)
- **Category**: `ai`
- **Target machine**: `oci-cloud-server`
- **Network**: `traefik-network` (for Traefik routing)
- **Domain**: `freellmapi.levonk.com` (CNAME → `oci.tale-grouper.ts.net`)

### Infrastructure Variables

| File | Variable | Value |
|------|----------|-------|
| `ports.yml` (shared) | `infra_port_ai_freellmapi_host` | `"3003"` |
| `ports.yml` (shared) | `infra_port_ai_freellmapi_container` | `"3001"` |
| `domains.yml` (shared) | `infra_domain_ai_freellmapi` | `"freellmapi.{{ infra_domain_base }}"` |
| `storage.yml` (shared) | `infra_storage_ai_freellmapi_volume` | `"localnet-freellmapi-data-volume"` |

### Traefik Routing

- Public domain: `freellmapi.levonk.com`
- Behind Authelia SSO (dashboard is admin-only, API endpoints need auth)
- `TRUST_PROXY=1` (single Traefik reverse proxy hop)

### Backup

- SQLite database at `/app/server/data/freellmapi.db`
- Encrypted provider keys — cannot be regenerated from Ansible config
- Use file-based backup: `rsync`/`tar` of the data volume to
  `/opt/localnet/backup/freellmapi/`
- FreeLLMAPI also supports `FREEAPI_DB_BACKUP_PATH` for built-in encrypted
  backups

### Monitoring

- Health endpoint: `/api/ping`
- No native Prometheus metrics endpoint (no `/metrics`)
- Pipeline: `ai`, stage: `gateway` (sits alongside LiteLLM as an AI gateway)

### Comparison with LiteLLM (existing AI gateway)

| Aspect | LiteLLM | FreeLLMAPI |
|--------|---------|------------|
| Focus | Enterprise proxy, spend tracking, virtual keys | Free-tier aggregation, automatic fallover |
| Provider keys | Stored in PostgreSQL | Encrypted in SQLite (AES-256-GCM) |
| Catalog updates | Manual config | Self-updating from signed feed |
| Dashboard | Basic admin UI | Full React dashboard with analytics |
| Anthropic API | Via proxy | Native `/v1/messages` |
| Resource usage | Heavy (Postgres + Redis) | Light (~40 MB RSS) |

**Coexistence**: FreeLLMAPI and LiteLLM serve different purposes — LiteLLM is
the enterprise gateway with spend tracking and virtual keys, FreeLLMAPI is the
free-tier aggregator. They can coexist on the same host on different ports and
domains.

## First-Run Setup

After deployment, the first account must be created through the dashboard:
1. Open `https://freellmapi.levonk.com` in a browser
2. Create the first account (email + password)
3. Add provider API keys on the Keys page
4. Grab the unified `freellmapi-...` API key from the Keys page header
5. Point OpenAI clients at `https://freellmapi.levonk.com/v1` with that key

**Note**: If the server is reachable from other devices (which it will be via
Traefik), the first account creation requires a one-time setup code printed in
the server logs at startup. This is a security measure to prevent strangers
from claiming a freshly exposed install.
