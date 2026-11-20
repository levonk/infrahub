# Postiz — Deployment

Target environment: Windows Docker Desktop host, x86_64 (amd64), deployed via
Ansible `community.docker.docker_container` (no docker-compose on target —
the official compose is reference-only), Traefik reverse proxy at
`postiz.nl.levonk.com` (HTTPS).

## Official image

| Registry | Image | Notes |
|----------|-------|-------|
| GHCR (only) | `ghcr.io/gitroomhq/postiz-app` | Single all-in-one image: frontend + backend + orchestrator |

- **Multi-arch**: `latest` is an OCI index with `linux/amd64` and `linux/arm64`
  (verified via GHCR manifest). Windows Docker Desktop (WSL2) pulls `amd64`.
- **Tag scheme — red flag**: the registry publishes `latest`, Unix-timestamp
  tags (e.g. `amd64-1728144268`, `arm64-1728144268`, `1728144268`), and no
  semver tags, even though GitHub releases use semver (v2.26.0…). For
  reproducible deploys **pin by timestamp tag or digest**, not `latest`.
  (There is also a stray `Array-1727179445` tag — CI artifact, ignore.)
- There is no separate slim/micro variant; this is the only image.

## Containers (reference: gitroomhq/postiz-docker-compose)

| Container | Image | Required | Ports published (ref) | Purpose |
|-----------|-------|----------|----------------------|---------|
| `postiz` | `ghcr.io/gitroomhq/postiz-app` | yes | `4007:5000` (we proxy instead) | App — serves everything on **container :5000** |
| `postiz-postgres` | `postgres:17-alpine` | yes | none (internal) | App database |
| `postiz-redis` | `redis:7.2` | yes | none (internal) | Queues/cache/sessions |
| `temporal` | `temporalio/auto-setup:1.28.1` | yes | `127.0.0.1:7233` (internal-only is fine) | Workflow engine; auto-creates schema |
| `temporal-postgresql` | `postgres:16` | yes (Temporal's own DB) | none | Temporal persistence |
| `temporal-elasticsearch` | `elasticsearch:7.17.27` | ref ships it; **droppable** | none (`expose 9200`) | Temporal *advanced* visibility only. `ENABLE_ES=false` + standard SQL visibility works — saves ~0.5–1 GB RAM |
| `temporal-ui` | `temporalio/ui:2.34.0` | optional | `127.0.0.1:8080` | Workflow debugging dashboard; skip or keep loopback-only |
| `temporal-admin-tools` | `temporalio/admin-tools:1.28.1-…` | optional | none | CLI tools container |
| `spotlight` | `ghcr.io/getsentry/spotlight` | optional (`debug` profile) | `127.0.0.1:8969` | Sentry dev monitoring |

**External services**: `DATABASE_URL`, `REDIS_URL`, and `TEMPORAL_ADDRESS` are
plain connection strings — an existing shared Postgres/Redis can be reused
(dedicated `postiz` db + user recommended). Temporal can also point at a shared
Postgres via `POSTGRES_SEEDS`/`DB_PORT`; simplest is keeping its dedicated
`postgres:16` container.

**Note**: `postiz-postgres` and `temporal-postgresql` are separate containers
in the reference; merging them into one Postgres with two databases is possible
but deviates from the tested layout — keep separate unless resources demand it.

## Networks

Reference uses two bridge networks:

- `postiz-network`: `postiz`, `postiz-postgres`, `postiz-redis`
- `temporal-network`: `temporal`, `temporal-postgresql`,
  `temporal-elasticsearch`, `temporal-ui`, `temporal-admin-tools`
- **`postiz` joins both** (it must reach `temporal:7233`).

For our deploy: put `postiz` additionally on the Traefik-facing network (same
pattern as other levonk services). Only `postiz` needs Traefik reachability.

## Ports

| Listener | Port | Notes |
|----------|------|-------|
| Postiz app (in-container) | `5000` | Single entrypoint: UI on `/`, API on `/api/*`, uploads on `/uploads/*`, OAuth callbacks on `/integrations/*`. Traefik service port = `5000` |
| Backend internal | `3000` | In-container only (`BACKEND_INTERNAL_URL=http://localhost:3000`) |
| Temporal gRPC | `7233` | Internal; `TEMPORAL_ADDRESS=temporal:7233`. No publish needed |
| Temporal UI | `8080` | Optional; loopback-only if deployed |

**Healthcheck** (from reference): `GET http://localhost:5000/` —
`statusCode < 500` = healthy, `interval 30s`, `start_period 120s`
(the app is slow to boot; keep the long start period).

## Volumes / storage

| Mount | Purpose |
|-------|---------|
| `postiz-uploads → /uploads` | User media when `STORAGE_PROVIDER=local`. Required for persistence |
| `postiz-config → /config` | Optional `.env` file location (the container reads `/config/*.env`); env vars can also be passed directly — a bind dir or named volume both work |
| `postgres-volume → /var/lib/postgresql/data` | App DB |
| `postiz-redis-data → /data` | Redis (AOF/cache; persistence nice-to-have, not strictly required) |
| `temporal-postgres-data`, `temporal-elasticsearch-data` | Temporal state |

**Temporal dynamic config bind-mount (Ansible gotcha)**: the reference mounts
`./dynamicconfig` → `/etc/temporal/config/dynamicconfig` in the `temporal`
container and sets `DYNAMIC_CONFIG_FILE_PATH=config/dynamicconfig/development-sql.yaml`.
The file content (from `gitroomhq/postiz-docker-compose/dynamicconfig/development-sql.yaml`):

```yaml
limit.maxIDLength:
  - value: 255
    constraints: {}
system.forceSearchAttributesCacheRefreshOnRead:
  - value: true
    constraints: {}
```

Ansible must push this file to a host directory and bind-mount the directory —
it is not baked into the image. (Note the file itself is marked "dev setup
only" upstream; it is what the reference compose ships.)

**Local-uploads caveat**: providers like TikTok pull media via public URL —
`/uploads/*` must be reachable over public HTTPS. Our Traefik-fronted deploy
satisfies this.

## Boot ordering (healthcheck dependencies)

`postiz` waits on healthy: `postiz-postgres` (`pg_isready`), `postiz-redis`
(`redis-cli ping`), `temporal` (`temporal operator cluster health`).
`temporal` waits on `temporal-postgresql` + `temporal-elasticsearch`.
In Ansible: `docker_container` has no `depends_on` — start infra containers
first (separate tasks, order matters) and rely on Postiz's own retries +
the app's healthcheck; or poll container health before finishing.

## Resources

- Officially tested on **2 vCPU / 2 GB** single VM (all-in-one) — works for a
  single user with no headroom.
- **Recommended: 4 vCPU / 4–8 GB RAM**, 50 GB disk. The Temporal stack
  (ES ~256 MB heap + Postgres + auto-setup + UI) adds ~1–1.5 GB.
- On Docker Desktop: ensure the WSL2 VM memory limit accommodates the stack;
  dropping `temporal-elasticsearch` (`ENABLE_ES=false`) is the easiest saving.

## Environment variables

See `configuration.md`. Minimum viable set for our deploy (non-secret shown):

```env
MAIN_URL=https://postiz.nl.levonk.com
FRONTEND_URL=https://postiz.nl.levonk.com
NEXT_PUBLIC_BACKEND_URL=https://postiz.nl.levonk.com/api
BACKEND_INTERNAL_URL=http://localhost:3000
DATABASE_URL=postgresql://postiz-user:<vault>@postiz-postgres:5432/postiz-db-local
REDIS_URL=redis://postiz-redis:6379
JWT_SECRET=<vault>
TEMPORAL_ADDRESS=temporal:7233
IS_GENERAL=true
RUN_CRON=true
STORAGE_PROVIDER=local
UPLOAD_DIRECTORY=/uploads
NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads
NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY=/uploads
```

Env changes require container recreate (Ansible `docker_container` already
recreates on env diff).

## Upgrade notes

- Since **v2.12.0** Postiz requires Temporal (the old cron/worker model was
  replaced). Fresh installs just run the stack above.
- For future upgrades of a pre-2.12 install there is a migration guide:
  https://docs.postiz.com/self-host/installation/migration
- No DB migration command is needed on container start — Prisma migrations run
  inside the app container at boot (keep backups before image bumps).
