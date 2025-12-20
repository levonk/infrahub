# Jellyfin - Production Docker Service
# Generated from boilerplate template

## Overview

This service is built using the official Jellyfin Docker image.

## Features

- **Media Server**: The Free Software Media System
- **Health Checks**: Built-in health monitoring
- **Resource Limits**: Configurable CPU and memory limits
- **Logging**: Structured JSON logging

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Localnet infrastructure running

### Build and Run

```bash
# Start the service
make up

# Check health
make health-check

# View logs
make logs
```

### Development

```bash
# Lint configuration
make lint

# Clean up
make clean
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `jellyfin` |
| `SERVICE_PORT` | Port the service listens on | `8096` |
| `NODE_ENV` | Node.js environment | `production` |

### Ports

- **8096**: Main service port
- **7359/udp**: Discovery port

### Health Checks

- **Endpoint**: `/health`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3

## Build System

The Makefile provides convenient commands:

### Core Commands
- `up` - Start services
- `down` - Stop services
- `restart` - Restart services
- `logs` - View logs
- `health-check` - Verify health

### Development Commands
- `lint` - Lint configuration files
- `clean` - Remove containers (keep data)
- `clean-all` - Remove everything (WARNING: destroys data)

## Security

### Best Practices

- No privileged containers
- No host network access
- No Docker socket mounting
- Resource limits enforced
- Secrets mounted at runtime

## Deployment

### Docker Compose

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: localnet-media-jellyfin-standalone
    restart: unless-stopped
    ports:
      - "8096:8096"
      - "7359:7359/udp"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   # Find what's using the port
   lsof -i :8096

   # Change port in docker-compose.yml
   ```

2. **Health check failures**
   ```bash
   # Check service logs
   make logs

   # Test health endpoint manually
   curl http://localhost:8096/health
   ```

## Contributing

1. Follow the established patterns
2. Add tests for new features
3. Update documentation
4. Ensure security best practices

## License

See LICENSE file in the project root.
