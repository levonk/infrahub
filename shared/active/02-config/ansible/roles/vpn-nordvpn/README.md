# NordVPN Ansible Role

Deploys NordVPN container with VPN gateway capabilities using the official NordVPN Linux client.

## Requirements

- Docker host with Docker Compose
- NordVPN access token
- TUN device access (`/dev/net/tun`)

## Role Variables

```yaml
# Enable/disable NordVPN deployment
vpn_nordvpn_enabled: false

# NordVPN Configuration
vpn_nordvpn_token: ""                    # Your NordVPN access token (required)
vpn_nordvpn_country: "United_States"     # Country to connect to

# Container Configuration
vpn_nordvpn_container_name: "nordvpn"
vpn_nordvpn_config_volume_name: "localnet-nordvpn-config-volume"
vpn_nordvpn_data_volume_name: "localnet-nordvpn-data-volume"

# Port Configuration (all ports are variables)
vpn_nordvpn_wireguard_host_port: "51820"
vpn_nordvpn_wireguard_container_port: "51820"
vpn_nordvpn_socks_host_port: "1080"
vpn_nordvpn_socks_container_port: "1080"

# Service Directories
localnet_services_dir: "/opt/localnet/services"
localnet_tz: "UTC"
```

## Dependencies

- `docker-engine` role for Docker host setup

## Example Playbook

```yaml
- hosts: vpn_servers
  become: true
  roles:
    - vpn-nordvpn
  vars:
    vpn_nordvpn_enabled: true
    vpn_nordvpn_token: "{{ vault_nordvpn_token }}"
    vpn_nordvpn_country: "United_States"
```

## Features

- Official NordVPN Linux client on Debian Bookworm
- NordLynx technology for fast, secure connections
- Full NAT routing for external hosts
- Support for Docker containers, Tailscale, NetBird, and LAN devices
- Kill switch and firewall enabled by default
- Health check monitoring
- Security hardening with capability dropping

## Security

- Root execution required for NordVPN daemon and iptables operations
- Required capabilities: NET_ADMIN, NET_RAW
- Capability dropping: ALL dropped, only NET_ADMIN and NET_RAW added
- No new privileges: security_opt no-new-privileges:true
- TUN device access
- IP forwarding enabled
- NAT masquerading for external routing

## External Host Routing

The container acts as a full VPN router. External hosts can route traffic through it:

### Tailscale Host
```bash
sudo ip route add 0.0.0.0/0 via <docker_host_ip>
```

### NetBird Host
```bash
sudo ip route add 0.0.0.0/0 via <docker_host_ip>
```

### LAN Host
Add a static route on your router:
```
0.0.0.0/0 → <docker_host_ip>
```

## License

MIT
