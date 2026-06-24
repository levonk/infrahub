# proxy-firewall

Ansible role that configures a default-deny host-level firewall using **nftables** or **ufw**.

## ⚠️  High-Risk Warning

Misconfiguration can **lock out remote access**. Before relying on remote-only connectivity:

- Test via **console access** first.
- Use the built-in **lockout prevention** (temporary allow rule for your management IP).
- Have a **fallback console session** when applying changes.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- One of `nftables` or `ufw` will be installed by the role

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `proxy_firewall_type` | `{{ cloud_server_firewall_type \| default('nftables') }}` | Firewall engine: `nftables` or `ufw` |
| `proxy_firewall_ssh_port` | `{{ cloud_server_ssh_port \| default('22') }}` | SSH port to allow |
| `proxy_firewall_mosh_port` | `{{ cloud_server_mosh_port \| default('60000:61000') }}` | Mosh UDP port range |
| `proxy_firewall_vpn_subnets` | `{{ cloud_server_vpn_subnets \| default([]) }}` | List of CIDRs to allow |
| `proxy_firewall_tailscale_subnet` | `100.64.0.0/10` | Tailscale default subnet |
| `proxy_firewall_netbird_subnet` | `10.0.0.0/8` | Netbird default subnet |
| `proxy_firewall_rate_limit_ssh` | `true` | Enable SSH rate limiting |
| `proxy_firewall_rate_limit_connections` | `5` | Max new connections per interval |
| `proxy_firewall_rate_limit_interval` | `1/minute` | Rate limit interval |
| `proxy_firewall_enable_forwarding` | `true` | Enable IP forwarding |
| `proxy_firewall_enable_masquerade` | `true` | Enable NAT masquerade for VPN subnets |
| `proxy_firewall_prevent_lockout` | `true` | Add temporary allow for management IP |
| `proxy_firewall_prevent_lockout_timeout` | `300` | Seconds before temporary rule is removed |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: proxy-firewall
      vars:
        proxy_firewall_type: nftables
        proxy_firewall_ssh_port: "2222"
        proxy_firewall_vpn_subnets:
          - "100.64.0.0/10"
          - "10.0.0.0/8"
```

## License

MIT
