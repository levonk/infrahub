# Ansible Variable Naming Conventions

## Overview

This document defines the naming conventions and standards for Ansible variables in the infrahub project. Consistent variable naming ensures maintainability, readability, and prevents conflicts across roles and playbooks.

## Naming Pattern Standards

### General Pattern
```
<scope>_<service>_<component>_<attribute>
```

### Scope Prefixes
- `proxy_` - Reverse proxy and related services
- `security_` - Security services (CrowdSec, fail2ban, etc.)
- `cloudflare_` - Cloudflare DNS and API configuration
- `vault_` - Encrypted vault variables (sensitive data)
- `common_` - Shared/common infrastructure components
- `search_` - Search services (SearXNG, etc.)
- `cloud_server_` - Cloud server host-specific configuration
- `vpn_` - VPN services (NordVPN, Tailscale, etc.)

### Service Names
- `traefik` - Traefik reverse proxy
- `authelia` - Authelia authentication service
- `crowdsec` - CrowdSec security engine
- `searxng` - SearXNG search engine
- `nordvpn` - NordVPN service
- `tailscale` - Tailscale VPN
- `netbird` - NetBird VPN

### Component Names
- `container` - Docker container configuration
- `network` - Docker network configuration
- `postgres` - PostgreSQL database
- `redis` - Redis cache/storage
- `api` - API configuration
- `dns` - DNS configuration
- `acme` - ACME/Let's Encrypt SSL
- `bouncer` - Security bouncer (CrowdSec)

### Attribute Names
- `enabled` - Enable/disable flag (boolean)
- `image` - Docker image name
- `version` - Software version
- `port` - Port number (host or container)
- `host_port` - Host port number
- `container_port` - Container port number
- `name` - Name identifier
- `subnet` - Network subnet (CIDR notation)
- `gateway` - Network gateway IP
- `password` - Password (should be in vault)
- `token` - API token (should be in vault)
- `secret` - Secret key (should be in vault)
- `email` - Email address
- `domain` - Domain name
- `zone_id` - Cloudflare zone ID
- `api_key` - API key (should be in vault)
- `duration` - Time duration
- `user` - Username
- `database` - Database name

## Examples

### Traefik Variables
```yaml
proxy_traefik_enabled: true
proxy_traefik_container_name: "traefik"
proxy_traefik_image: "traefik:{{ proxy_traefik_version }}"
proxy_traefik_version: "v3.0"
proxy_traefik_host_http_port: "80"
proxy_traefik_host_https_port: "443"
proxy_traefik_container_dashboard_port: "8080"
proxy_traefik_network_name: "traefik-network"
proxy_traefik_network_subnet: "172.31.0.0/16"
proxy_traefik_network_gateway: "172.31.0.1"
vault_traefik_acme_email: "admin@levonk.com"
```

### Authelia Variables
```yaml
proxy_authelia_enabled: true
proxy_authelia_container_name: "authelia"
proxy_authelia_image: "authelia/authelia:{{ proxy_authelia_version }}"
proxy_authelia_version: "4.38"
proxy_authelia_host_port: "9091"
proxy_authelia_container_port: "9091"
proxy_authelia_postgres_password: "{{ vault_authelia_postgres_password }}"
vault_authelia_admin_password: "change-me-in-vault"
vault_authelia_admin_email: "admin@levonk.com"
vault_authelia_session_secret: "change-me-in-vault"
vault_authelia_jwt_secret: "change-me-in-vault"
```

### CrowdSec Variables
```yaml
security_crowdsec_enabled: true
security_crowdsec_container_name: "crowdsec"
security_crowdsec_image: "crowdsecurity/crowdsec:{{ security_crowdsec_version }}"
security_crowdsec_version: "latest"
security_crowdsec_host_port: "8080"
security_crowdsec_container_port: "8080"
vault_crowdsec_api_token: "change-me-in-vault"
vault_crowdsec_bouncer_api_key: "change-me-in-vault"
security_crowdsec_ban_duration: "672h"
```

### Cloudflare Variables
```yaml
cloudflare_dns_enabled: true
vault_cloudflare_zone_id: "change-me-in-vault"
vault_cloudflare_api_token: "change-me-in-vault"
vault_cloudflare_account_email: "admin@levonk.com"
cloudflare_domain: "levonk.com"
cloudflare_subdomain_search: "search"
cloudflare_search_fqdn: "{{ cloudflare_subdomain_search }}.{{ cloudflare_domain }}"
```

## Vault Variable Naming

### Pattern
```
vault_<service>_<sensitive_attribute>
```

