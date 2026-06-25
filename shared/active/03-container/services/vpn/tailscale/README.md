# Tailscale VPN - Nix-based Docker Service
# Generated from boilerplate template

## Overview

Tailscale VPN Client with multiple exit node configurations:
- Direct Oracle Cloud exit node (fast)
- NordVPN-routed exit node (private)
- Tor-routed exit node (anonymous)

This service is built using **Nix** to generate reproducible, minimal Docker images. It features a unique "Dual Image" workflow to solve the "distroless debugging" problem.

## The "Twist": Prod vs. Debug Images

We generate two images from the same source:

1.  **Production Image (`vpn-tailscale:latest`)**:
    *   **Content**: Contains *only* the application binary and its runtime dependencies (closure).
    *   **Size**: Extremely small.
    *   **Security**: Minimal attack surface (no shell, no package manager).
    *   **Use Case**: Production deployment.

2.  **Debug Image (`vpn-tailscale-debug:latest`)**:
    *   **Content**: The *exact same* application layer, plus a layer of debugging tools (`zsh`, `curl`, `htop`, `strace`, `vim`, etc.).
    *   **Use Case**: Local development, troubleshooting, and debugging.

## Exit Node Configurations

### 1. Direct Exit Node (Default)
- **Configuration**: Standard Tailscale deployment
- **Routing**: Direct Oracle Cloud connection
- **Performance**: Fast, low latency
- **Privacy**: Oracle Cloud IP visible
- **Use Case**: Regular browsing, development

### 2. NordVPN Exit Node
- **Configuration**: Tailscale container routed through NordVPN
- **Routing**: NordVPN → Internet
- **Performance**: Good (VPN overhead)
- **Privacy**: NordVPN IP visible
- **Use Case**: Privacy-sensitive operations

### 3. Tor Exit Node (NEW)
- **Configuration**: Tailscale container routed through Tor
- **Routing**: Tor network → Internet
- **Performance**: Slower (multi-hop)
- **Privacy**: Tor exit IP visible, maximum anonymity
- **Use Case**: High-anonymity requirements
- **Configuration File**: `docker-compose.tor.yml`

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) (with flakes enabled)
- Docker
- Docker Compose
- Tailscale auth key

### Standard Deployment

```bash
# 1. Build the Production Image
make build

# 2. Start the service
make up

# 3. Check health
make health-check
```

### Tor-Enhanced Deployment

```bash
# 1. Copy environment file
cp env.tor.example .env

# 2. Configure your Tailscale auth key
export TS_AUTHKEY=your-tailscale-auth-key

# 3. Start Tor and Tailscale
docker-compose -f docker-compose.tor.yml up -d

# 4. Check status
docker-compose -f docker-compose.tor.yml ps
docker-compose -f docker-compose.tor.yml logs -f
```

### Debugging

If you run into issues, build and run the debug image:

```bash
# 1. Build the Debug Image
make build-debug

# 2. Run it interactively (example)
docker run -it --rm vpn-tailscale-debug zsh
```

## Configuration

### Standard Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `vpn-tailscale` |
| `SERVICE_PORT` | Port the service listens on | `8085` |
| `NODE_ENV` | Environment | `production` |

### Tor Integration Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TS_AUTHKEY` | Tailscale authentication key | Required |
| `TS_HOSTNAME` | Tailscale hostname | `oci-vpn-server-tor` |
| `TOR_EXIT_NODE_ENABLED` | Enable Tor exit node | `false` |
| `TOR_NICKNAME` | Tor relay nickname | `levonk-tor-exit` |
| `TOR_EXIT_POLICY` | Tor exit policy | `reject *:*` |
| `TOR_BANDWIDTH_RATE` | Tor bandwidth limit | `100 KB` |

## Build System

The `Makefile` wraps Nix commands for convenience:

- `make build`: Builds `.#docker-prod` and loads it into Docker.
- `make build-debug`: Builds `.#docker-debug` and loads it into Docker.
- `make up`: Runs `docker-compose up`.

## Project Structure

- `flake.nix`: Defines the Nix build outputs (app, prod image, debug image).
- `docker-compose.yml`: Standard Tailscale service.
- `docker-compose.tor.yml`: Tailscale-over-Tor configuration.
- `env.tor.example`: Tor integration environment template.
- `Makefile`: Helper commands.

## Multi-Exit Node Architecture

The Levonk infrastructure supports three exit node options:

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Devices                            │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │  Direct │ │ NordVPN  │ │    Tor   │
   │  Exit   │ │  Exit    │ │  Exit    │
   └────┬────┘ └────┬─────┘ └────┬─────┘
        │           │            │
        ▼           ▼            ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │ Oracle  │ │ NordVPN  │ │   Tor    │
   │ Cloud   │ │  Tunnel  │ │ Network  │
   └─────────┘ └──────────┘ └──────────┘
```

### Client Usage

```bash
# Direct exit node (fast)
sudo tailscale up --exit-node=oci

# NordVPN exit node (private)
sudo tailscale up --exit-node=oci-vpn-server-nordvpn

# Tor exit node (anonymous)
sudo tailscale up --exit-node=oci-vpn-server-tor
```

## Troubleshooting

### Tor Integration Issues

1. **Tailscale can't connect through Tor**

   ```bash
   # Check Tor is running
   docker logs tor-exit

   # Verify SOCKS proxy
   docker exec tor-exit curl --socks5 127.0.0.1:9050 https://check.torproject.org

   # Check Tailscale logs
   docker logs tailscale-tor
   ```

2. **High latency with Tor exit**

   ```bash
   # This is expected - Tor adds multiple hops
   # Consider using NordVPN exit for better performance
   ```

3. **Exit node not advertised**

   ```bash
   # Check Tailscale status
   docker exec tailscale-tor tailscale status

   # Verify exit node flag
   docker exec tailscale-tor tailscale status --json | grep exitNode
   ```

## Security Considerations

### Tor Exit Node Warnings

- Running Tor exit nodes has legal implications
- Monitor for abuse reports
- Use conservative exit policies
- Keep Tor updated regularly
- Understand your hosting provider's policies

### Tailscale Security

- Use strong auth keys
- Rotate auth keys regularly
- Configure ACLs in Tailscale admin console
- Monitor connected devices
- Use exit node approval

## Contributing

- Follow the established patterns
- Add tests for new features
- Update documentation
- Ensure security best practices
- Test all exit node configurations

## License

See LICENSE file in the project root.
