# Research: treg (OpenRouter for Tools)

## Service Overview

**treg** is a credential-injecting proxy and tool registry — "OpenRouter, but for agent tools
instead of models." Point an agent at one base URL with one token and it can call 2,896+
catalogued endpoints across 60+ providers (SEO, backlinks, social, enrichment, ads, scraping),
priced per call from a cent, with no provider signup.

- **Source repo**: https://github.com/superdesigndev/treg
- **License**: Apache 2.0 with additional terms (free for self-hosting, no third-party hosted service)
- **Language**: Python 3.12+ (FastAPI + SQLModel + uvicorn)
- **Package**: `tools-registry` on PyPI (base = CLI only, `[server]` extra = FastAPI/DB/crypto)
- **Hosted reference**: treg.to (Render + managed Postgres)

## Architecture

Single FastAPI service: `python -m treg` honors `$PORT` (default 18790). Web assets ship in the
wheel — no separate frontend build. The `[server]` extra pulls FastAPI, SQLModel, SQLAlchemy,
asyncpg/aiosqlite, cryptography, pydantic-settings, pyyaml, stripe, mcp.

**Request flow for `/call`**: resolve tool (by URL host + longest base_url prefix, or by name) →
decrypt secret(s) → apply binding injectors → stream to upstream → fire-and-forget audit record.
The proxy does no business logic and never buffers the body.

**Key modules**: `proxy.py` (faithful streaming relay), `injectors.py` (auth shapes: env,
secret_file, oauth, cli_auth), `oauth.py` (token refresh + connect flow), `health.py` (credential
health probes), `api.py` (the API brain), `cli.py` (the `treg` CLI), `models.py` (SQLModel tables).

## Deployment Requirements

### Database
- **PostgreSQL (prod)**: `TREG_DATABASE_URL` with `postgresql+asyncpg://` driver. Config.py
  rewrites bare `postgres://` → `postgresql+asyncpg://` automatically.
- **SQLite (dev only)**: `sqlite+aiosqlite:///./treg.db` — docs warn SQLite is dev-only.
- **Decision**: PostgreSQL (prod) — separate `postgres:15-alpine` container, restoredrill backup.

### Secrets / Encryption
- `TREG_SECRET_KEY` — Fernet key for secrets-at-rest. **MUST be set for non-SQLite** (empty key
  + real DB → startup raises). Generate with `python -m treg keygen`.
- `TREG_SESSION_SECRET` — signs dashboard session cookie. Falls back to TREG_SECRET_KEY if empty,
  but should be a separate value in prod.
- `TREG_ADMIN_TOKEN` — cross-tenant super-admin bearer for `/admin/*` endpoints. Empty disables
  the env path (only `is_superadmin` users reach `/admin`).

### Auth / Sign-in
- **Decision**: Admin token only. No GitHub OAuth, no Google OAuth, no email OTP.
- `TREG_GITHUB_CLIENT_ID` / `TREG_SECRET` — empty (hides GitHub button)
- `TREG_RESEND_API_KEY` / `TREG_EMAIL_FROM` — empty (no email OTP)
- `TREG_EMAIL_DEV_MODE` — `false` (never in prod)

### Networking
- **Default port**: 18790 (`$PORT` env var)
- **Health endpoint**: `/meta` (used by Render health check)
- **Public URL**: `TREG_PUBLIC_URL` — drives OAuth callback, /meta, /llms.txt, /install.sh

### Traefik Routing
- **Decision**: Authelia SSO for web dashboard (`/app`, `/`); public for API/proxy paths.
- Public paths (bypass Authelia, use X-Treg-Token):
  - `/call/{...}` — proxy endpoint
  - `/mcp/` and `/mcp/v2/` — MCP front door
  - `/meta` — health check
  - `/api/` — REST API
  - `/llms.txt` — agent onboarding file
  - `/install.sh` — CLI install script
  - `/docs` — OpenAPI docs (optional, could be behind Authelia)
- Authelia-protected paths:
  - `/app` — dashboard
  - `/` — landing page (if not redirecting to /app)

### Container Image
- **No upstream Docker image exists.** treg ships as a Python package, not a Docker image.
- **Decision**: Locally-built multi-arch image (linux/amd64 + linux/arm64).
- Dockerfile: multi-stage build — builder stage installs `tools-registry[server]` via pip/uv,
  runtime stage copies the venv. Python 3.12 slim base.
