# SearXNG Ansible Role

## Overview

Deploys SearXNG as a Docker container with NordVPN proxy integration for privacy-respecting metasearch functionality. Integrated with Traefik reverse proxy for secure external access via `search.levonk.com` with comprehensive security middleware chain.

## Requirements

- Docker installed on target host
- NordVPN container running on vpn-network
- Traefik reverse proxy with security middleware (GeoBlock, CrowdSec, Authelia)
- Cloudflare DNS configured for `search.levonk.com`

## Role Variables

### Service Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `search_searxng_enabled` | `true` | Enable SearXNG deployment |
| `search_searxng_service_dir` | `/opt/searxng` | Service directory |
| `search_searxng_container_name` | `searxng` | Container name |
| `search_searxng_image` | `searxng/searxng` | Docker image |
| `search_searxng_image_tag` | `latest` | Image tag |

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `search_searxng_network_name` | `searxng-network` | Docker network |
| `search_searxng_vpn_network` | `vpn-network` | VPN network |
| `search_searxng_host_port` | `8080` | Host port |
| `search_searxng_container_port` | `8080` | Container port |
| `search_searxng_container_ip` | `172.22.0.2` | Container IP address |

### Proxy Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `search_searxng_http_proxy` | `http://nordvpn:1080` | HTTP proxy |
| `search_searxng_https_proxy` | `http://nordvpn:1080` | HTTPS proxy |

### Traefik Integration

| Variable | Default | Description |
|----------|---------|-------------|
| `search_searxng_domain` | `search.levonk.com` | External domain |
| `search_searxng_enabled` | `true` | Enable Traefik integration |

## Security Middleware Chain

SearXNG is protected by a comprehensive security middleware chain in Traefik:

1. **GeoBlock** - Restricts access to US-only geographic locations
2. **CrowdSec Bouncer** - IP-based threat protection and ban enforcement
3. **Authelia** - Password authentication for external access

### Tailscale Network Bypass

Requests from Tailscale (`100.64.0.0/10`) and NetBird (`100.100.0.0/10`) networks bypass authentication and geographic restrictions for trusted internal access.

## Dependencies

- NordVPN container must be running on vpn-network
- Docker service must be active
- Traefik reverse proxy with security middleware must be deployed
- Cloudflare DNS must be configured for `search.levonk.com`

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: search-searxng
      vars:
        search_searxng_host_port: 8080
        search_searxng_http_proxy: "http://nordvpn:1080"
        search_searxng_domain: "search.levonk.com"
```

## Traefik Configuration

The role includes Traefik labels in the docker-compose configuration for automatic routing:

- **HTTP Router**: Redirects to HTTPS
- **HTTPS Router**: Applies security middleware chain (GeoBlock → CrowdSec → Authelia)
- **Tailscale Router**: Bypasses authentication for VPN clients (higher priority)
- **SSL Certificate**: Automatic Let's Encrypt via Cloudflare DNS challenge

## Access Control

### External Access
- **URL**: https://search.levonk.com
- **Authentication**: Required (Authelia password)
- **Geographic**: US-only (GeoBlock middleware)
- **IP Filtering**: CrowdSec threat protection

### Internal Access (Tailscale/NetBird)
- **URL**: https://search.levonk.com
- **Authentication**: Not required (bypass)
- **Geographic**: No restrictions
- **IP Filtering**: None

## Troubleshooting

### Authentication Issues
- Check Authelia logs: `docker logs proxy-authelia`
- Verify Authelia is running: `docker ps | grep authelia`
- Test Authelia directly: `curl http://localhost:9091`

### Geographic Blocking Issues
- Check GeoBlock configuration in Traefik dynamic config
- Verify Cloudflare DNS is propagating correctly
- Test from different geographic locations

### SSL Certificate Issues
- Check Traefik ACME logs: `docker logs traefik`
- Verify Cloudflare API credentials in vault
- Ensure DNS records are properly configured

## License

MIT