# garnix-ci

Ansible role that deploys **garnix-ci** — a Nix-based CI builder — as a Docker container on a Windows Docker Desktop host (`windows_docker_hosts`, dtop202311, X86).

## Key features

- **Shared nix store reuse** — mounts the shared nix-sidecar volumes (`/nix/store`, `/etc/nix`, `/root/.cache/nix`) so Nix builds reuse already-downloaded packages instead of re-downloading from `cache.nixos.org`.
- **`/dev/kvm` passthrough** — passes `/dev/kvm` into the container for nested virtualization (NixOS VM builds). Uses `--device /dev/kvm` (not `--privileged`) for least-privilege access.
- **Local cache chain** — Nix substituters point to the local cache chain (Harmonia + ncps) first, then fall back to `cache.nixos.org` and `cache.garnix.io`.
- **Traefik routing** — joins the `traefik-windows-network` so the Windows Traefik instance routes `ci.nl.levonk.com` to the Web UI.

## Prerequisites

**WSL2 KVM must be enabled before deploying this role.** Run the `enable-wsl2-kvm.yml` playbook first so `/dev/kvm` is available inside Docker Desktop containers. The role validates `/dev/kvm` availability and fails fast if it is missing.

The shared nix-sidecar volumes (`localnet-base-nix-store-volume`, `localnet-base-nix-config-volume`, `localnet-base-nix-cache-volume`) must already exist — they are created by the nix-sidecar role and are mounted read-write so garnix-ci builds can add to the shared store.

## Deployment path

`tasks/main.yml` uses `ansible.builtin.shell` with `DOCKER_HOST: ssh://...` and `delegate_to: localhost` (the `verdaccio` nl pattern). `community.docker` modules cannot run on Windows because Ansible's `basic.py` imports `grp` (Unix-only). The `nix.conf` is rendered locally and copied into the garnix-ci config volume via a helper `alpine` container.

## Key variables

| Variable | Default | Source |
|----------|---------|--------|
| `garnix_ci_container_name` | `localnet-garnix-ci` | `infra_hostname_garnix_ci` |
| `garnix_ci_image_name` | `localnet-garnix-ci` | — |
| `garnix_ci_image_tag` | `latest` | — |
| `garnix_ci_web_host_port` | `4526` | `infra_port_garnix_ci_web_host` |
| `garnix_ci_web_container_port` | `3000` | `infra_port_garnix_ci_web_container` |
| `garnix_ci_api_host_port` | `4527` | `infra_port_garnix_ci_api_host` |
| `garnix_ci_api_container_port` | `8080` | `infra_port_garnix_ci_api_container` |
| `garnix_ci_domain` | `ci.nl.levonk.com` | `infra_domain_garnix_ci_nl` |
| `garnix_ci_network_name` | `traefik-windows-network` | — |
| `garnix_ci_nix_store_volume` | `localnet-base-nix-store-volume` | `infra_storage_nix_shared_store_volume` |
| `garnix_ci_nix_config_volume` | `localnet-base-nix-config-volume` | `infra_storage_nix_shared_config_volume` |
| `garnix_ci_nix_cache_volume` | `localnet-base-nix-cache-volume` | `infra_storage_nix_shared_cache_volume` |
| `garnix_ci_work_volume` | `localnet-garnix-ci-work-volume` | `infra_storage_garnix_ci_work_volume` |
| `garnix_ci_config_volume` | `localnet-garnix-ci-config-volume` | `infra_storage_garnix_ci_config_volume` |
| `garnix_ci_kvm_device` | `/dev/kvm` | — |
| `garnix_ci_docker_host_windows` | `ssh://ansible@dtop202311.tale-grouper.ts.net` | `infra_tailscale_fqdn_windows_docker` |

All IPs, ports, domains, and volume names reference `infra_*` infrastructure variables — no hardcoding.

## Substituters

The `nix.conf` rendered by `templates/nix.conf.j2` points Nix at the local cache chain:

1. `http://127.0.0.1:4523` — Harmonia (local binary cache on the host)
2. `http://localnet-nix-ncps:8080` — ncps (Nix caching proxy service on the Docker network)
3. `https://cache.nixos.org` — upstream NixOS cache (fallback)
4. `https://cache.garnix.io` — garnix upstream cache (fallback)

Trusted public keys cover all four substituters.

## Healthcheck

Uses the garnix-ci Web UI root endpoint:

```
wget -qO- http://127.0.0.1:3000/ || exit 1
```

Healthcheck interval/timeout/start_period are strings with unit suffixes (`"60s"`) per the `community.docker` parameter rules in `AGENTS.md`.

## Usage

This role is intended to be included from a playbook targeting the `windows_docker_hosts` group:

```yaml
- hosts: windows_docker_hosts
  roles:
    - role: garnix-ci
```

Tags: `validate`, `deploy`, `config`, `volume`, `pull`, `container`, `info`.
