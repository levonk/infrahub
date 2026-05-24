# Tor - Production Docker Service

## Overview

Tor proxy service for anonymizing traffic.

This service is built using hardened base-debian image with enterprise-grade security practices including:

- Non-root execution
- Minimal attack surface
- Health checks
- Proper resource limits

## Features

- **Security**: Hardened base image with non-root user
- **Health Checks**: Built-in health monitoring
- **Resource Limits**: Configurable CPU and memory limits
- **Logging**: Structured JSON logging
- **Monitoring**: Prometheus metrics endpoint

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
| `SERVICE_NAME` | Service identifier | `tor` |
| `SERVICE_PORT` | Port the service listens on | `9050` |

### Ports

- **9050**: Main service port

### Health Checks

- **Script**: `healthcheck/check-health.sh`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3

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

- **Base Image**: `base-alpine` (hardened Alpine)
- **User**: Non-root (`tor`)
- **Capabilities**: Dropped all capabilities
- **Filesystem**: Read-only root filesystem where possible
- **Networks**: Isolated network with explicit rules

### Best Practices

- No privileged containers
- No host network access
- No Docker socket mounting
- Resource limits enforced
- Secrets mounted at runtime

## Troubleshooting

### Common Issues

1. **Port already in use**

   ```bash
   # Find what's using the port
   lsof -i :9050

   # Change port in docker-compose.yml
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
- Add tests for new features
- Update documentation
- Ensure security best practices

## License

See LICENSE file in the project root.
