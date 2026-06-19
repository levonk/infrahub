# RustDesk Server Role

Deploys RustDesk server (hbbs and hbbr) as Docker containers for remote desktop access with VPN-only access control.

## Requirements

- Docker engine installed and running
- VPN configured (Tailscale and/or NetBird)
- Firewall (ufw or nftables) for access control

## Role Variables

### Container Configuration

```yaml
rustdesk_server_image: "rustdesk/rustdesk-server"
rustdesk_server_image_tag: "latest"
rustdesk_server_hbbs_container_name: "rustdesk-hbbs"
rustdesk_server_hbbr_container_name: "rustdesk-hbbr"
rustdesk_server_volume_name: "rustdesk-server-data"
```

### Network Configuration

```yaml
rustdesk_server_network_name: "cloud-server"
rustdesk_server_network_mode: "host"  # Recommended for Linux
```

### Port Configuration

```yaml
# hbbs ports
rustdesk_server_hbbs_nat_test_host_port: "21115"
rustdesk_server_hbbs_id_reg_host_port: "21116"
rustdesk_server_hbbs_web_host_port: "21118"

# hbbr ports
rustdesk_server_hbbr_relay_host_port: "21117"
rustdesk_server_hbbr_web_host_port: "21119"
```

### Service Configuration

```yaml
rustdesk_server_always_use_relay: "N"
rustdesk_server_enable_web_client: false
```

### VPN Access Control

```yaml
rustdesk_server_vpn_only: true
rustdesk_server_allowed_vpn_subnets:
  - "100.64.0.0/10"  # Tailscale
  - "100.100.0.0/10" # NetBird
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: rustdesk-server
      vars:
        rustdesk_server_vpn_only: true
        rustdesk_server_allowed_vpn_subnets:
          - "100.64.0.0/10"
          - "100.100.0.0/10"
```

## License

MIT

## Author Information

levonk
