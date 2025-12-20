# qBittorrent - VPN-routed file-xfer service (env-based ports)
# Generated from docker-nix boilerplate (materialized)

## Overview

VPN-routed BitTorrent client (qbittorrent-enhanced intent). Uses env-only port configuration with defaults in `env.template`.

This service is built using **Nix** to generate reproducible, minimal Docker images. It features a unique "Dual Image" workflow to solve the "distroless debugging" problem.

## The "Twist": Prod vs. Debug Images

We generate two images from the same source:

1.  **Production Image (`qbittorrent:latest`)**:
    *   **Content**: Contains *only* the application binary and its runtime dependencies (closure).
    *   **Size**: Extremely small.
    *   **Security**: Minimal attack surface (no shell, no package manager).
    *   **Use Case**: Production deployment.

2.  **Debug Image (`qbittorrent-debug:latest`)**:
    *   **Content**: The *exact same* application layer, plus a layer of debugging tools (`zsh`, `curl`, `htop`, `strace`, `vim`, etc.).
    *   **Use Case**: Local development, troubleshooting, and debugging.

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) (with flakes enabled)
- Docker
- Docker Compose

### Build and Run

```bash
# 1. Build the Production Image (optional; falls back to upstream image)
make build

# 2. Start the service
make up

# 3. Check health
make health-check
```

### Debugging

If you run into issues, build and run the debug image:

```bash
# 1. Build the Debug Image (optional)
make build-debug

# 2. Run it interactively (example)
docker run -it --rm qbittorrent-debug zsh
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `qbittorrent` |
| `SERVICE_PORT` | Port the service listens on (container) | `${QBIT_WEB_CONTAINER_PORT:-8701}` |
| `QBIT_WEB_HOST_PORT` | Host port for WebUI | `8701` |
| `QBIT_TORRENT_HOST_PORT_TCP` | Host TCP torrent port | `6881` |
| `QBIT_TORRENT_HOST_PORT_UDP` | Host UDP torrent port | `6881` |
| `QBIT_TORRENT_CONTAINER_PORT` | Container torrent port | `6881` |
| `NODE_ENV` | Environment | `production` |

## Build System

The `Makefile` wraps Nix commands for convenience:

- `make build`: Builds `.#docker-prod` and loads it into Docker.
- `make build-debug`: Builds `.#docker-debug` and loads it into Docker.
- `make up`: Runs `docker compose up`.

## Project Structure

- `flake.nix`: Defines the Nix build outputs (app, prod image, debug image).
- `docker-compose.yml`: Orchestrates the service.
- `Makefile`: Helper commands.
