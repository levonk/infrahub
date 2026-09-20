# ai-acrm

Deploys [ACRM](https://github.com/levonk/acrm) — a context-aware communication
intelligence platform (Next.js 16 + Drizzle/Postgres) — onto Windows Docker
Desktop (dtop202311, nl region). nl-only role; structured with a `group_names`
dispatch like `search-hister` so a future cno path can slot in.

## Architecture

- **Containers**: `localnet-acrm-web` (Next.js app) + `localnet-acrm-postgres`
  (`postgres:17-alpine`)
- **Image**: `{{ infra_registry }}/localnet-ai-acrm-web:latest` — built from the
  private acrm repo root Dockerfile (`pnpm --filter=web --prod deploy /prod/web`,
  deploy output copied to `/app`) and pushed by the acrm repo's build recipe
- **Networks**: dedicated `acrm-network` bridge (web ↔ postgres); the web
  container also joins `traefik-windows-network` for Traefik routing
- **Domains**: `acrm.nl.{{ infra_domain_base }}` (dashboard, Authelia-gated) and
  `acrm-api.nl.{{ infra_domain_base }}` (v1 API, `x-acrm-api-key`, no SSO)
- **Storage**: named volume `localnet-acrm-postgres-data-volume` at
  `/var/lib/postgresql/data` (postgres entrypoint handles ownership — no
  `localnet-volume-init`)

## Deployment Pattern

SSH-tunneled Docker CLI (`DOCKER_HOST: ssh://` + `delegate_to: localhost`)
because `community.docker` modules can't run on Windows (Ansible core
`basic.py` imports `grp`, Unix-only). Image pulls use
`DOCKER_CONFIG=~/.docker-no-creds` so public/registry pulls don't trigger the
macOS keychain unlock modal (tools-stirling-pdf pattern).

## Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ai_acrm_enabled` | `true` | Service toggle |
| `ai_acrm_verify_health` | `true` | Gate the post-deploy web health wait |
| `ai_acrm_run_migrations` | `true` | Gate the drizzle migration step |
| `ai_acrm_container_name_web` | `infra_hostname_acrm_web` | Web container name |
| `ai_acrm_container_name_postgres` | `infra_hostname_acrm_postgres` | Postgres container name |
| `ai_acrm_web_image` / `_tag` | `{{ infra_registry }}/localnet-ai-acrm-web` / `latest` | Registry image |
| `ai_acrm_postgres_image` | `postgres:17-alpine` | Postgres image |
| `ai_acrm_host_port` / `_container_port` | `infra_port_ai_acrm_*` (4538/3000) | Web port mapping |
| `ai_acrm_postgres_host_port` / `_container_port` | `infra_port_ai_acrm_postgres_*` (5440/5432) | Postgres port mapping (host port is tailnet debugging only) |
| `ai_acrm_network_name` | `infra_network_ai_acrm_network_name` (`acrm-network`) | Dedicated bridge |
| `ai_acrm_traefik_network_name` | `proxy_traefik_windows_network_name` (`traefik-windows-network`) | Traefik reachability |
| `ai_acrm_domain` / `_domain_api` | `infra_domain_ai_acrm` / `infra_domain_ai_acrm_api` | Dashboard / API domains |
| `ai_acrm_postgres_volume` | `infra_storage_acrm_postgres_data_volume` | pgdata volume |
| `ai_acrm_postgres_user` / `_db` | `acrm` / `acrm` | POSTGRES_USER / POSTGRES_DB |
| `ai_acrm_postgres_password` | `vault_acrm_postgres_password` | **Required, vault** |
| `ai_acrm_api_key` | `vault_acrm_api_key` | **Required, vault** — empty = open API |
| `ai_acrm_database_url` | derived | `postgresql://…@<postgres container>:5432/acrm` — container name + container port, never the host port |
| `ai_acrm_docker_host` | `ssh://ansible@{{ infra_tailscale_fqdn_windows_docker }}` | Windows Docker daemon endpoint |
| `ai_acrm_web_app_dir` | `/app` | In-image deploy output dir (see Migrations) |
| `ai_acrm_safety_keywords` | `acrm_safety_keywords` (empty) | Optional extra `ACRM_SAFETY_KEYWORDS` |
| `ai_acrm_tz` | `localnet_tz` | Timezone |

## Vault Requirements

Two keys must exist in the client vault
(`levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`)
before the first deploy — generate with `openssl rand -hex 32` and hand off to
the user per the repo AGENTS.md vault-edit flow:

```yaml
vault_acrm_api_key: "<generated>"
vault_acrm_postgres_password: "<generated>"
```

The role asserts both are non-empty — an empty `ACRM_API_KEY` leaves the v1
API open (the app treats an unset key as no-auth).

## Migrations

Schema migrations run as a one-off container on `acrm-network` before the web
container is (re)deployed, gated on `ai_acrm_run_migrations`:

```
docker run --rm --network acrm-network -e DATABASE_URL=… \
  <web image> sh -c 'cd /app && ./node_modules/.bin/drizzle-kit migrate'
```

**Why not `pnpm run db:migrate`?** The acrm root Dockerfile installs pnpm only
in the `base` build stage; the `runner` stage is a fresh `node:26-alpine`, so
the `pnpm` binary is absent at runtime. `drizzle-kit` itself IS a production
dependency of the web package, so `pnpm --prod deploy` links its binary at
`/app/node_modules/.bin/drizzle-kit` — the same direct-`.bin` invocation the
image's own `CMD` uses for `next start`. `drizzle.config.ts` and
`src/db/migrations/` ship in the deploy output because `apps/active/web` has
no `files` field / `.npmignore` / `.gitignore` for `pnpm deploy` to filter on.

`drizzle-kit migrate` is idempotent — applied migrations are tracked in the
`drizzle.__drizzle_migrations` journal table, so re-runs are no-ops.

## Example Play

```yaml
- name: Deploy ACRM (nl)
  hosts: windows_docker_hosts
  roles:
    - role: ai-acrm
```

Real wiring (inventory, `include_vars` of the infrastructure files, Traefik +
DNS phases) lives in `playbooks/deploy-acrm.yml` (story 05-001).

## Dependencies

- `traefik-windows` deployed (provides `traefik-windows-network`)
- `dtop202311` bootstrapped (Docker Desktop, Tailscale, `ansible` user)
- Web image built + pushed to the local registry from the acrm checkout
- Vault keys above added by the user
