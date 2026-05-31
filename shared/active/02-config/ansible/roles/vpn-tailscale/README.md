# vpn-tailscale

Install and configure the Tailscale daemon as a host-level overlay mesh VPN.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- A Tailscale auth key (from the Tailscale admin console)

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vpn_tailscale_version` | `latest` | Tailscale package version to install |
| `vpn_tailscale_channel` | `stable` | Repository channel (`stable` or `unstable`) |
| `vpn_tailscale_auth_key` | `""` | **Required.** Auth key for node registration (provide via vault) |
| `vpn_tailscale_port` | `{{ cloud_server_tailscale_port \| default('41641') }}` | WireGuard UDP port |
| `vpn_tailscale_hostname` | `{{ inventory_hostname }}` | Hostname in the Tailscale network |
| `vpn_tailscale_advertise_routes` | `[]` | Subnet routes to advertise (e.g., `['10.0.0.0/24']`) |
| `vpn_tailscale_accept_dns` | `true` | Accept DNS settings from Tailscale |
| `vpn_tailscale_accept_routes` | `false` | Accept routes from other Tailscale nodes |
| `vpn_tailscale_enable_ssh` | `false` | Enable Tailscale SSH |
| `vpn_tailscale_run_exit_node` | `false` | Advertise as an exit node |
| `vpn_tailscale_verify_connection` | `true` | Verify `tailscale status` after setup |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: vpn-tailscale
      vars:
        vpn_tailscale_auth_key: "{{ vault_tailscale_auth_key }}"
        vpn_tailscale_advertise_routes:
          - "10.0.0.0/24"
```

## Security Notes

- **Auth key**: Never store the Tailscale auth key in plain text. Use Ansible Vault, a secrets manager, or inject it at runtime.
- **Key rotation**: Auth keys can be revoked from the Tailscale admin console. Document rotation procedures.

## License

MIT
