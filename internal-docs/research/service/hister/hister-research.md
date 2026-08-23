# Hister — Service Research

## Overview

**Hister** is an open-source, self-hosted search engine for your browsing history,
documents, and personal content. It is the successor to SearXNG's personal search
concept, built by asciimoo (the original SearXNG author). AGPLv3 licensed.

- **Source repo**: https://github.com/asciimoo/hister
- **Official docs**: https://hister.org/docs
- **Demo**: https://demo.hister.org/
- **License**: AGPLv3

## Docker Deployment

Official Docker images are available for AMD64 and ARM64:

- **Image**: `ghcr.io/asciimoo/hister:latest`
- **Root image**: `ghcr.io/asciimoo/hister:latest-root` (if root needed)
- **Runs as**: non-root user (UID/GID 1000) by default
- **Container port**: 4433
- **Data volume**: `/hister/data` (stores index, rules, secret key, SQLite DB)

### Docker Compose (reference from docs)

```yaml
services:
  hister:
    image: ghcr.io/asciimoo/hister:latest
    container_name: hister
    user: '1000:1000'
    restart: unless-stopped
    environment:
      - HISTER__SERVER__ADDRESS=0.0.0.0:4433
      - HISTER__SERVER__BASE_URL=https://hister.example.com
    volumes:
      - ./data:/hister/data
    ports:
      - 4433:4433
```

### Behind Reverse Proxy (Traefik)

Set `HISTER__SERVER__BASE_URL` to the public domain. The container listens on
`0.0.0.0:4433` and Traefik routes to it.

## Configuration

Hister is configured via env vars using the `HISTER__<SECTION>__<KEY>` convention,
or via a YAML config file. For containerized deployments, env vars are recommended.

### Key Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `HISTER__SERVER__ADDRESS` | Listen address | `127.0.0.1:4433` |
| `HISTER__SERVER__BASE_URL` | Public URL (required behind proxy) | derived from address |
| `HISTER__APP__ACCESS_TOKEN` | API access token for auth | (none) |
| `HISTER__APP__PUBLIC` | Allow unauthenticated search | `false` |
| `HISTER__APP__USER_HANDLING` | Enable multi-user mode | `false` |
| `HISTER__APP__TITLE` | Web UI title | `Hister` |
| `HISTER__APP__LOG_LEVEL` | Log verbosity | `info` |
| `HISTER__SERVER__DATABASE` | SQLite filename or PostgreSQL DSN | `db.sqlite3` |
| `HISTER_DATA_DIR` | Override app.directory | (container default) |

### Authentication Modes

1. **Access token** (`app.access_token`): Simple token auth. Clients send
   `X-Access-Token` header or `Authorization: Bearer TOKEN`. Web UI prompts
   for token and exchanges it for an opaque session.
2. **Public mode** (`app.public: true`): Anonymous users can search public
   documents. Write access still requires token. Requires `access_token` or
   `user_handling` to be set.
3. **User handling** (`app.user_handling: true`): Multi-user mode with
   OAuth/OIDC support.
4. **OAuth** (`server.oauth`): Optional OAuth/OIDC provider configs.

### Database Backends

- **SQLite** (default): `server.database: db.sqlite3` — stored in data volume
- **PostgreSQL**: `server.database: "host=... user=... password=... dbname=... port=... sslmode=disable"`

For this deployment, SQLite is sufficient (single-user, personal search).

### Semantic Search (Optional)

Hister can augment keyword search with vector similarity search using an
OpenAI-compatible embeddings endpoint (Ollama, llama.cpp, OpenAI API).
Disabled by default — not needed for initial deployment.

## Deployment Decisions for Levonk

### Target Machine

- **Machine**: `dtop202311` (Windows Docker Desktop, X86)
- **Region**: `nl` (network local)
- **Inventory**: `levonk/active/02-config/ansible/inventories/windows-docker.yml`
- **Docker access**: Windows named pipe (`npipe:////./pipe/docker_engine`)
  via SSH-tunneled Docker CLI (`DOCKER_HOST: ssh://...`)

