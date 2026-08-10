# nix-ncps

Ansible role that deploys **ncps** (Nix Caching Proxy Server) as a Docker container on a Windows Docker Desktop host (dtop202311, X86). ncps is the front-door NAR caching proxy — Nix clients point to ncps, which caches NARs locally and queries ncro (the parallel racing proxy behind it) on miss.

| Host | OS | Arch | Network | Domain |
|------|----|------|---------|--------|
| Windows Docker Desktop (`windows_docker_hosts`, dtop202311) | Windows | X86 | joins `traefik-windows-network` | `{{ infra_domain_nix_cache_nl }}` |

Implements ADR-20260708001: ncps on regional hubs.

## Deployment path

`tasks/deploy-windows.yml` uses `ansible.builtin.shell` with `DOCKER_HOST: ssh://...` and `delegate_to: localhost` (the `ai-qm` / `verdaccio` pattern). `community.docker` modules cannot run on Windows because Ansible's `basic.py` imports `grp` (Unix-only). Config files are rendered locally and copied into a Docker config volume via a helper `alpine` container. The container joins `traefik-windows-network` for Traefik routing.

The target is selected by inventory group membership in `tasks/main.yml`:

- `windows_docker_hosts` → `deploy-windows.yml`

## Key variables

| Variable | Default | Source |
|----------|---------|--------|
| `nix_ncps_container_name` | `localnet-nix-ncps` | `infra_hostname_nix_ncps` |
| `nix_ncps_image_name` | `localnet-nix-ncps` | — |
| `nix_ncps_image_tag` | `latest` | — |
| `nix_ncps_host_port` | `4524` | `infra_port_nix_ncps_host` |
| `nix_ncps_container_port` | `8080` | `infra_port_nix_ncps_container` |
| `nix_ncps_domain` | `{{ infra_domain_nix_cache_nl }}` | `infra_domain_nix_cache_nl` |
| `nix_ncps_network_name` | `traefik-windows-network` | — |
| `nix_ncps_data_volume` | `localnet-ncps-data-volume` | `infra_storage_nix_ncps_data_volume` |
| `nix_ncps_config_volume` | `localnet-ncps-config-volume` | `infra_storage_nix_ncps_config_volume` |
| `nix_ncps_docker_host_windows` | `ssh://ansible@dtop202311.<tailnet>` | `infra_tailscale_fqdn_windows_docker` |
| `nix_ncps_ncro_url` | `http://localnet-nix-ncro:8081` | `nix_ncro_container_name`, `infra_port_nix_ncro_container` |

All ports, domains, and volume names reference `infra_*` infrastructure variables — no hardcoding.

## Upstream chain

ncps queries ncro on miss. ncro is the parallel racing proxy that fans out to all upstream Nix caches. The upstream chain is defined in `nix_ncps_upstreams`:

```yaml
nix_ncps_upstreams:
  - url: "http://localnet-nix-ncro:8081"
    priority: 20
```

## Healthcheck

ncps exposes a `/healthz` endpoint:

```
wget -qO- http://127.0.0.1:8080/healthz || exit 1
```

Healthcheck interval/timeout/start_period are strings with unit suffixes (`"30s"`) per the `community.docker` parameter rules in `AGENTS.md`.

## Usage

This role is intended to be included from a playbook. Example:

```yaml
- hosts: windows_docker_hosts
  roles:
    - role: nix-ncps
```

Tags: `validate`, `deploy`, `config`, `volume`, `pull`, `container`, `info`.
