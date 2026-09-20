---
story_id: "03-001"
story_title: "Create ai-acrm Ansible role (Windows deploy + postgres + migrations)"
story_name: "acrm-role"
prd_name: "acrm-deployment"
prd_file: "internal-docs/feature/todo/acrm-deployment/feat-202609191733-acrm-deployment.md"
phase: 3
parallel_id: 1
branch: "feature/current/acrm-deployment/story-03-001-acrm-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001"]
parallel_safe: false
modules: ["ansible-role", "docker", "windows", "postgres"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "docker", "role", "windows", "postgres", "acrm"]
due: "2026-09-19"
create-date: "2026-09-19"
update-date: "2026-09-19"
---

## Summary

Create `shared/active/02-config/ansible/roles/ai-acrm/` — an nl-only role
(ACRM deploys nowhere else, so only the Windows path is needed; structure it
like `search-hister` with a `group_names` dispatch so a future cno path can
slot in). Deploys `localnet-acrm-postgres` + `localnet-acrm-web` on
`acrm-network`, runs drizzle migrations via a one-off container, and wires
the web container onto `traefik-windows-network` for Traefik reachability.

## Sub-Tasks

- [ ] `defaults/main.yml` — all vars via `infra_*`/`infra_value_*`/`vault_*`
  chains (see defaults sketch below)
- [ ] `tasks/main.yml` — `assert` required vars (incl.
  `acrm_api_key | length > 0` and `acrm_postgres_password | length > 0` —
  empty key = open API), then `include_tasks: deploy-windows.yml` gated on
  `ai_acrm_enabled | bool` + `'windows_docker_hosts' in group_names`
- [ ] `tasks/deploy-windows.yml` — ssh-tunneled Docker CLI pattern
  (`DOCKER_HOST: ssh://…`, `delegate_to: localhost`):
  1. `docker network create acrm-network` (inspect-or-create)
  2. `docker volume create localnet-acrm-postgres-data-volume`
     (inspect-or-create; postgres entrypoint handles ownership — no
     `localnet-volume-init` needed)
  3. `docker pull postgres:17-alpine` and
     `docker pull {{ ai_acrm_web_image }}:{{ ai_acrm_web_image_tag }}`
     (registry image — HTTP over tailnet, no creds; use
     `DOCKER_CONFIG: ~/.docker-no-creds` for the public postgres pull to
     avoid the macOS keychain modal, per stirling)
  4. `docker rm -f localnet-acrm-postgres || true`; `docker run -d` postgres
     (`-e POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB`, volume mount,
     `-p 5440:5432`, `pg_isready` healthcheck, `no-new-privileges`,
     `unless-stopped`, json-file logs) — `no_log: true`
  5. wait healthy (`docker inspect .State.Health.Status`, `until ==
     "healthy"`, `retries: infra_retry_extended`, `delay:
     infra_delay_default`)
  6. migrations: `docker run --rm --network acrm-network -e
     DATABASE_URL=… <web image> sh -c 'cd {{ ai_acrm_web_app_dir }} &&
     pnpm run db:migrate'` gated on `ai_acrm_run_migrations | bool` —
     `no_log: true` (URL contains the password)
  7. `docker rm -f localnet-acrm-web || true`; `docker run -d` web on
     `acrm-network` (`-e PORT`, `-e DATABASE_URL` (postgres container name +
     5432, NOT the host port), `-e ACRM_API_KEY`, `-e TZ`, optional
     `-e ACRM_SAFETY_KEYWORDS`, `-p 4538:3000`, wget healthcheck on `/`,
     `unless-stopped`, `no-new-privileges`) — `no_log: true`
  8. `docker network connect traefik-windows-network localnet-acrm-web`
     (idempotent `|| true`) — lets traefik-windows reach the container by
     name
  9. wait healthy + status report debug blocks
- [ ] `handlers/main.yml` — `restart acrm-web` / `restart acrm-postgres`
  via `docker restart` over the tunnel (NOT `state: restarted`)
- [ ] `meta/main.yml` — `role_name: ai_acrm`, platforms Windows `["all"]`
  (schema rejects 10/11), description, tags
- [ ] `README.md` — role doc (vars table, dependencies, example play,
  vault requirements, migration notes)

### defaults/main.yml sketch

