# treg — Tool Registry (OpenRouter for agent tools)

Self-hosted instance of [treg](https://github.com/superdesigndev/treg), the credential-injecting
proxy and tool registry for AI agents. Deployed on the cno (OCI cloud server) network.

## What it does

treg is "OpenRouter, but for agent tools instead of models." Point an agent at one base URL
with one token and it can call catalogued endpoints across 60+ providers (SEO, backlinks,
social, enrichment, ads, scraping), priced per call, with no provider signup.

## Deployment

- **Machine**: oci-cloud-server (cno, ARM64 Linux)
- **Image**: `localnet-ai-treg` (locally-built, multi-arch amd64 + arm64)
- **Database**: PostgreSQL 15 (separate `postgres:15-alpine` container)
- **Domain**: `treg.cno.levonk.com` (Traefik, Authelia SSO for web UI)
- **Port**: 18790 (container + host)
- **Health**: `/meta` endpoint

## Traefik routing

- **Web UI** (`/app`, `/`): behind Authelia SSO middleware
- **API/proxy paths** (`/call/`, `/mcp/`, `/meta`, `/api/`, `/llms.txt`, `/install.sh`):
  public, authenticated via `X-Treg-Token` header (no Authelia)

## Secrets (vault)

All secrets are in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`:

- `vault_treg_secret_key` — Fernet key for secrets-at-rest (generate: `python -m treg keygen`)
- `vault_treg_session_secret` — Dashboard session cookie signing key
- `vault_treg_admin_token` — Super-admin bearer token
- `vault_treg_postgres_password` — PostgreSQL database password

## Backup

PostgreSQL database is backed up via `restoredrill_databases` in client group_vars:

```yaml
restoredrill_databases:
  - name: "treg"
    container: "treg-postgres"
    db_name: "treg"
    db_user: "treg"
    db_password: "{{ vault_treg_postgres_password }}"
    min_tables: 1
    rpo_target: "25h"
```

## Build

```bash
devbox run -- just docker-build-push localnet-ai-treg
```

## Monitoring

- **Health endpoint**: `/meta`
- **Pipeline**: none (standalone service)
- **Alert labels**: `pipeline=none, stage=standalone, service=treg`
- **Uptime**: Add to `monitoring_uptime_kuma_monitors` when the monitoring stack is deployed

## Configuration

Auth: Admin token only (no GitHub OAuth, no email OTP). Users created via admin panel.
Tier 4 platform providers OFF (`TREG_PLATFORM_PROVIDERS=""`). Overflow mode OFF.
