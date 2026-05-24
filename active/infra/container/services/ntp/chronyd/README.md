# Chronyd - Production Docker Service

## Overview

Chronyd is a versatile implementation of the Network Time Protocol (NTP).

This service is built using a hardened base-alpine image with enterprise-grade security practices including:

- Non-root execution
- Minimal attack surface
- Health checks
- Proper resource limits

## Features

- **Accurate Timekeeping**
- **Lightweight and Efficient**

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
| `SERVICE_NAME` | Service identifier | `chronyd` |

### Health Checks

- **Script**: `healthcheck/check-health.sh`
- **Interval**: 30 seconds
- **Timeout**: 5 seconds

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
- **User**: Non-root (`chrony`)

### Best Practices

- Run as a non-root user.

## Troubleshooting

### Common Issues

1. **Health check failures**

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
