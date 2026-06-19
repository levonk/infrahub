# NordVPN Gateway Container

A Docker container running the official NordVPN Linux client with full VPN gateway capabilities.

## Features

- Official NordVPN Linux client on Debian Bookworm
- NordLynx technology for fast, secure connections
- Full NAT routing for external hosts
- Support for Docker containers, Tailscale, NetBird, and LAN devices
- Kill switch and firewall enabled by default
- Health check monitoring
- Security hardening with capability dropping

## Usage

### Environment Variables

- `VPN_NORDVPN_TOKEN`: Your NordVPN access token (required)
- `VPN_NORDVPN_COUNTRY`: Country to connect to (default: United_States)
- `TZ`: Timezone (default: UTC)

### Running with Docker Compose

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your NordVPN token
vim .env

# Start the container
docker compose up -d --build

# View logs
docker compose logs -f
```

### Using Just Commands

```bash
# Build the service
just build

# Start the service
just up

# View logs
just logs

# Run health check
just health-check

# Run tests
just test

# Stop the service
just down
```

### External Host Routing

The container acts as a full VPN router. External hosts can route traffic through it:

#### Tailscale Host
```bash
sudo ip route add 0.0.0.0/0 via <docker_host_ip>
```

#### NetBird Host
```bash
sudo ip route add 0.0.0.0/0 via <docker_host_ip>
```

#### LAN Host
Add a static route on your router:
```
0.0.0.0/0 → <docker_host_ip>
```

## Architecture

This container supports:
- Docker containers
- Tailscale devices
- NetBird devices
- LAN devices
- VMs
- KVM/libvirt guests
- Proxmox nodes

## Security

- Root execution required for NordVPN daemon and iptables operations
- Required capabilities: NET_ADMIN, NET_RAW
- Capability dropping: ALL dropped, only NET_ADMIN and NET_RAW added
- No new privileges: security_opt no-new-privileges:true
- TUN device access
- IP forwarding enabled
- NAT masquerading for external routing
- Health check monitoring

## Compliance

This service follows Docker Service Standards (ADR-20251218002):
- Uses localnet-base-debian base image
- Standard directory structure (assets/, healthcheck/, tests/)
- NX integration with project.json
- Justfile for build/run operations
- Environment variable naming convention: {CATEGORY}_{SERVICE}_{SUB_SERVICE}_{HOST|CONTAINER}_{PORT|IP}
