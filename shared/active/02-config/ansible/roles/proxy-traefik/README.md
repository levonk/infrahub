# proxy-traefik

Deploy Traefik reverse proxy, Squid caching proxy, and Tor relay as Docker containers.

## Requirements

- Ansible >= 2.15
- Docker engine on target host
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_traefik_version` | `latest` | Traefik image tag |
| `proxy_traefik_http_host_port` | `{{ cloud_server_proxy_http_host_port \| default('80') }}` | Host HTTP port |
| `proxy_traefik_http_container_port` | `{{ cloud_server_proxy_http_container_port \| default('80') }}` | Container HTTP port |
| `proxy_traefik_https_host_port` | `{{ cloud_server_proxy_https_host_port \| default('443') }}` | Host HTTPS port |
| `proxy_traefik_https_container_port` | `{{ cloud_server_proxy_https_container_port \| default('443') }}` | Container HTTPS port |
| `proxy_traefik_api_port` | `{{ cloud_server_proxy_traefik_api_port \| default('8080') }}` | Traefik API/dashboard port |
| `proxy_traefik_dashboard_enabled` | `true` | Enable Traefik dashboard |
| `proxy_traefik_acme_enabled` | `false` | Enable ACME/Let's Encrypt |
| `proxy_squid_enabled` | `true` | Deploy Squid caching proxy |
| `proxy_squid_host_port` | `{{ cloud_server_proxy_squid_host_port \| default('3128') }}` | Host Squid port |
| `proxy_squid_container_port` | `{{ cloud_server_proxy_squid_container_port \| default('3128') }}` | Container Squid port |
| `proxy_squid_cache_size_mb` | `1024` | Squid cache size in MB |
| `proxy_tor_enabled` | `true` | Deploy Tor relay |
| `proxy_tor_socks_host_port` | `{{ cloud_server_tor_socks_host_port \| default('9050') }}` | Host Tor SOCKS port |
| `proxy_tor_socks_container_port` | `{{ cloud_server_tor_socks_container_port \| default('9050') }}` | Container Tor SOCKS port |
| `proxy_docker_network_name` | `{{ cloud_server_proxy_network_name \| default('proxy-network') }}` | Docker network name |
| `proxy_data_dir` | `{{ cloud_server_proxy_data_dir \| default('/opt/proxy') }}` | Data directory on host |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: proxy_servers
  become: true
  roles:
    - role: proxy-traefik
      vars:
        proxy_traefik_acme_enabled: true
        proxy_traefik_acme_email: "admin@example.com"
        proxy_squid_cache_size_mb: 2048
```

## Security Notes

- All ports are variable-driven per AGENTS.md rules. No hardcoded IPs or ports.
- Traefik dashboard is disabled by default in insecure mode. Use a reverse proxy or VPN for access.
- Tor exit relay is disabled by default.

## License

MIT
