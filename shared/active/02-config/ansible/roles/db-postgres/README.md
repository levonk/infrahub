# db-postgres

Shared PostgreSQL instance — one container per docker host, consumed by
multiple stacks instead of each service shipping its own DB sidecar.

Uses the SSH-tunneled Docker CLI pattern (`DOCKER_HOST` + `delegate_to:
localhost`), so the same tasks work on Windows Docker Desktop and any remote
dockerd. On Windows hosts this is required because `community.docker` modules
cannot run there.

## Usage

Consumers include the role with their docker host, networks, and the
users/databases they need:

```yaml
- name: Deploy shared postgres and provision databases
  ansible.builtin.include_role:
    name: db-postgres
  vars:
    db_postgres_docker_host: "{{ media_stack_docker_host }}"
    db_postgres_networks:
      - "{{ media_stack_network_name }}"
    db_postgres_users:
      - name: "radarr"
        password: "{{ vault_media_postgres_radarr_password }}"
    db_postgres_databases:
      - { name: "radarr_main", owner: "radarr" }
      - { name: "radarr_log", owner: "radarr" }
```

Provisioning is additive and idempotent — multiple playbooks may include the
role against the same instance; each declares only its own users/databases.
The role never drops users or databases, and never force-recreates a running
container (that would drop every consumer's connections).

## Key variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `db_postgres_enabled` | `true` | `false` removes the container (volume preserved) |
| `db_postgres_docker_host` | `infra_value_db_postgres_docker_host` | docker endpoint (required) |
| `db_postgres_container_name` | `localnet-db-postgres` | container name / in-network hostname |
| `db_postgres_image` / `_tag` | `postgres` / `17-alpine` | image |
| `db_postgres_volume` | `localnet-db-postgres-data-volume` | data volume |
| `db_postgres_networks` | `[]` | networks to join (first = primary) |
| `db_postgres_publish_port` | `true` | publish host port for admin access |
| `db_postgres_host_port` | `infra_port_db_postgres_host` (5439) | host port |
| `db_postgres_container_port` | `infra_port_db_postgres_container` (5432) | container port |
| `db_postgres_admin_password` | `vault_db_postgres_admin_password` | superuser password |
| `db_postgres_users` | `[]` | `[{name, password}]` to provision |
| `db_postgres_databases` | `[]` | `[{name, owner}]` to provision |

## Secrets

- `vault_db_postgres_admin_password` — superuser password (vault, per ADR-20260624001)
- Consumer passwords — caller-supplied vault refs in `db_postgres_users`

## Consumers

- `media-stack` (dtop202311, nl region): radarr, sonarr, lidarr, prowlarr
  (main + log each), bazarr, romm — 10 databases, 6 users.