### Domain

- **Domain**: `hister.nl.levonk.com`
- **Pattern**: Subdomain under `nl.levonk.com` zone (matching `start.nl.levonk.com`,
  `npmjs.nl.levonk.com`, etc.)
- **DNS**: CNAME → `dtop202311.tale-grouper.ts.net` (Tailscale FQDN)

### Authentication

- **Auth**: Authelia SSO (forward-auth middleware in Traefik)
- Hister's own `access_token` auth is not needed since Authelia gates access
  at the Traefik layer. Hister runs in single-user mode (no `user_handling`,
  no `access_token`).

### Port Allocation

- **Port**: 4433 (host and container)
- **Status**: Free — no conflicts in shared or client port schemas

### Image

- **Upstream image**: `ghcr.io/asciimoo/hister:latest` (no local build needed)
- **Architecture**: AMD64 (dtop202311 is X86) — image supports AMD64

### Storage

- **Data volume**: `localnet-hister-data-volume` (Docker named volume)
- **Container path**: `/hister/data`
- **No config file needed** — all configuration via env vars

### Network

- **Primary network**: `traefik-windows-network` (for Traefik routing)
- The container joins the traefik-windows network so Traefik can route to it

### Secrets

- **No secrets required** — Authelia handles auth at the proxy layer
- Hister auto-generates its own secret key in the data directory on first run

## Architecture Context

```
Internet → Cloudflare DNS → dtop202311 (Tailscale)
  → Traefik (Windows) → Authelia forward-auth (via OCI Tailscale)
  → Hister container (port 4433)
```

The `proxy_traefik_windows` role manages Traefik on dtop202311. nl services
follow one of two patterns:

1. **Simple services** (homepage-nl, trala-nl): Container deployed directly
   in the `proxy_traefik_windows` role tasks
2. **Complex services** (verdaccio-nl): Separate role with
   `deploy-windows.yml` using the SSH-tunneled Docker CLI pattern

Hister is a single-container service with no secrets and no config file,
so it could follow either pattern. The implementation guide (Phase 5)
recommends creating a separate role, so we'll create `search-hister` with
a Windows deployment task file.

## Implementation Plan (for execute-upsert)

### Files to Create/Modify

1. **Shared infrastructure schemas** (Phase 1):
   - `shared/active/02-config/ansible/infrastructure/ports.yml` — add port 4433
   - `shared/active/02-config/ansible/infrastructure/domains.yml` — add domain var
   - `shared/active/02-config/ansible/infrastructure/storage.yml` — add volume var

2. **Client infrastructure values** (Phase 2):
   - `levonk/active/02-config/ansible/infrastructure/domains.yml` — add `hister.nl.levonk.com`
   - `levonk/active/02-config/ansible/inventories/group_vars/all.yml` — add DNS CNAME

3. **Service catalog** (Phase 2f):
   - `shared/active/02-config/ansible/infrastructure/services.yml` — add Hister entry

4. **Ansible role** (Phase 5):
   - `shared/active/02-config/ansible/roles/search-hister/` — new role
   - `defaults/main.yml`, `tasks/main.yml`, `tasks/deploy-windows.yml`,
     `handlers/main.yml`, `meta/main.yml`, `README.md`

5. **Traefik routing** (Phase 6):
   - `shared/active/02-config/ansible/roles/proxy_traefik_windows/templates/dynamic/hister-nl.yml.j2`
   - `shared/active/02-config/ansible/roles/proxy_traefik_windows/tasks/main.yml` — add render + copy + network connect tasks
   - `shared/active/02-config/ansible/roles/proxy_traefik_windows/defaults/main.yml` — add hister defaults

6. **Playbook** (Phase 8):
   - Add `search-hister` role to the Windows Docker deployment playbook
     (or the proxy-web-stack playbook that targets windows_docker_hosts)

7. **Service catalog regeneration** (Phase 2g):
   - Run `just generate-service-catalog-all`
