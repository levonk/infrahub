# 9Router Service - LocalNet

AI router and token saver for LLM providers with multi-tier fallback.

## Overview

9Router is a smart router that sits between your AI coding tools and LLM providers, providing:
- **RTK Token Saver**: Compress tool outputs to save 20-40% tokens
- **Smart 3-Tier Fallback**: Auto-route Subscription → Cheap → Free
- **Format Translation**: OpenAI ↔ Claude ↔ Gemini ↔ Cursor ↔ Kiro
- **Real-Time Quota Tracking**: Live token count and reset countdown
- **Multi-Account Support**: Load balancing across multiple accounts

## Quick Start

```bash
# Build the service
make build

# Start the service
make up

# View logs
make logs

# Stop the service
make down
```

## Configuration

Environment variables are configured in `.env`:

- `PUID`/`PGID`: User/group ID for the container (default: 1000)
- `PROXY_ROUTER_9ROUTER_HOST_PORT`: Host port (default: 20128)
- `PROXY_ROUTER_9ROUTER_CONTAINER_PORT`: Container port (default: 20128)
- `NODE_ENV`: Node environment (default: production)
- `DATA_DIR`: Data directory path (default: /app/data)

## Access

- **Dashboard**: http://localhost:20128/dashboard
- **API**: http://localhost:20128/v1

## Integration with LocalNet

This service is part of the LocalNet proxy services and integrates with the docker-compose.proxy.yml file.

## Security

- Runs as non-root user (UID/GID 1000)
- Read-only root filesystem
- Dropped all capabilities except NET_BIND_SERVICE
- No new privileges
- Resource limits configured

## Health Check

The service exposes a health check endpoint at `/health` that is monitored by Docker.

## Volumes

- `9router-data`: Persistent application data
- `9router-config`: Configuration files

## Networks

Connected to `localnet-proxy-network` for communication with other proxy services.
