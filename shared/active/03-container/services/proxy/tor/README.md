# Tor - Production Docker Service

## Overview

Tor proxy service for anonymizing traffic with optional exit node capabilities.

This service is built using hardened base-debian image with enterprise-grade security practices including:

- Non-root execution
- Minimal attack surface
- Health checks
- Proper resource limits
- Optional Tor exit node functionality

## Features

- **Security**: Hardened base image with non-root user
- **Health Checks**: Built-in health monitoring
- **Resource Limits**: Configurable CPU and memory limits
- **Logging**: Structured JSON logging
- **Monitoring**: Prometheus metrics endpoint
- **Exit Node Mode**: Optional Tor relay/exit node configuration
- **Tailscale Integration**: Support for Tailscale-over-Tor configurations

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Localnet infrastructure running

### Build and Run

```bash
# Build the service
make build

# Start the service (SOCKS proxy only)
make up

# Start with exit node enabled
export PROXY_TOR_EXIT_NODE_ENABLED=true
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
| `PROXY_TOR_EXIT_NODE_ENABLED` | Enable Tor exit node mode | `false` |
| `PROXY_TOR_ORPORT` | Tor ORPort for relay/exit | `9001` |
| `PROXY_TOR_DIRPORT` | Tor DirPort for directory | `9030` |
| `PROXY_TOR_NICKNAME` | Tor relay nickname | `levonk-tor-exit` |
| `PROXY_TOR_CONTACT_INFO` | Contact information | `admin@levonk.com` |
| `PROXY_TOR_EXIT_POLICY` | Exit policy for traffic | `reject *:*` |
| `PROXY_TOR_BANDWIDTH_RATE` | Bandwidth rate limit | `100 KB` |
| `PROXY_TOR_BANDWIDTH_BURST` | Bandwidth burst limit | `200 KB` |

### Ports

- **9050**: SOCKS5 proxy port (always available)
- **9001**: ORPort (exit node mode only)
- **9030**: DirPort (exit node mode only)

### Exit Node Configuration

To enable Tor as an exit node:

```bash
# Set environment variable
export PROXY_TOR_EXIT_NODE_ENABLED=true

# Configure exit policy (conservative default)
export PROXY_TOR_EXIT_POLICY="reject *:*"

# Or use a more permissive policy (use with caution)
export PROXY_TOR_EXIT_POLICY="accept *:443, reject *:*"

# Start the service
make up
```

**WARNING**: Running a Tor exit node has legal and security implications. Ensure you:
- Understand your local laws regarding exit node operation
- Configure appropriate exit policies
- Monitor bandwidth and resource usage
- Contact your hosting provider about their exit node policy

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
- Conservative exit policies by default

### Exit Node Security

When running as an exit node:
- Use conservative exit policies initially
- Monitor logs for abuse reports
- Implement rate limiting
- Consider reduced exit policies
- Keep Tor updated regularly

## Tailscale Integration

This Tor service can be used with Tailscale for enhanced privacy:

### Tailscale-over-Tor Configuration

See `../vpn/tailscale/docker-compose.tor.yml` for complete configuration.

The setup includes:
- Tor exit node container
- Tailscale container configured to use Tor SOCKS proxy
- Dedicated network isolation
- Automatic routing configuration

### Usage

```bash
# Navigate to Tailscale service
cd ../vpn/tailscale

# Copy environment file
cp env.tor.example .env

# Configure Tailscale auth key
export TS_AUTHKEY=your-auth-key

# Start Tailscale over Tor
docker-compose -f docker-compose.tor.yml up -d
```

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

3. **Exit node not relaying traffic**

   ```bash
   # Check Tor configuration
   docker exec tor cat /etc/tor/torrc

   # Verify ports are exposed
   docker port tor

   # Check Tor logs for relay status
   docker logs tor | grep -i relay
   ```

4. **Tailscale can't connect through Tor**

   ```bash
   # Verify Tor SOCKS proxy is working
   docker exec tor-exit curl --socks5 127.0.0.1:9050 https://check.torproject.org

   # Check Tailscale container logs
   docker logs tailscale-tor

   # Verify network connectivity
   docker network inspect tor-network
   ```

## Contributing

- Follow the established patterns
- Add tests for new features
- Update documentation
- Ensure security best practices
- Test exit node functionality carefully

## License

See LICENSE file in the project root.
