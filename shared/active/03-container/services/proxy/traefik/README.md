# Traefik - Production Docker Service

## Overview

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy.

This service is built using the official Traefik image.

## Features

- **Automatic Service Discovery**
- **Let's Encrypt Integration**
- **Web UI (Dashboard)**
- **Metrics for Monitoring**

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Localnet infrastructure running

### Build and Run

```bash
# Build the service
make build

# Start the service
make up

# Check health
make health-check

# View logs
make logs
```

### Development

```bash
# Run tests
make test

# Lint configuration
make lint

# Clean up
make clean
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `traefik` |
| `SERVICE_PORT` | Admin port for the service | `8080` |

### Ports

- **80**: Web
- **443**: Web Secure
- **8080**: Admin/Dashboard

### Health Checks

- **Script**: `healthcheck/check-health.sh`
- **Interval**: 30 seconds
- **Timeout**: 3 seconds

## Build System

The Makefile provides convenient commands:

### Core Commands

- `build` - Build Docker images
- `up` - Start services
- `down` - Stop services
- `restart` - Restart services
- `logs` - View logs
- `health-check` - Verify health

### Development Commands

- `test` - Run test suite
- `lint` - Lint configuration files
- `shell` - Access container shell
- `clean` - Remove containers (keep data)
- `clean-all` - Remove everything (WARNING: destroys data)

## Security

### Container Hardening

- **Base Image**: Official `traefik` image
- **User**: Non-root (`traefik`)

### Best Practices

- The Traefik dashboard should not be exposed to the internet without authentication.

## Troubleshooting

### Common Issues

1. **Port already in use**

   ```bash
   # Find what's using the port
   lsof -i :80
   lsof -i :443
   lsof -i :8080
   ```

2. **Health check failures**

   ```bash
   # Check service logs
   make logs

   # Test health endpoint manually
   make health-check
   ```

## Contributing

- Follow the established patterns
- Update documentation
- Ensure security best practices

## License

See LICENSE file in the project root.
