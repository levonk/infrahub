# Proxy Headroom Role

## Overview

Deploys headroom context compression layer for AI agents. Headroom reduces LLM token usage by 60-95% while maintaining accuracy by compressing prompts before they reach the LLM.

## Architecture

Headroom sits upstream of iron-proxy in the proxy chain:

```
Tailscale Clients → Headroom (8787) → Iron-Proxy (8080) → Internet
```

## Role Variables

### Container Configuration

- `proxy_headroom_enabled`: Enable/disable headroom deployment (default: true)
- `proxy_headroom_version`: Headroom version (default: "0.26.0")
- `proxy_headroom_image`: Docker image to use (default: "headroom:{{ proxy_headroom_version }}")

### Network Configuration

- `proxy_headroom_host_port`: Host port for headroom proxy (default: 8787)
- `proxy_headroom_container_port`: Container port (default: 8787)
- `proxy_headroom_host_ip`: Host bind address (default: 0.0.0.0)
- `proxy_headroom_container_ip`: Container bind address (default: 0.0.0.0)

### Upstream Proxy

- `proxy_headroom_upstream_proxy`: Upstream proxy URL (default: "http://iron-proxy:80")

### Features

- `proxy_headroom_output_shaper`: Enable output token reduction (default: 0)

### Data Storage

- `proxy_headroom_data_dir`: Data directory for cache and configuration (default: /opt/proxy/headroom)
- `proxy_headroom_volume_name`: Docker volume name (default: localnet-headroom-data-volume)

### User Configuration

- `proxy_headroom_puid`: User ID for container (default: 1000)
- `proxy_headroom_pgid`: Group ID for container (default: 1000)
- `proxy_headroom_tz`: Timezone (default: UTC)

### Network

- `proxy_headroom_docker_network_name`: Docker network name (default: proxy-chain-network)

## Dependencies

- `proxy-iron-proxy`: Headroom requires iron-proxy as upstream

## Usage

### Basic Deployment

```yaml
- name: Deploy headroom
  hosts: cloud_servers
  roles:
    - role: proxy-headroom
```

### Custom Configuration

```yaml
- name: Deploy headroom with custom settings
  hosts: cloud_servers
  roles:
    - role: proxy-headroom
      vars:
        proxy_headroom_host_port: "8787"
        proxy_headroom_output_shaper: "1"
        proxy_headroom_upstream_proxy: "http://iron-proxy:8080"
```

## Health Check

The role includes automatic health verification:

```yaml
- name: Wait for headroom to be healthy
  ansible.builtin.uri:
    url: "http://127.0.0.1:{{ proxy_headroom_host_port }}/health"
    status_code: 200
  register: headroom_health
  until: headroom_health.status == 200
  retries: 10
  delay: 5
```

## Container Security

- Non-root user (PUID/PGID 1000)
- Dropped all capabilities except essential ones
- Read-only filesystem
- No-new-privileges security option
- Temporary filesystem for /tmp

## Troubleshooting

### Check Container Status

```bash
docker ps | grep headroom
docker logs headroom
```

### Verify Proxy Chain

```bash
# Test headroom health
curl http://localhost:8787/health

# Test proxy chain through headroom
curl -x http://localhost:8787 https://httpbin.org/get
```

### Check Network Connectivity

```bash
# Verify headroom can reach iron-proxy
docker exec headroom ping iron-proxy

# Check network configuration
docker network inspect proxy-chain-network
```

## References

- [Headroom Documentation](https://headroom-docs.vercel.app/docs)
- [Headroom GitHub](https://github.com/chopratejas/headroom)
- [Iron-Proxy Role](../proxy-iron-proxy/README.md)