# SearXNG - Privacy-Respecting Metasearch Engine

## Overview

SearXNG is a privacy-respecting metasearch engine that aggregates results from multiple search engines while neither tracking nor profiling users. This container routes all traffic through NordVPN for enhanced privacy and is exposed via Traefik for Tailscale client access.

**Proxy Chain Architecture:**
```
Tailscale Clients → Traefik → SearXNG (8080) → NordVPN (1080) → Internet
```

**Key Features:**
- **Privacy**: No tracking or profiling of users
- **Metasearch**: Aggregates results from multiple search engines
- **Proxy Routing**: All traffic routed through NordVPN
- **Traefik Integration**: Automatic routing and SSL termination
- **Self-Hosted**: Complete control over your search instance

**Source**: https://github.com/searxng/searxng

## Quick Start

### Prerequisites

- Docker and Docker Compose
- NordVPN container running on vpn-network
- Traefik running for routing

### Configuration

Set the NordVPN proxy in `.env`:

```bash
SEARCH_SEARXNG_HTTP_PROXY=http://nordvpn:1080
SEARCH_SEARXNG_HTTPS_PROXY=http://nordvpn:1080
```

### Build and Run

```bash
# Build the service
docker-compose build

# Start the service
docker-compose up -d

# View logs
docker-compose logs -f
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SEARCH_SEARXNG_PUID` | User ID for container process | 1000 |
| `SEARCH_SEARXNG_PGID` | Group ID for container process | 1000 |
| `SEARCH_SEARXNG_TZ` | Timezone | UTC |
| `SEARCH_SEARXNG_HOST_IP` | Host bind address | 0.0.0.0 |
| `SEARCH_SEARXNG_HOST_PORT` | Host port | 8080 |
| `SEARCH_SEARXNG_CONTAINER_IP` | Container bind address | 0.0.0.0 |
| `SEARCH_SEARXNG_CONTAINER_PORT` | Container port | 8080 |
| `SEARCH_SEARXNG_HTTP_PROXY` | NordVPN HTTP proxy | http://nordvpn:1080 |
| `SEARCH_SEARXNG_HTTPS_PROXY` | NordVPN HTTPS proxy | http://nordvpn:1080 |

### Ports

- **8080**: SearXNG web interface (exposed via Traefik)

### Proxy Chain Integration

SearXNG is designed to work in a proxy chain with NordVPN:

1. **Tailscale clients** connect to Traefik
2. **Traefik** routes to SearXNG on port 8080
3. **SearXNG** routes all outbound traffic through NordVPN
4. **NordVPN** provides privacy and IP masking
5. **Internet** receives requests from NordVPN IP

### Network Configuration

The container connects to two networks:
- `searxng-network`: Isolated network for SearXNG services
- `vpn-network`: Shared network for NordVPN communication

## Usage

### Access via Traefik

Access SearXNG through Traefik using the configured route:

```bash
# Via Traefik (configured route)
https://your-domain.com/searxng
```

### Direct Access (for testing)

For direct access during development:

```bash
# Direct access to container port
curl http://localhost:8080
```

### Configure Search Engines

Edit the SearXNG configuration in the mounted volume:

```bash
# Access configuration
docker exec -it searxng sh
vi /etc/searxng/settings.yml
```

## Monitoring

### Logs

View logs:

```bash
docker-compose logs -f searxng
```

### Health Check

The container includes a health check:

```bash
curl http://localhost:8080/health
```

Or use the health check script:

```bash
./healthcheck/check-health.sh
```

## Security

### Container Hardening

- **Base Image**: Alpine 3.20 (minimal attack surface)
- **User**: Non-root (searxng:searxng, UID/GID 1000)
- **Capabilities**: Dropped all capabilities
- **Filesystem**: Read-only root filesystem
- **Networks**: Isolated network configuration

### Best Practices

- No privileged containers
- No host network access
- No Docker socket mounting
- Resource limits enforced
- All traffic routed through NordVPN
- Traefik provides SSL termination

## Deployment

### Docker Compose

```yaml
services:
  searxng:
    build:
      context: .
      dockerfile: Dockerfile.searxng
    container_name: searxng
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - HTTP_PROXY=http://nordvpn:1080
      - HTTPS_PROXY=http://nordvpn:1080
    networks:
      - searxng-network
      - vpn-network
```

### Ansible Deployment

Deploy to OCI cloud host using the provided Ansible playbooks:

```bash
# Deploy SearXNG service
ansible-playbook playbooks/deploy-searxng.yml
```

## Troubleshooting

### Common Issues

1. **Cannot connect to NordVPN proxy**
   ```bash
   # Check if NordVPN is running
   docker ps | grep nordvpn
   
   # Check network connectivity
   docker exec searxng ping nordvpn
   ```

2. **Traefik routing not working**
   ```bash
   # Check Traefik logs
   docker logs traefik
   
   # Verify Traefik labels
   docker inspect searxng | grep -A 20 Labels
   ```

3. **High memory usage**
   ```bash
   # Check SearXNG cache size
   docker exec searxng du -sh /var/cache/searxng
   
   # Clear cache if needed
   docker exec searxng rm -rf /var/cache/searxng/*
   ```

4. **Port already in use**
   ```bash
   # Find what's using the port
   lsof -i :8080
   
   # Change port in .env
   SEARCH_SEARXNG_HOST_PORT=8081
   ```

## Performance

### Expected Performance

- **Search Response Time**: 1-3 seconds (depending on engines)
- **Memory Usage**: ~100-200MB (base) + cache
- **CPU Usage**: Low during idle, moderate during searches

### Optimization Tips

- Limit enabled search engines in settings.yml
- Configure result caching appropriately
- Use NordVPN servers with low latency
- Monitor and tune cache size

## Architecture

### Privacy Pipeline

```
User Request → Traefik → SearXNG → Search Engines
                    ↓            ↓
                 SSL         NordVPN
                Termination   (Privacy)
```

### Components

- **SearXNG Core**: Metasearch engine with multiple search backends
- **NordVPN**: Privacy protection and IP masking
- **Traefik**: Reverse proxy and SSL termination
- **Configuration**: Customizable search engines and settings

## References

- [SearXNG Documentation](https://docs.searxng.org)
- [SearXNG GitHub](https://github.com/searxng/searxng)
- [Proxy Chain Architecture](../../vpn/nordvpn/README.md)
- [Traefik Configuration](../../proxy/traefik/README.md)