# proxy-traefik

Deploy Traefik reverse proxy with ACME/Let's Encrypt, experimental plugins (CrowdSec Bouncer, GeoBlock), and security middleware. This role follows the docker-linux boilerplate patterns and uses variable-driven configuration per AGENTS.md guidelines.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- Docker Engine installed (dependency: docker-engine role)
- Internet connectivity for ACME challenges and plugin downloads

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_traefik_enabled` | `true` | Enable Traefik deployment |
| `proxy_traefik_data_dir` | `/opt/traefik` | Traefik data directory |
| `proxy_traefik_container_name` | `traefik` | Docker container name |
| `proxy_traefik_image` | `traefik` | Docker image name |
| `proxy_traefik_image_tag` | `v3.0` | Docker image tag |
| `proxy_traefik_network_name` | `traefik-network` | Docker network name |
| `proxy_traefik_network_subnet` | `172.31.0.0/16` | Network subnet |
| `proxy_traefik_network_gateway` | `172.31.0.1` | Network gateway |
| `proxy_traefik_http_port` | `80` | HTTP host port |
| `proxy_traefik_https_port` | `443` | HTTPS host port |
| `proxy_traefik_dashboard_port` | `8882` | Dashboard host port |
| `proxy_traefik_dashboard_enabled` | `true` | Enable dashboard |
| `proxy_traefik_acme_enabled` | `true` | Enable ACME/Let's Encrypt |
| `proxy_traefik_acme_email` | `{{ cloud_server_acme_email }}` | ACME email for notifications |
| `proxy_traefik_acme_dns_provider` | `cloudflare` | DNS challenge provider |
| `proxy_traefik_plugins_enabled` | `true` | Enable experimental plugins |
| `proxy_traefik_crowdsec_enabled` | `true` | Enable CrowdSec Bouncer middleware |
| `proxy_traefik_geoblock_enabled` | `true` | Enable GeoBlock middleware |
| `proxy_traefik_geoblock_allowed_countries` | `["US"]` | Allowed country codes |

## Client Overrides

Override defaults in `group_vars/cloud_server.yml` or `host_vars/oci-cloud-server.yml`:

```yaml
proxy_traefik_acme_email: "admin@yourdomain.com"
proxy_traefik_acme_staging: true  # Use staging for testing
proxy_traefik_geoblock_allowed_countries:
  - "US"
  - "CA"
  - "GB"
proxy_traefik_dashboard_enabled: false  # Disable dashboard in production
```

## Dependencies

- `docker-engine` - Installs Docker Engine and Compose plugin

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: proxy-traefik
      vars:
        proxy_traefik_acme_email: "admin@example.com"
        proxy_traefik_acme_staging: false
        proxy_traefik_geoblock_allowed_countries:
          - "US"
```

## Plugin Configuration

### CrowdSec Bouncer (v1.4.4)
The CrowdSec Bouncer middleware integrates with CrowdSec security engine for IP-based protection. Configure via:

```yaml
proxy_traefik_crowdsec_lapi_host: "crowdsec"
proxy_traefik_crowdsec_lapi_port: 8080
proxy_traefik_crowdsec_trusted_ips:
  - "127.0.0.1"
  - "172.31.0.1"
```

### GeoBlock (v0.3.3)
The GeoBlock middleware restricts access based on country codes. Configure via:

```yaml
proxy_traefik_geoblock_allowed_countries:
  - "US"
  - "CA"
proxy_traefik_geoblock_strict: true
```

## Security Middleware Chain

The middleware chain order is critical for proper security:
1. **GeoBlock** - Geographic filtering (first layer)
2. **CrowdSec Bouncer** - IP reputation filtering (second layer)
3. **Authelia** - Authentication (third layer, future integration)

## ACME Configuration

Traefik uses DNS challenge for Let's Encrypt certificate generation. Requires:
- Valid DNS provider credentials (Cloudflare API token)
- Proper DNS records pointing to the server
- Ports 80 and 443 accessible from the internet

For testing, use staging environment:
```yaml
proxy_traefik_acme_staging: true
```

## License

MIT
