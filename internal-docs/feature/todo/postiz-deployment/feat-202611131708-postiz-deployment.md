---
# Product Requirements Document (PRD)

feature_slug: postiz-deployment
created: 2026-11-13
completed:
last-activity: 2026-11-13
status: todo
tech_context:
  deploy_tool: ansible           # ssh-tunneled Docker CLI (Windows target)
  image: ghcr.io/gitroomhq/postiz-app  # upstream all-in-one (amd64+arm64)
  db: postgres                   # postgres:17-alpine (app) + postgres:16-alpine (temporal)
  queue: redis                   # redis:7.2-alpine
  orchestrator: temporalio/auto-setup:1.28.1
  target_region: nl              # dtop202311, Windows Docker Desktop, amd64
  never_use: [docker compose, community.docker on Windows, hardcoded IPs/ports]
---

# Product Requirements Document (PRD)

## Introduction / Overview

- **Feature name:** Postiz nl-region deployment into infrahub
- **Summary:** Deploy Postiz (https://github.com/gitroomhq/postiz-app — a
  self-hosted social-media scheduling platform, Buffer/Hootsuite
  alternative) onto `dtop202311` (Windows Docker Desktop, the `nl` region)
  using the established ssh-tunneled Docker CLI Ansible pattern
  (ai-acrm/search-hister precedent), Windows Traefik routing, Cloudflare DNS
  record, and vault-managed secrets.
- **Context:**
  - Upstream image `ghcr.io/gitroomhq/postiz-app` is all-in-one: Next.js
    frontend + NestJS backend + Temporal worker, serving UI on `/`, API on
    `/api/*`, uploads on `/uploads/*`, OAuth callbacks on
    `/integrations/*` — all on container port 5000. No local build needed.
  - Required stack (reference `gitroomhq/postiz-docker-compose`): postiz
    app + dedicated Postgres + Redis + Temporal (`auto-setup`) + Temporal's
    own Postgres. Elasticsearch is dropped (`ENABLE_ES=false`, saves ~1 GB
    RAM); Temporal UI/admin-tools/spotlight skipped.
  - Research: `internal-docs/research/service/postiz/` (committed
    `a3de2c6`).

## Goals

- Six containers on dtop202311 — `localnet-postiz`,
  `localnet-postiz-postgres`, `localnet-postiz-redis`,
  `localnet-postiz-temporal`, `localnet-postiz-temporal-postgres` — on
  `postiz-network` + `postiz-temporal-network` (postiz on both), app also
  joined to `traefik-windows-network`.
- `postiz.nl.levonk.com` serves the app over Traefik TLS **without**
  Authelia (app has own auth + social-OAuth flows; SSO would double-login
  and complicate provider callbacks).
- Temporal `dynamicconfig` delivered via a named volume populated by a
  one-shot init container (no Windows host bind-mounts).
- All ports/domains/secrets via `infra_*` / `vault_*` variables.
- Service catalog entries + regenerated catalogs; `just
  ansible-deploy-postiz` recipe.

## User Stories

- **As the operator**, I run `just ansible-deploy-postiz` and get a
  working TLS-terminated Postiz on the nl host with secrets from the
  vault.
- **As the operator**, I open `https://postiz.nl.levonk.com` from any
  tailnet device, register the first account, connect social channels,
  and schedule posts.
- **As a social provider**, OAuth callbacks reach
  `https://postiz.nl.levonk.com/integrations/social/{provider}` from the
  operator's tailnet-connected browser.

## Functional Requirements

1. **Infrastructure variables** — `infra_port_tools_postiz_{host,container}`
   (4539/5000), `infra_port_tools_postiz_postgres_{host,container}`
   (5441/5432), `infra_port_tools_postiz_temporal_postgres_{host,container}`
   (5442/5432), `infra_domain_tools_postiz`, `infra_hostname_postiz{,_postgres,_redis,_temporal,_temporal_postgres}`,
   `infra_network_tools_postiz_{network_name,temporal_network_name}`,
   `infra_storage_postiz_*` volumes, `infra_value_postiz_*` fallbacks.
2. **Role `tools-postiz`** —
   `shared/active/02-config/ansible/roles/tools-postiz/` (nl-only; same
   `group_names` dispatch shape as ai-acrm):
   validate vars → ensure networks → ensure volumes → populate
   dynamicconfig volume via one-shot container → pull images → deploy
   `postiz-postgres` + `temporal-postgres` + `redis` → wait healthy →
   deploy `temporal` (auto-setup, `ENABLE_ES=false`) → wait healthy →
   deploy `postiz` app → connect to `traefik-windows-network` → wait
   healthy → status report. All Docker ops via `DOCKER_HOST: ssh://…` +
   `delegate_to: localhost`; `no_log` on secret-bearing tasks.
