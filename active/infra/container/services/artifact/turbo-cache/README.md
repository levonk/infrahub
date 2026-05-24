# Turbo Cache Server

A blazingly fast Turborepo remote cache server written in Rust, deployed as a containerized service in the localnet environment.

## Overview

Turbo Cache Server provides a high-performance remote caching solution for Turborepo builds, enabling faster build times across development teams by sharing build artifacts.

## Service Details

- **Image**: `localnet-turbo-cache:latest`
- **Container**: `localnet-turbo-cache`
- **Version**: 2.0.14
- **Base OS**: Alpine Linux 3.21.3
- **Architecture**: x86_64 (AMD64)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARTIFACT_TURBO_CACHE_VERSION` | `2.0.14` | Turbo Cache Server version |
| `ARTIFACT_TURBO_CACHE_CONTAINER_PORT` | `3654` | Internal cache port |
| `ARTIFACT_TURBO_CACHE_HOST_PORT` | `3654` | Host port mapping for cache |
| `ARTIFACT_TURBO_CACHE_WEB_CONTAINER_PORT` | `3655` | Internal web UI port |
| `ARTIFACT_TURBO_CACHE_WEB_HOST_PORT` | `3655` | Host port mapping for web UI |
| `ARTIFACT_TURBO_CACHE_LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `ARTIFACT_TURBO_CACHE_CPU_LIMIT` | `0.5` | CPU limit (cores) |
| `ARTIFACT_TURBO_CACHE_MEMORY_LIMIT` | `512M` | Memory limit |
| `ARTIFACT_TURBO_CACHE_CPU_RESERVATION` | `0.1` | CPU reservation |
| `ARTIFACT_TURBO_CACHE_MEMORY_RESERVATION` | `128M` | Memory reservation |

### Volumes

- **Data Volume**: `/var/lib/turbocache` - Cache storage
- **Config Volume**: `/etc/turbocache` - Configuration files

### Network

- **Network**: `localnet-internal` (172.21.255.0/24)
- **Gateway**: 172.21.255.1

## Security Features

- **Non-root user**: Runs as `turbocache` (UID:GID 1001:1001)
- **Read-only filesystem**: Except for required writable paths
- **Capability dropping**: All capabilities dropped
- **No new privileges**: Prevents privilege escalation
- **Temporary filesystems**: `/tmp` and `/var/tmp` mounted with `noexec,nosuid`

## Health Checks

The service includes comprehensive health checks:

- **Container status**: Verifies the container is running
- **HTTP endpoint**: Checks service availability on port 3654
- **Resource monitoring**: Monitors CPU and memory usage

## Usage

### Starting the Service

```bash
cd /home/micro/p/gh/lrepo52/job-aide/apps/active/devops/localnet
just up-artifact
```

### Viewing Logs

```bash
just logs SERVICE=turbo-cache
```

### Health Check

```bash
just health
```

### Stopping the Service

```bash
just down
```

## Integration with Turborepo

To use this cache server with your Turborepo projects, configure your `turbo.json`:

```json
{
  "remoteCache": {
    "url": "http://localhost:3654",
    "signature": true,
    "teamId": "your-team-id"
  }
}
```

## Web Interface

Access the web interface at: `http://localhost:3655`

The web interface provides:
- Cache statistics and metrics
- Cache management tools
- Performance monitoring

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 3654 and 3655 are available
2. **Permission errors**: Check volume permissions and UID/GID settings
3. **Network issues**: Verify `localnet-internal` network is running

### Debug Commands

```bash
# Check container status
docker ps | grep turbo-cache

# Inspect container
docker inspect localnet-turbo-cache

# View logs
docker logs localnet-turbo-cache

# Test connectivity
curl -f http://localhost:3654/health
```

## Development

### Building the Image

```bash
cd services/artifact/turbo-cache
docker build -f docker/Dockerfile.turbo-cache -t localnet-turbo-cache .
```

### Testing

```bash
# Run health check
./healthcheck/check-health.sh --verbose

# Test service endpoints
curl -f http://localhost:3654/health
curl -f http://localhost:3655/
```

## Performance Tuning

### CPU and Memory

Adjust resource limits based on your team size and build frequency:

- **Small teams** (1-5 developers): Default settings
- **Medium teams** (6-20 developers): Increase CPU to 1.0, Memory to 1G
- **Large teams** (20+ developers): Increase CPU to 2.0, Memory to 2G

### Storage

Monitor cache storage usage:

```bash
docker exec localnet-turbo-cache du -sh /var/lib/turbocache
```

## Monitoring

The service exposes metrics for monitoring:

- Cache hit/miss ratios
- Request latency
- Storage usage
- Error rates

Integrate with your monitoring system using the health check endpoints.

## Security Considerations

- The service runs in a isolated network environment
- All communications are internal to the localnet environment
- No external network access is required
- Cache data is stored locally and not exposed externally

## Dependencies

- **Docker Engine**: 20.10+
- **Docker Compose**: 2.0+
- **LocalNet Environment**: Base services and networking

## Support

For issues and support:

1. Check the logs: `just logs SERVICE=turbo-cache`
2. Verify health: `just health`
3. Review configuration: Check `.env` file settings
4. Consult the main localnet documentation: `AGENTS.md`

## License

This service configuration follows the localnet project licensing terms.
