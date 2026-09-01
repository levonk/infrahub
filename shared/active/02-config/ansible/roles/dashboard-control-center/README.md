# dashboard-control-center

Ansible role that deploys the **Control Center** Next.js dashboard to Windows
Docker Desktop (host `dtop202311`) via `delegate_to: localhost` +
`DOCKER_HOST: ssh://`.

## Architecture

The Control Center is a Next.js application packaged as a Docker image
(`localnet-dashboard-control-center:latest`) and published to the local
registry. The role:

1. Validates required infrastructure variables.
2. Ensures the Docker data volume exists on the Windows Docker host.
3. Pulls the image from the local registry.
4. Removes any existing container (`docker rm -f`) and starts a fresh one
   (`docker run -d`) — this is the idempotent update pattern used because
   `community.docker` modules cannot run on Windows (Ansible's `basic.py`
   imports the Unix-only `grp` module).
5. Waits for the container's Docker healthcheck to report `healthy`.
6. Verifies the `/api/health` endpoint responds `200`.
7. Reports the final container status.

The container joins `traefik-windows-network` so Traefik routes
`dashboard.<base>` and `dashboard.nl.<base>` to it.

## Variables

All variables are defined in `defaults/main.yml` and resolve to `infra_*`
infrastructure variables. Key variables:

| Variable | Default |
|----------|---------|
| `control_center_enabled` | `true` |
| `control_center_container_name` | `infra_hostname_dashboard_control_center` |
| `control_center_image_name` | `{{ local_registry }}/localnet-dashboard-control-center` |
| `control_center_image_tag` | `latest` |
| `control_center_host_port` | `infra_port_dashboard_control_center_host` |
| `control_center_container_port` | `infra_port_dashboard_control_center_container` |
| `control_center_domain` | `dashboard.nl.<base>` |
| `control_center_domain_default` | `dashboard.<base>` |
| `control_center_data_volume` | `infra_storage_control_center_data_volume` |
| `control_center_data_dir` | `/data` |
| `control_center_network_name` | `traefik-windows-network` |
| `control_center_verify_health` | `true` |

## Tags

- `deploy`, `control-center` — deployment tasks
- `validate`, `control-center` — health verification tasks
- `always`, `info`, `control-center` — status reporting

## Deployment

```bash
just ansible-deploy-dashboard-control-center
```

Or directly:

```bash
devbox run -- rtk ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  playbooks/deploy-dashboard-control-center.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Backup & Restore

The Control Center persists runtime state in the `control_center_data_volume`
Docker volume (mounted at `/data`). Back up and restore it with an ephemeral
alpine container that mounts the volume and the host `/tmp` directory.

### Backup

```bash
docker run --rm \
  -v {{ control_center_data_volume }}:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/control-center-$(date +%Y%m%d).tar.gz /data
```

Set `DOCKER_HOST` to the Windows Docker host when running remotely:

```bash
DOCKER_HOST="{{ control_center_docker_host_windows }}" \
docker run --rm \
  -v {{ control_center_data_volume }}:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/control-center-$(date +%Y%m%d).tar.gz /data
```

### Restore

```bash
docker run --rm \
  -v {{ control_center_data_volume }}:/data \
  -v /tmp:/backup \
  alpine tar xzf /backup/control-center-YYYYMMDD.tar.gz -C /
```

Replace `YYYYMMDD` with the date suffix of the backup archive. After
restoring, redeploy the container so it picks up the restored data:

```bash
just ansible-deploy-dashboard-control-center
```
