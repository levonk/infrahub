# ACRM — Research Index

## Service

- **Name**: ACRM (context-aware communication intelligence platform)
- **Source repo**: `git@github-l:levonk/acrm.git` (private GitHub repo, checkout at `~/p/gh/levonk/acrm`)
- **Language/toolchain**: TypeScript, Next.js 16, Nx + pnpm monorepo, Drizzle ORM + postgres.js
- **Category**: AI / communication intelligence
- **Target region**: `nl` only — `dtop202311` (Windows Docker Desktop, amd64, via Tailscale)

## What It Is

ACRM captures, analyzes, and understands human communication context —
relationship graphs, tone, risk, and appropriateness — and exposes it through
a versioned JSON API plus a Next.js dashboard. The first production consumer
is a Vencord (Discord client) plugin that POSTs ingested messages to
`POST /api/v1/message` and renders safety-latch warnings / reply suggestions
from `POST /api/v1/suggest`.

See `~/p/gh/levonk/acrm/AGENTS.md` and `~/p/gh/levonk/acrm/internal-docs/concept.md`
for the full system description (engine interfaces, OSS/commercial split,
progression pipelines).

## Documents

| Document | Contents |
|----------|----------|
| [`deployment-design.md`](deployment-design.md) | Full nl-region design: containers, networks, ports, domains, Traefik (Windows), DNS records, secrets, migrations, backup, monitoring, Authelia |
| [`packaging-analysis.md`](packaging-analysis.md) | "How should side projects graduate into infrahub deployment?" — image-vs-package artifact analysis, Verdaccio's real role, option comparison, graduation checklist |

## Deployment Requirements Summary

| Requirement | Value | Notes |
|-------------|-------|-------|
| Web container | `localnet-acrm-web` | Locally-built image `localnet-ai-acrm-web` (private repo → Dockerfile lives in acrm repo, root build context) |
| DB container | `localnet-acrm-postgres` | `postgres:17-alpine` upstream image, per-service DB convention (n8n pattern) |
| Network | `acrm-network` (internal web↔db) + `traefik-windows-network` (web only) | Windows Traefik routes by container name |
| Ports | web `4538→3000`, postgres `5440→5432` | Verified free in shared + levonk `ports.yml` |
| Domains | `acrm.nl.levonk.com` (Authelia SSO) + `acrm-api.nl.levonk.com` (no Authelia, `x-acrm-api-key`) | Stirling-style two-domain split — the Vencord plugin cannot do SSO |
| Secrets | `vault_acrm_api_key`, `vault_acrm_postgres_password` | User vault handoff; better-auth is a stub so no `BETTER_AUTH_SECRET` yet |
| Health | `GET /` returns 200 (static landing page) | No `/api/health` exists — candidate follow-up in the acrm repo |
| Migrations | `pnpm run db:migrate` (drizzle-kit) via one-off container before web start | `drizzle-kit` is a prod dependency; migrations ship in the image |
| Backup | Deferred (no nl postgres precedent; `devops-restoredrill` is systemd/Linux-only) | Follow-up: pg_dump sidecar container |
| Machine (services.yml) | `dtop202311` | `machine:` field for both entries |

## Critical Discovery: `infra_tailscale_ip_windows_docker` is wrong

`levonk/active/02-config/ansible/infrastructure/domains.yml:126` sets
`infra_tailscale_ip_windows_docker: "100.90.22.85"` — but `100.90.22.85` is the
**OCI cloud server** (see `levonk/.../inventories/oci.yml` `ansible_host`, and
`group_vars/windows_docker_hosts.yml` comment "The OCI Tailscale IP is
100.90.22.85"; the local Docker registry `100.90.22.85:5000` also runs there).
Live `tailscale status` shows dtop202311 = **100.81.103.34**.

Consequence: the stirling-api A record (`stirling-api.nl.levonk.com`) points at
the OCI server, not the Windows host — almost certainly broken today (OCI
Traefik has no stirling router). For ACRM we recommend CNAME records to
`dtop202311.tale-grouper.ts.net` for both domains (consistent with every other
nl service), and flag the wrong variable as a fix-up item.
