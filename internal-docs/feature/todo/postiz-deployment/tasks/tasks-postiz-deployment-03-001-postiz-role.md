---
story_id: "03-001"
story_title: "Create tools-postiz Ansible role (Windows deploy, 6 containers)"
story_name: "postiz-role"
prd_name: "postiz-deployment"
prd_file: "internal-docs/feature/todo/postiz-deployment/feat-202611131708-postiz-deployment.md"
phase: 3
parallel_id: 1
branch: "levonk/20261113-postiz"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001"]
parallel_safe: false
modules: ["ansible-role", "docker", "windows", "postgres", "redis", "temporal"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "docker", "role", "windows", "postgres", "redis", "temporal", "postiz"]
due: "2026-11-13"
create-date: "2026-11-13"
update-date: "2026-11-13"
---

## Summary

Create `shared/active/02-config/ansible/roles/tools-postiz/` modeled on
`ai-acrm` (nl-only Windows path, `group_names` dispatch). Deploys five
containers on dtop202311 via the ssh-tunneled Docker CLI pattern
(`DOCKER_HOST: ssh://…`, `delegate_to: localhost`): app Postgres, Temporal
Postgres, Redis, Temporal auto-setup, and the Postiz all-in-one app.

## Sub-Tasks

- [ ] `defaults/main.yml` — vars via `infra_*`/`infra_value_*`/`vault_*`:
  - `tools_postiz_enabled: true`, `tools_postiz_verify_health: true`,
    `tools_postiz_disable_registration: false`
  - images: `ghcr.io/gitroomhq/postiz-app:latest`,
    `postgres:17-alpine` (app DB), `postgres:16-alpine` (temporal DB),
    `redis:7.2-alpine`, `temporalio/auto-setup:1.28.1`, `alpine:3`
    (one-shot config init)
  - container names / networks / ports / domain via infra vars
    (`infra_hostname_postiz*`, `infra_network_tools_postiz_*`,
    `infra_port_tools_postiz_*`, `infra_domain_tools_postiz`)
  - volumes via `infra_storage_postiz_*`
  - secrets: `tools_postiz_jwt_secret: "{{ vault_postiz_jwt_secret |
    default('') }}"`, `tools_postiz_postgres_password`, `..._temporal_postgres_password`,
    `tools_postiz_encryption_key` from `vault_postiz_*`
  - `tools_postiz_domain: "{{ infra_domain_tools_postiz }}"`,
    `tools_postiz_url: "https://{{ tools_postiz_domain }}"`
  - `tools_postiz_docker_host: "ssh://ansible@{{
    infra_tailscale_fqdn_windows_docker | default('dtop202311.' ~
    (infra_tailscale_tailnet | default('example.ts.net'))) }}"`
  - healthcheck vars (strings with unit suffixes; app start_period
    `120s`), log opts, `tools_postiz_tz`
- [ ] `tasks/main.yml` — assert required vars (secrets non-empty:
  jwt_secret, postgres_password, temporal_postgres_password,
  encryption_key) then `include_tasks: deploy-windows.yml` gated on
  `tools_postiz_enabled | bool` + `'windows_docker_hosts' in group_names`
