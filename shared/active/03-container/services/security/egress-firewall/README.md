# Egress Firewall Sidecar

A minimal, Nix-built container acting as a secure gateway for other containers or networks. It provides outbound traffic restriction, transparent MITM proxying, and DNS routing.

## Features
- **Minimal Footprint**: Built with Nix `dockerTools.buildLayeredImage`.
- **Egress Filtering**: Define allowed destinations via environment variables.
- **Transparent MITM**: Optional `mitmproxy` interception for HTTP/HTTPS (port 80/443).
- **DNS Routing**: Transparently route DNS queries to a specific upstream (e.g., AdGuard).
- **Sidecar & Gateway Mode**: Works via `network_mode: service:...` or as a gateway for a subnet.

## Building the Image

```bash
nix build .#
docker load < result
# Tag: egress-firewall:latest
```

## Configuration

| Environment Variable | Description | Default |
|----------------------|-------------|---------|
| `ALLOW_DESTINATIONS` | Comma-separated list of `host:port` or `host`. | (empty) |
| `ENABLE_DNS` | `true` or `false`. Allow outbound DNS (53). | `true` |
| `DNS_SERVER` | IP address of upstream DNS. **Forces** DNAT of all port 53 traffic to this IP. | (empty) |
| `ENABLE_MITM` | `true` or `false`. Enable transparent HTTP/HTTPS interception. | `false` |
| `MITM_OPTS` | Additional arguments for `mitmdump`. | (empty) |
| `DEBUG` | `true` or `false`. Verbose logging. | `false` |

## Usage Examples

### 1. Locked-down Sidecar
Protect a single container (e.g., test runner) and inspect its traffic.

```yaml
services:
  firewall:
    image: egress-firewall:latest
    cap_add: [NET_ADMIN]
    environment:
      - ALLOW_DESTINATIONS=api.github.com:443
      - ENABLE_MITM=true
      - DNS_SERVER=10.0.0.53 # Point to AdGuard

  app:
    image: my-app
    network_mode: service:firewall
```

### 2. Network Gateway
Act as a gateway for a subnet or physical machines.

```yaml
services:
  gateway:
    image: egress-firewall:latest
    cap_add: [NET_ADMIN]
    sysctls:
      - net.ipv4.ip_forward=1
    networks:
      testing_net:
        ipv4_address: 172.20.0.1
    environment:
      - ALLOW_DESTINATIONS=google.com:443
      - ENABLE_MITM=true
```

## Logs & Observability
- **Firewall Logs**: Iptables drops are not logged by default in this minimal setup unless `LOG` target is added via custom scripts.
- **MITM Logs**: `mitmdump` logs request/response metadata to stdout when enabled.
- **Custom Rules**: Mount a script to `/etc/firewall/custom-rules.sh` for advanced iptables logic.

