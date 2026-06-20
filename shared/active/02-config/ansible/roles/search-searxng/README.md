# SearXNG Ansible Role

## Overview

Deploys SearXNG as a Docker container with NordVPN proxy integration for privacy-respecting metasearch functionality.

## Requirements

- Docker installed on target host
- NordVPN container running on vpn-network
- Traefik for routing (optional)

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

### Proxy Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `search_searxng_http_proxy` | `http://nordvpn:1080` | HTTP proxy |
| `search_searxng_https_proxy` | `http://nordvpn:1080` | HTTPS proxy |

## Dependencies

- NordVPN container must be running on vpn-network
- Docker service must be active

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: search-searxng
      vars:
        search_searxng_host_port: 8080
        search_searxng_http_proxy: "http://nordvpn:1080"
```

## License

MIT