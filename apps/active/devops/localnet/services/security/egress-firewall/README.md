# Egress Firewall Sidecar

A minimal, Nix-built container designed to act as a network sidecar to restrict outbound traffic for other containers.

## Features
- **Minimal Footprint**: Built with Nix `dockerTools.buildLayeredImage` (no full OS overhead).
- **Configurable**: Define allowed outbound destinations via Environment Variables.
- **Sidecar Ready**: Designed to share network namespace with other services.
- **Secure**: Default DENY policy for egress.

## Building the Image

This project uses Nix Flakes.

```bash
# Build the Docker image tarball
nix build .#

# Load into Docker
docker load < result
```

The image will be tagged `egress-firewall:latest`.

## Usage with Docker Compose

To protect another service (e.g., `my-app`), run this container and make `my-app` use its network.

### `docker-compose.yml` Example

```yaml
services:
  # The Firewall Sidecar
  firewall:
    image: egress-firewall:latest
    container_name: egress-firewall
    cap_add:
      - NET_ADMIN # Required for iptables
    environment:
      # Format: host:port, host (all ports), ip:port
      - ALLOW_DESTINATIONS=api.github.com:443, 1.1.1.1:53
      - ENABLE_DNS=true # Defaults to true, allows outbound UDP/TCP 53 to system nameservers
      - DEBUG=true
    sysctls:
      - net.ipv4.ip_forward=1 # Often helpful if routing, but strictly sidecar might not need it

  # The Protected Application
  my-app:
    image: alpine:latest
    command: sh -c "apk add curl && curl -v https://api.github.com"
    network_mode: service:firewall # Share network stack with firewall
    depends_on:
      - firewall
```

## Configuration

| Environment Variable | Description | Default |
|----------------------|-------------|---------|
| `ALLOW_DESTINATIONS` | Comma-separated list of `host:port` or `host`. | (empty) |
| `ENABLE_DNS` | `true` or `false`. Automatically allows outbound traffic to nameservers listed in `/etc/resolv.conf`. | `true` |
| `DEBUG` | `true` or `false`. Enables verbose logging. | `false` |

## Custom Rules

If you need complex rules not covered by the environment variables, you can mount a script to `/etc/firewall/custom-rules.sh`.

```yaml
    volumes:
      - ./my-custom-rules.sh:/etc/firewall/custom-rules.sh
```

This script will be executed *before* the default DROP policy is applied.