- Build pipeline entry in `scripts/build-and-push-images.sh`.
- Image name: `localnet-ai-treg` (category: ai, since it's an agent tool registry)

### Environment Variables (for self-hosted instance)

| Variable | Value | Source |
|----------|-------|--------|
| `TREG_DATABASE_URL` | `postgresql+asyncpg://treg:{password}@treg-postgres:5432/treg` | vault |
| `TREG_SECRET_KEY` | Fernet key (generated) | vault |
| `TREG_SESSION_SECRET` | Session secret (generated) | vault |
| `TREG_ADMIN_TOKEN` | Admin token (generated) | vault |
| `TREG_PUBLIC_URL` | `https://treg.cno.levonk.com` | infra variable |
| `TREG_EMAIL_DEV_MODE` | `false` | hardcoded |
| `TREG_GITHUB_CLIENT_ID` | (empty) | not set |
| `TREG_RESEND_API_KEY` | (empty) | not set |
| `TREG_PLATFORM_PROVIDERS` | `""` (tier 4 off) | hardcoded |
| `TREG_OVERFLOW_MODE` | `off` | hardcoded |
| `PORT` | `18790` (container port) | infra variable |

### Vault Secrets Required

| Vault variable | Generation command |
|----------------|-------------------|
| `vault_treg_secret_key` | `python -m treg keygen` (Fernet key) |
| `vault_treg_session_secret` | `openssl rand -base64 32` |
| `vault_treg_admin_token` | `openssl rand -hex 32` |
| `vault_treg_postgres_password` | `openssl rand -hex 24` |

### Backup (PostgreSQL)
- Add to `restoredrill_databases` in client group_vars:
  ```yaml
  - name: "treg"
    container: "treg-postgres"
    db_name: "treg"
    db_user: "treg"
    db_password: "{{ vault_treg_postgres_password }}"
    min_tables: 1
    rpo_target: "25h"
  ```

## Infrastructure Variables (proposed)

### Ports (`shared/.../infrastructure/ports.yml`)
```yaml
# treg — Tool Registry (OpenRouter for agent tools)
infra_port_ai_treg_host: "18790"
infra_port_ai_treg_container: "18790"
```

### Domains (`shared/.../infrastructure/domains.yml`)
```yaml
# treg — Tool Registry
infra_domain_ai_treg: "treg.cno.{{ infra_domain_base }}"
infra_hostname_treg: "localnet-ai-treg"
```

### Storage (`shared/.../infrastructure/storage.yml`)
```yaml
# treg — Tool Registry
infra_storage_treg_data_volume: "localnet-treg-data-volume"
infra_storage_treg_config_dir: "{{ infra_storage_services_dir }}/treg"
```

### Networks
- Joins `traefik-network` (same as Verdaccio, Authelia, etc.)
- No new network needed.

## Service Catalog Entry (proposed)

```yaml
- name: "treg Tool Registry (cno)"
  container: "{{ infra_hostname_treg }}"
  machine: "oci-cloud-server"
  category: "ai"
  description: "OpenRouter for agent tools — credential-injecting proxy + tool registry"
  source_repo: "https://github.com/superdesigndev/treg"
  domains:
    - "infra_domain_ai_treg"
  ports:
    - host: "infra_port_ai_treg_host"
      container: "infra_port_ai_treg_container"
      label: "Web/API"
  traefik: true
  network: "traefik-network"
  health_endpoint: "/meta"
  pipeline: "none"
  pipeline_stage: "standalone"
  alert_labels:
    pipeline: "none"
    stage: "standalone"
    service: "treg"
```

## Deployment Target

- **Machine**: oci-cloud-server (cno network, ARM64 Linux)
- **Inventory**: `levonk/active/02-config/ansible/inventories/oci.yml`
- **Host group**: `cloud_servers`
- **Domain**: `treg.cno.levonk.com` (CNAME → `oci.tale-grouper.ts.net`)

## Role Naming

- **Role name**: `ai-treg` (functional-group prefix `ai-` for AI/agent services)
- **Container name**: `localnet-ai-treg`
- **Postgres container**: `treg-postgres`

## Key Design Decisions

1. **Locally-built image** (not upstream) — no Docker Hub image exists; treg is a Python package.
2. **PostgreSQL** (not SQLite) — prod-grade, matches treg's Render deployment, enables restoredrill backup.
3. **Admin token only** — minimal auth, no OAuth provider config needed, users created via admin.
4. **Authelia SSO for web UI, public API** — Verdaccio-style split: dashboard behind Authelia,
   API/proxy paths public with X-Treg-Token auth.
5. **Tier 4 platform providers OFF** — `TREG_PLATFORM_PROVIDERS=""` (no treg-owned provider keys;
   users register their own tools/keys).
6. **Overflow mode OFF** — `TREG_OVERFLOW_MODE=off` (no aggregator relay accounts).

## References

- README: https://github.com/superdesigndev/treg#readme
- Deploy docs: https://github.com/superdesigndev/treg/blob/main/docs/context/ops/deploy.md
- render.yaml: https://github.com/superdesigndev/treg/blob/main/render.yaml
- pyproject.toml: https://github.com/superdesigndev/treg/blob/main/pyproject.toml
- Self-host script: https://github.com/superdesigndev/treg/blob/main/src/treg/web/selfhost.sh
