# Security & Identity Services

This domain manages authentication, authorization, intrusion detection, and network security controls.

## Packages

- **authelia** — [Authelia](https://www.authelia.com/) provides Single Sign-On (SSO) and Two-Factor Authentication (2FA) for protected services.
- **crowdsec** — [CrowdSec](https://crowdsec.net/) offers collaborative intrusion detection and prevention, protecting exposed services (like Traefik) from attacks.
- **egress-firewall** — A custom NFTables-based firewall ensuring strict outbound traffic control (allowlisting) for sensitive workloads.
- **dockerproxy** — [Socket Proxy](https://github.com/wollomatic/socket-proxy) (read-only and read-write variants) secures the Docker socket, limiting access to only authorized containers (e.g., Traefik, Watchtower).
- **watchtower** — [Watchtower](https://containrrr.dev/watchtower/) automates container base image updates.
- **frpc** — [FRP Client](https://github.com/fatedier/frp) for exposing local services to the internet securely via a reverse proxy tunnel.

## Compose file

`docker-compose.security.yml` defines the core security stack:

- **Authelia** and its backing Redis database for SSO/2FA.
- **CrowdSec** and dashboards for intrusion detection and banning.
- **Docker socket proxies** (read-only/read-write) used by Traefik and Watchtower.
- **Watchtower** for automated image updates.
- **FRPC** for outbound reverse-tunnel publishing.
- **Egress firewall container** (`localnet-security-egress-firewall`):
  - Runs with `NET_ADMIN` capability and `net.ipv4.ip_forward=1` to enforce container-level egress rules.
  - Uses `ALLOW_DESTINATIONS` (e.g. `api.github.com:443,cache.nixos.org:443`) as an allowlist for outbound traffic.
  - Supports `ENABLE_DNS` to allow internal DNS resolution and `DEBUG` for verbose logging.
