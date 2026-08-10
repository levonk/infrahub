# nix-harmonia

Ansible role that deploys [Harmonia](https://github.com/nix-community/harmonia) — a Nix binary cache server that serves the local `/nix/store` over HTTP — as a Docker container on a Windows Docker Desktop host.

| Host | OS | Arch | Network | Access |
|------|----|------|---------|--------|
| dtop202311 (`windows_docker_hosts`) | Windows | X86 | joins `traefik-windows-network` | `127.0.0.1` only (local, not exposed externally) |

Harmonia reads `/nix/store` read-only and serves it over HTTP on `127.0.0.1` only. This implements ADR-20260708001: Harmonia on every Nix machine, enabling local binary cache lookups so Nix builds on the host can substitute from the local store without hitting upstream caches.

## Deployment path

`tasks/main.yml` uses `ansible.builtin.shell` with `DOCKER_HOST: ssh://...` and `delegate_to: localhost` (the `ai-qm` / `verdaccio` pattern). `community.docker` modules cannot run on Windows because Ansible's `basic.py` imports `grp` (Unix-only). The `harmonia.toml` config file is rendered locally and copied into the Harmonia data volume via a helper `alpine` container before the main container is started.

The container mounts three volumes:

- `{{ nix_harmonia_nix_store_volume }}` → `/nix/store:ro` — the shared Nix store (read-only)
- `{{ nix_harmonia_nix_config_volume }}` → `/etc/nix:ro` — shared Nix config (read-only)
- `{{ nix_harmonia_data_volume }}` → `/data:rw` — Harmonia state + signing key

The port is bound to `127.0.0.1` only so the cache is reachable from the host but not exposed externally.

## Key variables

| Variable | Default | Source |
|----------|---------|--------|
| `nix_harmonia_container_name` | `localnet-nix-harmonia` | `infra_hostname_nix_harmonia` |
| `nix_harmonia_image_name` | `localnet-nix-harmonia` | — |
| `nix_harmonia_image_tag` | `latest` | — |
| `nix_harmonia_host_port` | `4523` | `infra_port_nix_harmonia_host` |
| `nix_harmonia_container_port` | `5000` | `infra_port_nix_harmonia_container` |
| `nix_harmonia_nix_store_volume` | `localnet-base-nix-store-volume` | `infra_storage_nix_shared_store_volume` |
| `nix_harmonia_nix_config_volume` | `localnet-base-nix-config-volume` | `infra_storage_nix_shared_config_volume` |
| `nix_harmonia_data_volume` | `localnet-harmonia-data-volume` | `infra_storage_nix_harmonia_data_volume` |
| `nix_harmonia_network_name` | `traefik-windows-network` | — |
| `nix_harmonia_docker_host_windows` | `ssh://ansible@dtop202311.<tailnet>` | `infra_tailscale_fqdn_windows_docker` |

All ports and volume names reference `infra_*` infrastructure variables — no hardcoding.

## Secrets

The Harmonia signing key is read from `vault_nix_harmonia_sign_key`. When the vault variable is not defined or empty, Harmonia runs in read-only mode (serves the store but does not sign new paths). Add the secret via the vault handoff workflow described in the root `AGENTS.md`:

```bash
docker run --rm -it \
  -v "$HOME/.ansible/vault_password:/vault_password:ro" \
  -v "$HOME/p/gh/levonk/infrahub/levonk/active/02-config/ansible/inventories/group_vars:/vault-dir" \
  -e EDITOR=vi \
  alpine/ansible:latest \
  ansible-vault edit /vault-dir/infrahub-levonk-all.vault.yml --vault-password-file /vault_password
```

Add the line: `vault_nix_harmonia_sign_key: "<your-signing-key-content>"`

## Healthcheck

The container uses the Harmonia `nix-cache-info` endpoint:

```
wget -qO- http://127.0.0.1:5000/nix-cache-info || exit 1
```

Healthcheck interval/timeout/start_period are strings with unit suffixes (`"30s"`) per the `community.docker` parameter rules in `AGENTS.md`.

## Usage

This role is intended to be included from a playbook. Example:

```yaml
- hosts: windows_docker_hosts
  roles:
    - role: nix-harmonia
```

Tags: `validate`, `deploy`, `config`, `volume`, `pull`, `container`, `info`.
