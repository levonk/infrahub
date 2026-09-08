# treg — Tool Registry (OpenRouter for agent tools)

Self-hosted instance of [treg](https://github.com/superdesigndev/treg), deployed on the
cno (OCI cloud server) network at `treg.cno.levonk.com`.

## What it does

treg is a credential-injecting proxy and tool registry — "OpenRouter, but for agent tools
instead of models." Point an agent at one base URL with one token and it can call catalogued
endpoints across 60+ providers (SEO, backlinks, social, enrichment, ads, scraping), priced
per call, with no provider signup.

## Deployment

- **Machine**: oci-cloud-server (cno, ARM64 Linux)
- **Image**: `localnet-ai-treg` (locally-built, multi-arch amd64 + arm64)
- **Database**: PostgreSQL (separate `postgres:15-alpine` container)
- **Domain**: `treg.cno.levonk.com` (Traefik, Authelia SSO for web UI)
- **Port**: 18790 (container + host)
- **Health**: `/meta` endpoint

## Traefik routing

- **Web UI** (`/app`, `/`): behind Authelia SSO
- **API/proxy paths** (`/call/`, `/mcp/`, `/meta`, `/api/`, `/llms.txt`, `/install.sh`):
  public, authenticated via `X-Treg-Token` header

## Secrets (vault)

All secrets are in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`:

- `vault_treg_secret_key` — Fernet key for secrets-at-rest
- `vault_treg_session_secret` — Dashboard session cookie signing key
- `vault_treg_admin_token` — Super-admin bearer token
- `vault_treg_postgres_password` — PostgreSQL database password

## Backup

PostgreSQL database is backed up via `restoredrill_databases` in client group_vars.

## Build

```bash
devbox run -- just docker-build-push localnet-ai-treg
```

## Monitoring

- **Health endpoint**: `/meta`
- **Pipeline**: none (standalone service)
- **Alert labels**: `pipeline=none, stage=standalone, service=treg`
