# Control Center — Research

Service: **Control Center** (business dashboard for industry updates, brand mentions, newsletter monitoring, audience tracking, reminders, tasks)

## Upstream

- **Original**: https://github.com/mreflow/control-center (local-first, single-user desktop app)
- **Fork (deploy this)**: https://github.com/lrepo52/control-center (adds multi-tenancy: auth, login/register, session cookies, per-tenant entities, tagging system)
- **Fork diff**: 94 files, +16834/-507 lines — adds `app/api/auth/*`, `lib/server/auth.ts`, `lib/server/tags.ts`, `lib/server/view-state.ts`, tenant-scoped collectors, entity CRUD, schema v7 migration

## Architecture

| Component | Technology |
|-----------|-----------|
| Framework | Next.js (App Router, `next start`) |
| Runtime | Node.js >= 24.19 (uses `node:sqlite` built-in) |
| Database | SQLite via `node:sqlite` (Node 24+ built-in, NOT `better-sqlite3`) |
| Auth (fork) | scrypt password hashing, session cookies (httpOnly, sameSite:strict, 7-day maxAge) |
| Data dir | `CONTROL_CENTER_DATA_DIR` env var (default: OS-specific app-data dir) |
| Port | 3000 (configurable via `PORT` env or `--port=`) |

## Critical Deployment Constraints

### 1. Loopback-only Host check (proxy.ts)

The app has a Next.js middleware (`proxy.ts`) that rejects ALL requests where the
`Host` header is not `localhost`/`127.0.0.1`/`::1`. Behind Traefik, the Host header
will be `dashboard.levonk.com` / `dashboard.nl.levonk.com`, so every API call returns
`403 "Control Center only accepts requests from this computer."`.

**The fork (lrepo52) did NOT patch this check.** The auth additions (login/register/
session) are layered ON TOP of the loopback check — the loopback check runs first
and blocks everything before auth can even run.

**Required patch**: Modify `proxy.ts` to allow configured domains via an env var
(e.g., `CONTROL_CENTER_ALLOWED_HOSTS=dashboard.levonk.com,dashboard.nl.levonk.com`)
or disable the loopback check entirely when `CONTROL_CENTER_PUBLIC_MODE=true`.

### 2. Loopback binding (`next start --hostname 127.0.0.1`)

The `npm start` script and `scripts/launch.mjs` both hardcode `--hostname 127.0.0.1`.
Inside a Docker container, this is fine — Traefik connects to the container's IP on
the Docker network, and the app listens on 127.0.0.1 inside the container's network
namespace. BUT: the container needs to listen on `0.0.0.0` for Traefik to reach it
via the Docker network.

**Required patch**: Change `next start --hostname 127.0.0.1` to `next start` (defaults
to 0.0.0.0) or `next start --hostname 0.0.0.0` in the Dockerfile's CMD.

### 3. No Dockerfile exists

Neither the original nor the fork ships a Dockerfile. Need to create one:
- Base: `node:24-alpine` (or `node:24-slim` — need Node >= 24.19 for `node:sqlite`)
- Multi-stage build (mandatory per AGENTS.md Invariant #2):
  - Stage 1 (builder): `npm ci`, `npm run build`
  - Stage 2 (runtime): copy `.next/standalone`, `.next/static`, `public/`, `node_modules/`
- CMD: `node server.js` (Next.js standalone output) or `npm start`

### 4. SQLite data persistence

The app stores all data in SQLite (`control-center.sqlite`) in the data directory.
For container deployment:
- Mount a volume to `CONTROL_CENTER_DATA_DIR`
- The app creates the DB and runs schema migrations on first start
- **Backup**: SQLite file-based state → use rsync/tar to backup path (Phase 5b)

### 5. No upstream Docker image

This is a **locally-built image** (Phase 3 of the implementation workflow applies).
- Source: `https://github.com/lrepo52/control-center`
- Build: Dockerfile in `shared/active/03-container/services/dashboard/control-center/`
- Register in `scripts/build-and-push-images.sh`

## Secrets Required

The fork adds authentication, but the first user registers via the UI (`/register`).
No secrets are needed for initial deployment — the app bootstraps its own auth.

Optional secrets (env vars, not required for deployment):
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `XAI_API_KEY` — AI curation
- `CONTROL_CENTER_DATA_DIR` — data directory path (will set to volume mount)

**No vault secrets required for this service.**

## Domain Plan

Per user decision: deploy on BOTH domains.

| Domain | Purpose |
|--------|---------|
| `dashboard.levonk.com` | Shared default (Traefik router) |
| `dashboard.nl.levonk.com` | Client-specific override (dtop202311) |

Both domains route to the same container via Traefik. Authelia SSO middleware
protects both (the fork has its own auth, but Authelia provides the outer gate).

## Target Machine

- **dtop202311** (Windows Docker Desktop) — per user decision
- Same machine as `dashboard-directory-empire`
- Traefik Windows proxy (`proxy_traefik_windows`) routes to it

## Port Allocation

Need to allocate a new port for the container. Check `ports.yml` for conflicts.
The app defaults to port 3000 inside the container.

## Monitoring

- **Health endpoint**: The app has a health check (used by `npm run launch` smoke
  test). Need to verify the exact path (likely `/` or a dedicated `/health`).
- **Metrics**: No Prometheus metrics endpoint — set `metrics_path: null`.
- **Pipeline**: `none` (standalone dashboard service).

## Resolved Questions

1. **proxy.ts patch approach**: Env var allowlist (`CONTROL_CENTER_ALLOWED_HOSTS`)
   for defense-in-depth. The fork did NOT patch the loopback check — must be done
   in the fork repo before building the image.
2. **Image base**: `node:24.20-alpine` (available on Docker Hub, >= 24.19).
   `node:sqlite` is a built-in Node module (no native bindings), so Alpine works.
3. **Next.js standalone output**: `next.config.ts` does NOT have `output: "standalone"`.
   Must add it in the fork for a smaller runtime image.
4. **Health check path**: `/api/health` — returns JSON `{service, status, version}`,
   status 503 if unhealthy (DB check fails).
5. **Build pattern**: Follow `scripts/build-directory-empire-image.sh` pattern —
   Dockerfile lives in the fork repo (lrepo52/control-center), build script clones
   it, builds with buildx, pushes to local registry. linux/amd64 only (target is
   Windows Docker Desktop).

## Required Fork Patches (before building image)

1. **proxy.ts**: Add env-var-based host allowlist. When `CONTROL_CENTER_ALLOWED_HOSTS`
   is set, allow those hosts in addition to loopback. When unset, keep loopback-only
   (preserves upstream behavior for local dev).
2. **next.config.ts**: Add `output: "standalone"` for smaller Docker image.
3. **package.json `start` script**: Change `next start --hostname 127.0.0.1` to
   `next start` (defaults to 0.0.0.0, needed for Docker networking).
4. **Dockerfile**: Create multi-stage Dockerfile (builder + runtime).

## Reference Patterns (in this repo)

- **Role**: `shared/active/02-config/ansible/roles/dashboard-directory-empire/` —
  same target (dtop202311), same pattern (delegate_to + DOCKER_HOST ssh://)
- **Build script**: `scripts/build-directory-empire-image.sh` — clone, buildx, push
- **Traefik dynamic config**: `proxy_traefik_windows/templates/dynamic/de-nl.yml.j2` —
  Authelia-gated HTTPS router for Windows Traefik
- **Just recipes**: `justfile` → `build-directory-empire-image`, `ansible-deploy-directory-empire`