3. **Traefik (Windows)** — `postiz-nl.yml.j2`: HTTP→HTTPS redirect +
   `websecure` router `Host(postiz.nl.levonk.com)` →
   `http://localnet-postiz:5000`, no Authelia middleware; register
   render/copy/network-connect tasks + `proxy_traefik_windows_postiz_*`
   vars + cert SAN entry in `proxy_traefik_windows`.
4. **DNS** — `postiz.nl.levonk.com` CNAME →
   `dtop202311.tale-grouper.ts.net` in `configure-cloudflare-dns.yml`'s
   canonical `cloudflare_dns_records` list **and** a `dns`-tagged Phase-0
   play in `deploy-postiz.yml`.
5. **Secrets** — `vault_postiz_jwt_secret`,
   `vault_postiz_postgres_password`,
   `vault_postiz_temporal_postgres_password`,
   `vault_postiz_encryption_key` via user vault handoff.
6. **Playbook + recipes** — `playbooks/deploy-postiz.yml` (Phase 0 DNS →
   Phase 1 tools-postiz on `windows_docker_hosts` → Phase 2
   `proxy_traefik_windows`), `just ansible-deploy-postiz` (+`-internal`),
   devbox.json script entry.

## Non-Functional Requirements

- **Security:** `ENCRYPTION_PROVIDER=local` + vaulted `ENCRYPTION_KEY`
  (channel OAuth tokens encrypted at rest — plaintext is the upstream
  default). `no_log` on secret tasks. Postgres/Redis/Temporal reachable
  only inside their bridge networks; published host ports are tailnet
  debugging only. Never set `NOT_SECURED`,
  `DISABLE_SSRF_PROTECTION`, or any `STRIPE_*` var.
- **Idempotency:** `docker rm -f || true` + `docker run` (Windows
  pattern); re-runs replace containers cleanly.
- **Reproducibility:** `postiz_image_tag` default `latest` (upstream has
  no semver tags — pin by digest as a follow-up if desired).
- **Boot ordering:** infra containers (postgres, temporal-postgres,
  redis) healthy before temporal; temporal healthy before app. Prisma
  migrations run inside the app container at boot — no separate migrate
  step.
- **Portability:** every port/domain/volume resolves through
  `infra_*`/`infra_value_*` chains.

## Current State

- Fresh deploy — no existing Postiz resources on dtop202311.
- `postiz.nl.levonk.com` does not exist in Cloudflare DNS yet.
- Vault vars not yet added (user handoff required before live deploy).

## Known Limitations / Open Questions

- **Provider media fetch over public URL:** several providers (TikTok,
  Instagram) pull uploaded media from `{FRONTEND_URL}/uploads/*` over the
  public internet. `postiz.nl.levonk.com` is tailnet-only (CNAME →
  `dtop202311.tale-grouper.ts.net` = 100.x CGNAT), so URL-fetch posting
  will fail for those providers until the domain is publicly exposed
  (e.g. cloudflared tunnel — `proxy-cloudflared` role exists) or media is
  posted another way. Recommendation: ship tailnet-only now; revisit if
  TikTok/Instagram posting is needed.
- **Registration control:** `DISABLE_REGISTRATION=true` also disables
  OIDC login. Plan: deploy with registration enabled, create the first
  account, then set `tools_postiz_disable_registration: true` and
  redeploy. (Alternatively put the domain behind Authelia later.)
- **Image pinning:** upstream publishes no semver tags; `latest` used.
  Consider digest pinning after first successful deploy.
- **Shared vs dedicated Postgres:** Temporal gets its own
  `postgres:16-alpine` (reference layout); merging into the app Postgres
  is possible but deviates from the tested compose.

## Vault Handoff (blocking for live deploy, not for code)

User adds to `infrahub-levonk-all.vault.yml` via `scripts/edit-vault.sh`
(agent generates values, never edits the vault):

```yaml
vault_postiz_jwt_secret: "<openssl rand -hex 32>"
vault_postiz_postgres_password: "<openssl rand -hex 24>"
vault_postiz_temporal_postgres_password: "<openssl rand -hex 24>"
vault_postiz_encryption_key: "<openssl rand -hex 32>"
```

## Out of Scope

- Social provider OAuth app credentials (per-provider `*_CLIENT_ID` /
  `*_CLIENT_SECRET` pairs) — added later per-provider as channels are
  connected; role accepts optional vaulted pairs when present.
- Public exposure of `/uploads` (cloudflared tunnel) — see Known
  Limitations.
- Temporal UI / admin-tools / Elasticsearch / Spotlight containers.
- Backup policy for postiz volumes (defer — see Phase 5b of impl guide).

## Acceptance Criteria

- `just ansible-deploy-postiz` completes clean against
  `windows-docker.yml` (syntax check + `--check` first).
- `docker ps` on dtop202311 shows all six containers healthy.
- `https://postiz.nl.levonk.com` returns the Postiz UI (TLS valid,
  no auth redirect).
- `https://postiz.nl.levonk.com/api` responds (not 404/502).
- Temporal healthy: postiz can schedule (worker connects to
  `localnet-postiz-temporal:7233`).
