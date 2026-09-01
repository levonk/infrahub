# storage-copyparty

Deploys [copyparty](https://github.com/9001/copyparty) — a portable, self-hosted
HTTP file sharing server with resumable chunked uploads, deduplication, media
indexing/thumbnails, search, and WebDAV.

## Requirements

- Docker engine with userns-remap enabled
- The `traefik-network` Docker network (created by the `proxy-traefik` role)
- `community.docker` Ansible collection

## Variables

| Variable | Default | Description |
|---|---|---|
| `copyparty_enabled` | `true` | Enable the role |
| `copyparty_container_name` | `copyparty` | Docker container name |
| `copyparty_image` | `copyparty/iv` | Upstream image (iv = full media indexing) |
| `copyparty_image_tag` | `latest` | Image tag |
| `copyparty_host_port` | `3923` | Host port (refs `infra_port_storage_copyparty_host`) |
| `copyparty_container_port` | `3923` | Container port (refs `infra_port_storage_copyparty_container`) |
| `copyparty_network_name` | `traefik-network` | Docker network (refs `infra_network_proxy_traefik_network_name`) |
| `copyparty_domain` | `files.<base>` | Traefik domain (refs `infra_domain_storage_copyparty`) |
| `copyparty_data_volume` | `localnet-copyparty-data-volume` | Docker volume mounted at `/w` |
| `copyparty_config_dir` | `/opt/localnet/services/copyparty` | Bind-mounted config dir mounted at `/cfg` |
| `copyparty_admin_password` | `""` | Admin password (from `vault_copyparty_admin_password`) |
| `copyparty_verify_health` | `true` | Run post-deploy health probe |
| `copyparty_healthcheck_interval` | `30s` | Healthcheck interval (string with unit) |
| `copyparty_healthcheck_timeout` | `10s` | Healthcheck timeout (string with unit) |
| `copyparty_healthcheck_start_period` | `30s` | Healthcheck start period (string with unit) |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: storage-copyparty
```

## Volumes

The role serves three shares under `/w` (the data Docker volume):

| URL path | Container path | Access |
|---|---|---|
| `/public` | `/w/public` | anonymous read |
| `/uploads` | `/w/uploads` | anonymous write-only |
| `/family` | `/w/family` | admin read/write/move/delete |

Configuration is rendered to `{{ copyparty_config_dir }}/copyparty.conf` and
bind-mounted at `/cfg` inside the container. The `PRTY_CONFIG` env var points
copyparty at `/cfg/copyparty.conf`.

## Monitoring

copyparty does not expose a dedicated `/health` endpoint. The container
healthcheck and the role's `copyparty_verify_health` task probe `GET /` on the
container port (returns `200` when up, `401` if auth is required on the root).
No Prometheus metrics endpoint is exposed by default.

## Backup

Shared files live in the `copyparty_data_volume` Docker volume (plain files).
The SQLite index/thumbnails are kept under `/cfg/hists` inside the container
(bind-mounted config dir on the host). Back up both the data volume and the
config directory using standard Docker volume / directory backup procedures.
