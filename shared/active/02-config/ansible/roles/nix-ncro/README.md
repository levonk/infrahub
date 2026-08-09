# nix-ncro

Ansible role that deploys **ncro** (Nix Cache Route Optimizer) as a Docker container on a Windows Docker Desktop host (`dtop202311`, X86). ncro sits behind ncps and races all upstream Nix caches in parallel, returning the fastest response. It is **stateless** — no NAR storage (ncps handles caching). Routing decisions are cached in SQLite for fast subsequent lookups.

Upstream: https://github.com/manic-systems/ncro

Implements ADR-20260708001: ncro on regional hubs.

## Deployment path

- **Windows (dtop202311)** — `tasks/main.yml` uses `ansible.builtin.shell` with `DOCKER_HOST: ssh://...` and `delegate_to: localhost` (the verdaccio-nl pattern). `community.docker` modules cannot run on Windows because Ansible's `basic.py` imports `grp` (Unix-only). The config file (`config.toml`) is rendered locally and copied into a Docker config volume via a helper `alpine` container.

ncro is **internal only** — the published port binds to `127.0.0.1` so it is reachable only from the host and the `traefik-windows-network` Docker network. ncps (the caching proxy) forwards to ncro; ncro races the upstreams.

## Upstream caches

ncro races these upstreams in parallel (defined in `defaults/main.yml`):

1. `local-harmonia` — local Harmonia instance (sub-millisecond for local store hits)
2. `cache.nixos.org`
3. `cache.garnix.io`
4. `nix-community.cachix.org`

## Key variables

| Variable | Default | Source |
|----------|---------|--------|
| `nix_ncro_container_name` | `localnet-nix-ncro` | `infra_hostname_nix_ncro` |
| `nix_ncro_image_name` | `localnet-nix-ncro` | — |
| `nix_ncro_image_tag` | `latest` | — |
| `nix_ncro_host_port` | `4525` | `infra_port_nix_ncro_host` |
| `nix_ncro_container_port` | `8081` | `infra_port_nix_ncro_container` |
| `nix_ncro_config_volume` | `localnet-ncro-config-volume` | — |
| `nix_ncro_network_name` | `traefik-windows-network` | — |
| `nix_ncro_docker_host_windows` | `ssh://ansible@dtop202311.tale-grouper.ts.net` | `infra_tailscale_fqdn_windows_docker` |

All ports reference `infra_*` infrastructure variables — no hardcoding.

## Healthcheck

ncro exposes a `/health` endpoint:

```
wget -qO- http://127.0.0.1:8081/health || exit 1
```

Healthcheck interval/timeout/start_period are strings with unit suffixes (`"30s"`) per the `community.docker` parameter rules in `AGENTS.md`.

## Usage

This role is intended to be included from a playbook. Example:

```yaml
- hosts: windows_docker_hosts
  roles:
    - role: nix-ncro
```

Tags: `validate`, `deploy`, `config`, `volume`, `pull`, `container`, `info`.
