# vpn-netbird

Install and configure Netbird as a host-level WireGuard mesh VPN daemon.

## Requirements

- Debian 12 (bookworm) or Ubuntu 22.04/24.04 target host
- `become: true` privilege escalation
- Valid Netbird setup key and management URL

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vpn_netbird_version` | `latest` | Package version to install |
| `vpn_netbird_channel` | `stable` | Repository channel (`stable` or `unstable`) |
| `vpn_netbird_management_url` | `""` | Netbird management server URL (required) |
| `vpn_netbird_setup_key` | `""` | Setup key for peer registration (required) |
| `vpn_netbird_port` | `51820` | WireGuard UDP port |
| `vpn_netbird_hostname` | `inventory_hostname` | Hostname in the Netbird network |
| `vpn_netbird_advertise_routes` | `[]` | Subnet routes to advertise |
| `vpn_netbird_accept_dns` | `true` | Accept DNS from management server |
| `vpn_netbird_accept_routes` | `false` | Accept routes from other peers |
| `vpn_netbird_enable_ssh` | `false` | Enable Netbird SSH feature |
| `vpn_netbird_verify_connection` | `true` | Run `netbird status` verification |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: vpn_servers
  become: true
  roles:
    - role: vpn-netbird
      vars:
        vpn_netbird_setup_key: "{{ vault_netbird_setup_key }}"
        vpn_netbird_management_url: "https://api.netbird.io:33073"
        vpn_netbird_advertise_routes:
          - "10.0.0.0/24"
```

## License

MIT