```yaml
ai_acrm_enabled: true
ai_acrm_verify_health: true
ai_acrm_run_migrations: true
ai_acrm_container_name_web: "{{ infra_hostname_acrm_web | default('localnet-acrm-web') }}"
ai_acrm_container_name_postgres: "{{ infra_hostname_acrm_postgres | default('localnet-acrm-postgres') }}"
ai_acrm_web_image: "{{ infra_registry | default('100.90.22.85:5000') }}/localnet-ai-acrm-web"
ai_acrm_web_image_tag: "latest"
ai_acrm_postgres_image: "postgres:17-alpine"
ai_acrm_host_port: "{{ infra_port_ai_acrm_host }}"
ai_acrm_container_port: "{{ infra_port_ai_acrm_container }}"
ai_acrm_postgres_host_port: "{{ infra_port_ai_acrm_postgres_host }}"
ai_acrm_postgres_container_port: "{{ infra_port_ai_acrm_postgres_container }}"
ai_acrm_network_name: "{{ infra_network_ai_acrm_network_name | default('acrm-network') }}"
ai_acrm_traefik_network_name: "{{ proxy_traefik_windows_network_name | default('traefik-windows-network') }}"
ai_acrm_domain: "{{ infra_domain_ai_acrm | default('acrm.nl.' ~ (infra_domain_base | default('example.com'))) }}"
ai_acrm_domain_api: "{{ infra_domain_ai_acrm_api | default('acrm-api.nl.' ~ (infra_domain_base | default('example.com'))) }}"
ai_acrm_postgres_volume: "{{ infra_storage_acrm_postgres_data_volume | default('localnet-acrm-postgres-data-volume') }}"
ai_acrm_postgres_user: "acrm"
ai_acrm_postgres_db: "acrm"
ai_acrm_postgres_password: "{{ vault_acrm_postgres_password | default('') }}"
ai_acrm_api_key: "{{ vault_acrm_api_key | default('') }}"
ai_acrm_database_url: "postgresql://{{ ai_acrm_postgres_user }}:{{ ai_acrm_postgres_password }}@{{ ai_acrm_container_name_postgres }}:{{ ai_acrm_postgres_container_port }}/{{ ai_acrm_postgres_db }}"
ai_acrm_docker_host: "ssh://ansible@{{ infra_tailscale_fqdn_windows_docker | default('dtop202311.' ~ (infra_tailscale_tailnet | default('example.ts.net'))) }}"
ai_acrm_web_app_dir: "/app/apps/active/web"   # confirm with story 01-001
ai_acrm_safety_keywords: "{{ acrm_safety_keywords | default('') }}"   # optional
ai_acrm_tz: "{{ localnet_tz | default('UTC') }}"
ai_acrm_healthcheck_interval: "30s"  # + timeout/retries/start_period strings
```

## Relevant Files

- `shared/active/02-config/ansible/roles/ai-acrm/{defaults,tasks,handlers,meta}/main.yml`, `README.md`
- Reference: `roles/search-hister/tasks/deploy-windows.yml`,
  `roles/tools-stirling-pdf/tasks/deploy-windows.yml`,
  `roles/artifact-verdaccio/tasks/deploy-windows.yml`,
  `roles/ai-n8n/tasks/*postgres*` (env var pattern)

## Acceptance Criteria

- Given `windows_docker_hosts` inventory + loaded infra vars, when the role
  runs, then it validates vars, creates network+volume, deploys postgres,
  waits healthy, runs migrations, deploys web, joins traefik-windows-network
- Given missing `vault_acrm_api_key`, when the role runs, then the assert
  fails with a clear message
- Given a re-run, then containers are replaced cleanly (`docker rm -f ||
  true` + `docker run`) — idempotent
- Given `docker logs`, then no secrets appear (no_log on secret tasks)
- Given the defaults, then every value traces to `infra_*`/`infra_value_*`/
  `vault_*` — no hardcoded IPs/ports/domains

## Implementation Notes

- Env values must be strings in `docker run -e` — quote ports.
- Postgres published host port 5440 is for tailnet debugging only; the app
  never uses it.
- If story 01-001 lands the web app at a different in-image path, update
  `ai_acrm_web_app_dir` to match.
- Migrations are idempotent (drizzle-kit migrate is a no-op when applied).

## Definition of Done

- Role complete (6 files), `ansible-lint` clean, syntax-check clean, deploy
  verified on dtop202311 during 05-001's live run
