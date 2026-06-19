# proxy-iron-proxy

Ansible role to deploy [iron-proxy](https://github.com/ironsh/iron-proxy), a default-deny egress firewall for untrusted workloads.

## Features

- **DNS Interception**: Redirects DNS queries to enforce allowlist rules
- **TLS Termination**: MITM mode for full payload inspection or SNI-only mode
- **Allowlist Enforcement**: Default-deny egress with configurable domain/CIDR allowlists
- **Secret Injection**: On-the-fly API key injection/replacement for secure credential management
- **Security Hardening**: Non-root execution, capability dropping, read-only filesystem

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_iron_proxy_enabled` | `true` | Enable/disable iron-proxy deployment |
| `proxy_iron_proxy_version` | `"latest"` | Container image version |
| `proxy_iron_proxy_tls_mode` | `"mitm"` | TLS mode: `mitm` or `sni-only` |

### DNS Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_iron_proxy_dns_enabled` | `true` | Enable DNS interception |
| `proxy_iron_proxy_dns_host_port` | `"53"` | DNS port on host |
| `proxy_iron_proxy_dns_proxy_ip` | `docker_network_gateway` | IP returned for intercepted DNS |
| `proxy_iron_proxy_upstream_dns` | `"8.8.8.8:53"` | Upstream DNS resolver |

### HTTP/HTTPS Proxy

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_iron_proxy_http_host_port` | `"8080"` | HTTP proxy port on host |
| `proxy_iron_proxy_https_host_port` | `"8443"` | HTTPS proxy port on host |

### Allowlist Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_iron_proxy_allowlist_warn` | `false` | Log but allow blocked requests |
| `proxy_iron_proxy_allowed_domains` | `[]` | List of allowed domains |
| `proxy_iron_proxy_allowed_cidrs` | `[]` | List of allowed CIDRs |
| `proxy_iron_proxy_allowlist_rules` | `[]` | Advanced allowlist rules |

### API Key Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_iron_proxy_openai_enabled` | `false` | Enable OpenAI API key injection |
| `proxy_iron_proxy_openai_api_key` | `""` | OpenAI API key |
| `proxy_iron_proxy_anthropic_enabled` | `false` | Enable Anthropic API key replacement |
| `proxy_iron_proxy_anthropic_api_key` | `""` | Anthropic API key |
| `proxy_iron_proxy_google_enabled` | `false` | Enable Google API key injection |
| `proxy_iron_proxy_google_api_key` | `""` | Google API key |
| `proxy_iron_proxy_github_enabled` | `false` | Enable GitHub token injection |
| `proxy_iron_proxy_github_token` | `""` | GitHub token |

## Example Usage

### Basic Deployment

```yaml
- name: Deploy iron-proxy
  hosts: cloud_servers
  roles:
    - role: proxy-iron-proxy
      vars:
        proxy_iron_proxy_dns_proxy_ip: "172.20.0.1"
```

### With API Key Injection

```yaml
- name: Deploy iron-proxy with API keys
  hosts: cloud_servers
  roles:
    - role: proxy-iron-proxy
      vars:
        proxy_iron_proxy_openai_enabled: true
        proxy_iron_proxy_openai_api_key: "{{ vault_openai_api_key }}"
        proxy_iron_proxy_anthropic_enabled: true
        proxy_iron_proxy_anthropic_api_key: "{{ vault_anthropic_api_key }}"
```

### With Custom Allowlist

```yaml
- name: Deploy iron-proxy with allowlist
  hosts: cloud_servers
  roles:
    - role: proxy-iron-proxy
      vars:
        proxy_iron_proxy_allowed_domains:
          - "api.openai.com"
          - "*.anthropic.com"
          - "registry.npmjs.org"
        proxy_iron_proxy_allowed_cidrs:
          - "10.0.0.0/8"
          - "172.16.0.0/12"
```

## Security Considerations

- **CA Certificate**: In MITM mode, clients must trust the generated CA certificate
- **Default-Deny**: All egress is blocked unless explicitly allowed
- **IMDS Protection**: Cloud metadata services are blocked by default
- **Secret Management**: API keys should be stored in Ansible Vault, not plain text

## Dependencies

- Docker engine
- Docker Python library (`community.docker` collection)

## License

MIT
