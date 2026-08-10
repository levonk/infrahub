# artifact-verdaccio

Ansible role that deploys [Verdaccio](https://verdaccio.org/) — a private npm registry and proxy cache — as two independent instances:

| Instance | Host | OS | Arch | Network | Domain |
|----------|------|----|------|---------|--------|
| **cno** | OCI cloud server (`cloud_servers`) | Oracle Linux (EL) | ARM64 | joins `traefik-network` | `npmjs.cno.<base>` |
| **nl** | Windows Docker Desktop (`windows_docker_hosts`, dtop202311) | Windows | X86 | standalone (published port) | `npmjs.nl.<base>` |

The upstream multi-arch image `verdaccio/verdaccio:latest` is used (no custom build). Ansible renders `config.yaml` and `htpasswd` from Jinja2 templates.

## Deployment paths

- **Linux (cno)** — `tasks/deploy-linux.yml` uses `community.docker` modules (`docker_container`, `docker_volume`, `docker_image`). The container joins the Traefik network so the OCI Traefik instance routes `npmjs.cno.<base>` directly.
- **Windows (nl)** — `tasks/deploy-windows.yml` uses `ansible.builtin.shell` with `DOCKER_HOST: ssh://...` and `delegate_to: localhost` (the `ai-qm` pattern). `community.docker` modules cannot run on Windows because Ansible's `basic.py` imports `grp` (Unix-only). Config files are rendered locally and copied into a Docker config volume via a helper `alpine` container. The nl instance is standalone — Traefik on OCI routes `npmjs.nl.<base>` to the Windows host's Tailscale FQDN + published port cross-machine.

The target is selected by inventory group membership in `tasks/main.yml`:

- `cloud_servers` (or `ansible_os_family == "RedHat"`) → `deploy-linux.yml`
- `windows_docker_hosts` → `deploy-windows.yml`

## Key variables

| Variable | Default | Source |
|----------|---------|--------|
| `verdaccio_container_name_cno` | `localnet-artifact-verdaccio` | `infra_hostname_verdaccio_cno` |
| `verdaccio_container_name_nl` | `localnet-artifact-verdaccio-nl` | `infra_hostname_verdaccio_nl` |
| `verdaccio_image_name` | `verdaccio/verdaccio` | — |
| `verdaccio_image_tag` | `latest` | — |
| `verdaccio_host_port` | `4873` | `infra_port_artifact_verdaccio_host` |
| `verdaccio_container_port` | `4873` | `infra_port_artifact_verdaccio_container` |
| `verdaccio_domain_cno` | `npmjs.cno.<base>` | `infra_domain_artifact_verdaccio_cno` |
| `verdaccio_domain_nl` | `npmjs.nl.<base>` | `infra_domain_artifact_verdaccio_nl` |
| `verdaccio_network_name_cno` | `traefik-network` | `infra_network_proxy_traefik_network_name` |
| `verdaccio_data_volume` | `localnet-verdaccio-data-volume` | `infra_storage_verdaccio_data_volume` |
| `verdaccio_config_volume` | `localnet-verdaccio-config-volume` | `infra_storage_verdaccio_config_volume` |
| `verdaccio_admin_username` | `levonk-admin` | `vault_verdaccio_admin_username` |
| `verdaccio_admin_password` | (empty) | `vault_verdaccio_admin_password` |
| `verdaccio_docker_host_windows` | `ssh://ansible@dtop202311.<tailnet>` | `infra_tailscale_fqdn_windows_docker` |

All IPs, ports, domains, and volume names reference `infra_*` infrastructure variables — no hardcoding.

## Secrets

The admin password is read from `vault_verdaccio_admin_password`. When the vault is not yet populated, the `htpasswd.j2` template renders a locked placeholder (`!!locked-no-password-set`) so the file is valid but login is impossible. Add the secret via the vault handoff workflow described in the root `AGENTS.md`.

## Healthcheck

Both instances use the Verdaccio `/-/ping` endpoint:

```
wget -qO- http://127.0.0.1:4873/-/ping || exit 1
```

Healthcheck interval/timeout/start_period are strings with unit suffixes (`"30s"`) per the `community.docker` parameter rules in `AGENTS.md`.

## Usage

This role is intended to be included from a playbook (story 01-006). Example:

```yaml
- hosts: cloud_servers
  roles:
    - role: artifact-verdaccio

- hosts: windows_docker_hosts
  roles:
    - role: artifact-verdaccio
```

Tags: `validate`, `deploy`, `config`, `volume`, `pull`, `container`, `info`.
