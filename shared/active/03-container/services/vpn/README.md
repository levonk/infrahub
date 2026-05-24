# VPN Services

This directory contains the VPN stack for Home Lab In-a-Box. It provides multiple ways to connect clients and services through the `localnet` environment, with a focus on observability and controlled egress.

## Services

- **Gluetun** (`localnet-vpn-gluetun`)
  - Upstream privacy VPN client based on `qmcgaw/gluetun`.
  - Exposes HTTP proxy, Shadowsocks, and various media automation ports.
  - Used as a general-purpose outbound privacy tunnel.

- **WireGuard Direct** (`localnet-vpn-direct`)
  - Standard WireGuard server (wg0) for clients that can access the internet directly.
  - Clients get access to the internet plus selected `localnet` resources.
  - Ports and peer counts are controlled via the `WIREGUARD_DIRECT_*` variables in the root `env.template`.

- **WireGuard Transparent** (`localnet-vpn-transparent`)
  - WireGuard server (wg1) for fully observed clients that must use `localnet` services.
  - Designed for managed or higher-risk devices that should not talk to the internet directly.
  - Uses the transparent gateway path and `WIREGUARD_TRANSPARENT_*` settings from `env.template`.

- **Netbird VPN client** (`localnet-vpn-netbird`)
  - Nix-built Netbird client image (`vpn-netbird:latest`).
  - Runs as a VPN client inside `localnet`, used for mesh-style connectivity.
  - HTTP admin/health endpoint is exposed only on the internal port configured via:
    - `VPN_NETBIRD_HTTP_CONTAINER_PORT`
    - `VPN_NETBIRD_HTTP_HOST_PORT`
  - Traefik routes `https://netbird.localnet` to this service using the internal HTTP port; no direct host port binding.

- **Tailscale VPN client** (`localnet-vpn-tailscale`)
  - Nix-built Tailscale client image (`vpn-tailscale:latest`).
  - Runs as a VPN client inside `localnet` for Tailscale-based connectivity.
  - HTTP admin/health endpoint is exposed only on the internal port configured via:
    - `VPN_TAILSCALE_HTTP_CONTAINER_PORT`
    - `VPN_TAILSCALE_HTTP_HOST_PORT`
  - Traefik routes `https://tailscale.localnet` to this service using the internal HTTP port; no direct host port binding.

## Compose and Makefile

- `docker-compose.vpn.yml` defines all VPN-related services (gluetun, WireGuard, Netbird, Tailscale).
- The top-level `env.template` in `apps/active/devops/localnet` is the **single source of truth** for all VPN-related ports and network settings.
- The local `Makefile` wraps common Docker Compose operations:
  - `make build` / `make up` / `make down` / `make restart`
  - `make status` / `make logs` / `make logs-follow`
  - `make health-check` / `make lint` / `make clean` / `make clean-all`.