### Examples
```yaml
vault_authelia_postgres_password: "secure-password"
vault_authelia_admin_password: "secure-password"
vault_authelia_session_secret: "secure-random-string"
vault_authelia_jwt_secret: "secure-random-string"
vault_crowdsec_api_token: "secure-token"
vault_crowdsec_bouncer_api_key: "secure-key"
vault_cloudflare_zone_id: "zone-id-from-cloudflare"
vault_cloudflare_api_token: "api-token-from-cloudflare"
vault_nordvpn_openvpn_user: "nordvpn-username"
vault_nordvpn_openvpn_pass: "nordvpn-password"
```

## Port Number Conventions

### Pattern
```
<service>_<scope>_port
```

### Host vs Container Ports
- `host_port` - Port exposed on the host system
- `container_port` - Port inside the container

### Examples
```yaml
proxy_traefik_host_http_port: "80"
proxy_traefik_host_https_port: "443"
proxy_traefik_container_dashboard_port: "8080"
proxy_authelia_host_port: "9091"
proxy_authelia_container_port: "9091"
security_crowdsec_host_port: "8080"
security_crowdsec_container_port: "8080"
```

## Network Configuration Conventions

### Pattern
```
<service>_network_<attribute>
```

### Examples
```yaml
proxy_traefik_network_name: "traefik-network"
proxy_traefik_network_subnet: "172.31.0.0/16"
proxy_traefik_network_gateway: "172.31.0.1"
proxy_authelia_network_name: "authelia-network"
proxy_authelia_network_subnet: "172.32.0.0/16"
proxy_authelia_network_gateway: "172.32.0.1"
security_crowdsec_network_name: "crowdsec-network"
security_crowdsec_network_subnet: "172.33.0.0/16"
security_crowdsec_network_gateway: "172.33.0.1"
```

## Variable Type Conventions

### Boolean Variables
- Use `enabled` suffix for enable/disable flags
- Always use boolean values (`true`/`false`)
- Example: `proxy_traefik_enabled: true`

### String Variables
- Port numbers should be strings to prevent type conversion issues
- Example: `proxy_traefik_host_http_port: "80"`

### Version Variables
- Use `version` suffix for software versions
- Use string format for version numbers
- Example: `proxy_traefik_version: "v3.0"`

### Secret Variables
- All secrets must use `vault_` prefix
- Secrets must be stored in vault files
- Never commit secrets to git
- Example: `vault_authelia_admin_password`

## Variable Reference Conventions

### Pattern
```yaml
service_attribute: "{{ vault_service_attribute }}"
```

### Examples
```yaml
proxy_authelia_postgres_password: "{{ vault_authelia_postgres_password }}"
proxy_authelia_admin_password: "{{ vault_authelia_admin_password }}"
proxy_authelia_session_secret: "{{ vault_authelia_session_secret }}"
```

## Comments and Documentation

### Variable Comments
Each variable should have a comment explaining:
- Purpose of the variable
- Security implications (if sensitive)
- Valid values or format
- Dependencies on other variables

### Example
```yaml
# ---------------------------------------------------------------------------
# Traefik Configuration
# ---------------------------------------------------------------------------
# Traefik reverse proxy with ACME SSL and experimental plugins
proxy_traefik_enabled: true
proxy_traefik_container_name: "traefik"
proxy_traefik_image: "traefik:{{ proxy_traefik_version }}"
proxy_traefik_version: "v3.0"

# ACME Configuration for Let's Encrypt SSL
# Email used for Let's Encrypt certificate notifications
vault_traefik_acme_email: "admin@levonk.com"
```

## Validation Rules

### Required Variables
- All variables must be defined before use
- Use `required_vars` in role meta/main.yml for critical variables
- Provide sensible defaults in defaults/main.yml

### Type Validation
- Use variable validation playbooks to check types
- Validate email formats with regex
- Validate port numbers are within valid range
- Validate IP addresses and CIDR notation

### Placeholder Values
- Use descriptive placeholders for vault variables
- Format: `change-me-in-vault-<instruction>`
- Example: `vault_authelia_admin_password: "change-me-in-vault-generate-secure-password"`

## Compliance

All variable naming must comply with:
- AGENTS.md guidelines for variable-driven configuration
- No hardcoded IPs, ports, or credentials
- Proper secret management using Ansible vault
- Consistent naming across all roles and playbooks

## References

- AGENTS.md: `~/p/gh/levonk/infrahub/AGENTS.md`
- Vault Management: `shared/active/02-config/ansible/vault/README.md`
- Ansible Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html