- [ ] `tasks/deploy-windows.yml` — ssh-tunneled docker CLI:
  1. ensure `postiz-network` + `postiz-temporal-network` (inspect-or-create)
  2. ensure volumes (5 named volumes, inspect-or-create)
  3. populate `localnet-postiz-temporal-dynamicconfig` via one-shot:
     `docker run --rm -v {vol}:/config alpine:3 sh -c 'printf ... > /config/development-sql.yaml'`
     with the yaml from `internal-docs/research/service/postiz/deployment.md`
     (limit.maxIDLength 255, forceSearchAttributesCacheRefreshOnRead true)
     — skip write if file already correct (idempotency: check `docker run
     --rm -v {vol}:/config alpine:3 test -f` first)
  4. pull all 5 service images (`DOCKER_CONFIG: ~/.docker-no-creds`)
  5. `docker rm -f || true` + `docker run -d` for infra tier, in order:
     - `localnet-postiz-postgres` (postiz-network; `-p 5441:5432`; pgdata
       volume; POSTGRES_USER=postiz, POSTGRES_DB=postiz,
       POSTGRES_PASSWORD=vault; pg_isready healthcheck; no_log)
     - `localnet-postiz-temporal-postgres` (postiz-temporal-network;
       `-p 5442:5432`; POSTGRES_USER=temporal, POSTGRES_DB=temporal,
       POSTGRES_PASSWORD=vault; pg_isready; no_log)
     - `localnet-postiz-redis` (postiz-network; redis data volume;
       `redis-cli ping` healthcheck; no publish)
  6. wait healthy on all three (`docker inspect .State.Health.Status`,
     `until`, `retries: infra_retry_extended`, `delay: infra_delay_default`)
  7. `localnet-postiz-temporal` on postiz-temporal-network
     (`temporalio/auto-setup:1.28.1`): env `DB=postgresql`,
     `DB_PORT=5432`, `POSTGRES_SEEDS=localnet-postiz-temporal-postgres`,
     `POSTGRES_USER=temporal`, `POSTGRES_PWD=<vault>`,
     `ENABLE_ES=false`,
     `DYNAMIC_CONFIG_FILE_PATH=config/dynamicconfig/development-sql.yaml`;
     mount dynamicconfig volume at `/etc/temporal/config/dynamicconfig`;
     healthcheck `temporal operator cluster health` (or equivalent);
     no_log (contains PWD)
  8. wait temporal healthy (retries extended — auto-setup runs schema
     setup; allow ~120s+)
  9. `localnet-postiz` on postiz-network + postiz-temporal-network can't
     be passed at `docker run` (one network per run) — run on
     postiz-network, then `docker network connect
     postiz-temporal-network` AND `docker network connect
     traefik-windows-network`
     env (see configuration.md): `MAIN_URL`, `FRONTEND_URL` =
     `https://postiz.nl.levonk.com`; `NEXT_PUBLIC_BACKEND_URL` = same +
     `/api`; `BACKEND_INTERNAL_URL=http://localhost:3000`;
     `DATABASE_URL=postgresql://postiz:<vault>@localnet-postiz-postgres:5432/postiz`;
     `REDIS_URL=redis://localnet-postiz-redis:6379`;
     `JWT_SECRET=<vault>`;
     `TEMPORAL_ADDRESS=localnet-postiz-temporal:7233`;
     `IS_GENERAL=true`; `RUN_CRON=true`; `STORAGE_PROVIDER=local`;
     `UPLOAD_DIRECTORY=/uploads`; `NEXT_PUBLIC_UPLOAD_DIRECTORY=/uploads`;
     `NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY=/uploads`;
     `ENCRYPTION_PROVIDER=local`; `ENCRYPTION_KEY=<vault>`;
     `DISABLE_REGISTRATION={{ tools_postiz_disable_registration }}` only
     when true; `TZ`; `-p 4539:5000`; uploads volume at `/uploads`;
     wget healthcheck `GET / :5000` statusCode<500, `start_period 120s`;
     `no-new-privileges`; `unless-stopped`; no_log
  10. wait healthy (start_period 120s → allow generous retries)
  11. status report debug block
- [ ] `handlers/main.yml` — `docker restart` over tunnel per container
- [ ] `meta/main.yml` — `role_name: tools_postiz`, platforms Windows
  `["all"]`
- [ ] `README.md` — vars, secrets, deploy notes, upgrade notes
  (pin-by-digest, prisma auto-migrations at boot)

## Acceptance Criteria

- `ansible-playbook --syntax-check` clean when wired into a playbook
  (story 05); `ansible-lint` clean on the role; all env/secrets resolve
  from `infra_*`/`vault_*` only — zero hardcoded ports/IPs/domains.
