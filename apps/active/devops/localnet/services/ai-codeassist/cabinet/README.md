# Cabinet - Docker Container

AI-first knowledge base and startup OS, containerized for LocalNet deployment.

## Overview

Cabinet is an AI-powered knowledge base that helps you:
- Build custom AI teams in 5 questions
- Ship HTML apps inside your knowledge base
- Run AI agents with scheduled jobs
- Maintain git-versioned memory

## Quick Start

```bash
# Build and start the container
just up

# View logs
just logs

# Stop the container
just down
```

Or use docker-compose directly:
```bash
docker-compose up -d
docker-compose logs -f cabinet
docker-compose down
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Node.js environment |
| `PORT` | `3000` | Port for the web interface |
| `NEXT_TELEMETRY_DISABLED` | `1` | Disable Next.js telemetry |

### Volumes

- `cabinet-data`: Persistent knowledge base data
- `cabinet-git`: Git repository storage

## Access

Once running, access Cabinet at:
- Web UI: http://localhost:3000

## Development

For development with hot reload:
```bash
# Build with development mode
docker-compose -f docker-compose.dev.yml up
```

## Health Check

The container includes a health check that verifies the service is responding:
```bash
docker inspect --format='{{.State.Health.Status}}' ai-codeassist-cabinet
```

## Security

- Runs as non-root user (`cabinet`)
- Uses Alpine Linux minimal base image
- Multi-stage build to reduce image size
- No privileged operations
- Signal handling via dumb-init

## Troubleshooting

### Container won't start
```bash
# Check logs
just logs

# Verify build
just rebuild
```

### Data persistence
Data is stored in Docker volumes. To backup:
```bash
docker run --rm -v cabinet-data:/data -v $(pwd):/backup alpine tar czf /backup/cabinet-backup.tar.gz /data
```

## References

- Cabinet Repository: https://github.com/hilash/cabinet
- Documentation: https://github.com/hilash/cabinet
