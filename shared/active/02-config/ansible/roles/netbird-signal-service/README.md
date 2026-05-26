# NetBird Signal Service Ansible Role

This Ansible role deploys the NetBird signal service (NAT traversal helper) as a Docker container.

## Requirements

- Docker installed on target host
- Docker community collection (`community.docker`)
- LocalNet common role dependencies

## Role Variables

### Default Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `netbird_signal_container_name` | `localnet-netbird-signal` | Container name |
| `netbird_signal_image_name` | `netbirdio/signal:latest` | Docker image name |
| `netbird_signal_host_port` | `33074` | Host port mapping (MUST BE VARIABLE) |
| `netbird_signal_container_port` | `33074` | Container port (MUST BE VARIABLE) |
| `netbird_signal_log_level` | `info` | Logging level |

### Required Variables

These variables must be defined in group_vars/all.yml or playbook:

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
- name: Deploy NetBird Signal Service
  hosts: cloud_vps
  become: true
  roles:
    - netbird-signal-service
  vars:
    localnet_services_dir: /opt/localnet/services
    localnet_network_name: localnet
    localnet_puid: 1000
    localnet_pgid: 1000
    localnet_tz: UTC
    netbird_signal_host_port: "{{ netbird_signal_host_port }}"
    netbird_signal_container_port: "{{ netbird_signal_container_port }}"
```

## Tasks

The role performs the following tasks:

1. **Directory Setup**: Creates the NetBird signal service directory
2. **Container Deployment**: Deploys the NetBird signal container with:
   - Port mapping (all ports as variables per localnet AGENTS.md)
   - Environment variables
   - Security options (no-new-privileges, read-only filesystem)
   - Healthcheck
3. **Health Verification**: Waits for the service to become healthy
4. **Status Report**: Reports deployment status

## Security Features

- Non-root user execution (PUID/PGID)
- Read-only filesystem
- No-new-privileges security option
- Proper resource limits
- All ports as variables (per localnet AGENTS.md)

## Important Notes

**CRITICAL**: All port numbers must be defined as variables in group_vars/all.yml per localnet AGENTS.md. No hardcoded ports allowed.

## License

MIT

## Author Information

LocalNet Project
