# OmniRoute Ansible Role

This Ansible role deploys the OmniRoute AI Gateway service.

## Requirements

- Docker installed on target host
- Docker community collection (`community.docker`)
- LocalNet common role dependencies

## Role Variables

### Default Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ai_omniroute_container_name` | `localnet-ai-omniroute` | Container name |
| `ai_omniroute_image_name` | `localnet-ai-omniroute:latest` | Docker image name |
| `ai_omniroute_volume_name` | `ai-omniroute-data` | Docker volume name |
| `ai_omniroute_host_port` | `20128` | Host port mapping |
| `ai_omniroute_container_port` | `20128` | Container port |
| `ai_omniroute_healthcheck_interval` | `30` | Healthcheck interval (seconds) |
| `ai_omniroute_healthcheck_timeout` | `10` | Healthcheck timeout (seconds) |
| `ai_omniroute_healthcheck_retries` | `3` | Healthcheck retries |
| `ai_omniroute_healthcheck_start_period` | `40` | Healthcheck start period (seconds) |

### Required Variables

These variables are expected to be defined by the parent playbook or inventory:

| Variable | Description |
|----------|-------------|
| `localnet_services_dir` | Base directory for LocalNet services |
| `localnet_network_name` | Docker network name |
| `localnet_puid` | User ID for container processes |
| `localnet_pgid` | Group ID for container processes |
| `localnet_tz` | Timezone for containers |

## Dependencies

- `common` - LocalNet common role for base configuration

## Usage

### Example Playbook

```yaml
---
- name: Deploy OmniRoute
  hosts: localhost
  become: true
  roles:
    - omniroute
  vars:
    localnet_services_dir: /opt/localnet/services
    localnet_network_name: localnet
    localnet_puid: 1000
    localnet_pgid: 1000
    localnet_tz: UTC
```

### Override Variables

```yaml
- hosts: localhost
  roles:
    - role: omniroute
      vars:
        ai_omniroute_host_port: 20129
```

## Tasks

The role performs the following tasks:

1. **Directory Setup**: Creates the OmniRoute service directory
2. **Volume Management**: Creates the data volume for OmniRoute
3. **Image Build**: Builds the OmniRoute Docker image from source
4. **Container Deployment**: Deploys the OmniRoute container with:
   - Port mapping
   - Volume mounts
   - Environment variables
   - Security options (no-new-privileges, read-only filesystem)
   - Healthcheck
5. **Health Verification**: Waits for the service to become healthy
6. **Managed Configuration**: Pushes a partial config (provider nodes,
   connections, `kckinaicombo`) via `/api/settings/import-json`. Uses
   INSERT OR REPLACE - only entities in `managed-config.json.j2` are
   reconciled; UI changes to other entities are preserved. Disable with
   `ai_omniroute_managed_config_enabled: false`.
7. **Status Report**: Reports deployment status and access URLs

### FreeLLMAPI wiring

When `ai_omniroute_freellmapi_enabled` is true (default), the role also:

1. Asserts the `ai-freellmapi` container is running (the pipeline playbook
   stages it before this role).
2. Reads the auto-minted unified API key from the FreeLLMAPI container's
   SQLite (`/app/server/data/freeapi.db`, read-only `docker exec`). No vault
   secret is needed; a dashboard key rotation is picked up on the next run.
3. Adds a `freellmapi` openai-compatible provider node + connection pointing
   at `http://{{ infra_network_ip_ai_freellmapi }}:{{ infra_port_ai_freellmapi_container }}/v1`
   (chain-network IP - matches the NO_PROXY `172.29.0.0/16` range, so no
   iron-proxy egress), plus a `freellmapi/auto` model entry in
   `kckinaicombo` (weight `ai_omniroute_managed_freellmapi_weight`, default 12).

Set `ai_omniroute_freellmapi_enabled: false` on hosts without FreeLLMAPI.

## Handlers

- `restart omniroute` - Restarts the OmniRoute container

## Security Features

- Non-root user execution (PUID/PGID)
- Read-only filesystem
- No-new-privileges security option
- Custom healthcheck script
- Proper resource limits

## Access

After deployment, OmniRoute is accessible at:

- **Dashboard**: http://localhost:20128
- **API**: http://localhost:20128/v1

## License

MIT

## Author Information

LocalNet Project
