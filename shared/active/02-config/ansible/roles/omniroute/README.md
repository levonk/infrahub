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
6. **Status Report**: Reports deployment status and access URLs

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
