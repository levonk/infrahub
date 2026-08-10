# sandbox-cli-proxy

Deploys [iron-proxy](https://github.com/ironsh/iron-proxy) as a default-deny
egress firewall for sandboxed CLI containers (sherlock, subfinder, recon tools,
scrapers).

## Architecture

See [ADR-202608051501: Sandboxed CLI Container Egress Control](../../../08-docs/adr/adr-202608051501-sandboxed-cli-egress.md)
for the full architecture decision.

Two-layer design:

1. **This role** deploys iron-proxy as a persistent, Ansible-managed container
   via `community.docker.docker_container`.
2. **`just` recipes** run ephemeral CLI containers via `docker run --rm -it`,
   pointing at the deployed proxy.

Each egress profile (e.g., `osint`, `recon`) deploys a separate iron-proxy
instance on a dedicated Docker network with its own allowlist.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `sandbox_cli_proxy_enabled` | `true` | Enable the role |
| `sandbox_cli_proxy_version` | `0.7.0` | iron-proxy image version (pinned) |
| `sandbox_cli_proxy_tls_mode` | `mitm` | TLS mode (MITM required for method enforcement) |
| `sandbox_cli_proxy_allowlist_warn` | `false` | Warn mode (false = default-deny) |
| `sandbox_cli_proxy_profiles` | `[]` | List of profile dicts (populated by client) |
| `sandbox_cli_proxy_ca_dir` | `/opt/sandbox-cli` | CA certificate directory |

## Profile Structure

Each profile in `sandbox_cli_proxy_profiles`:

```yaml
- name: "osint"
  network: "sandbox-osint-net"
  subnet: "172.43.0.0/16"
  gateway: "172.43.0.1"
  proxy_ip: "172.43.0.2"
  http_port: "18080"
  https_port: "18443"
  dns_port: "18053"
  allowlist_rules:
    - host: "*.google.com"
      methods: ["GET", "HEAD"]
      paths: ["/*"]
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: sandbox_proxy_hosts
  become: true
  roles:
    - role: sandbox-cli-proxy
```
