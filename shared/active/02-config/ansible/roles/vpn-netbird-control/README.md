# vpn-netbird-control

Ansible role that deploys the self-hosted NetBird control plane as Docker containers.

## Description

This role consolidates the three core NetBird control plane services into a single deployment:

- **Management Server** — API, user/device management, IdP integration
- **Signal Server** — WebRTC signalling relay
- **Relay (TURN) Server** — NAT traversal relay for peer-to-peer connections

All services run on a dedicated Docker network with health checks and automatic restarts.

## Requirements

- Docker Engine installed on the target host
- `community.docker` Ansible collection
- Target host must be in the `docker` group or playbook must run with `become: true`

## Role Variables

### Container Images

| Variable | Default | Description |
|----------|---------|-------------|
| `netbird_control_mgmt_image_name` | `netbirdio/management:latest` | Management container image |
| `netbird_control_signal_image_name` | `netbirdio/signal:latest` | Signal container image |
| `netbird_control_relay_image_name` | `netbirdio/relay:latest` | Relay container image |

### Ports

All ports are variable-driven and reference `cloud_server` group_vars per AGENTS.md rules:

| Variable | Default Source | Description |
|----------|----------------|-------------|
| `netbird_control_mgmt_host_port` | `cloud_server_netbird_mgmt_host_port` | Management host port |
| `netbird_control_mgmt_container_port` | `cloud_server_netbird_mgmt_container_port` | Management container port |
| `netbird_control_signal_host_port` | `cloud_server_netbird_signal_host_port` | Signal host port |
| `netbird_control_signal_container_port` | `cloud_server_netbird_signal_container_port` | Signal container port |
| `netbird_control_relay_host_port` | `cloud_server_netbird_turn_host_port` | Relay host port |
| `netbird_control_relay_container_port` | `cloud_server_netbird_turn_container_port` | Relay container port |

### IdP / OIDC Configuration

Set these via `host_vars` or encrypted `group_vars` to enable SSO:

| Variable | Default | Description |
|----------|---------|-------------|
| `netbird_control_mgmt_idp_provider` | `none` | IdP provider type |
| `netbird_control_mgmt_idp_client_id` | `""` | OIDC client ID |
| `netbird_control_mgmt_idp_client_secret` | `""` | OIDC client secret |
| `netbird_control_mgmt_idp_authorization_endpoint` | `""` | OIDC authorization endpoint |
| `netbird_control_mgmt_idp_token_endpoint` | `""` | OIDC token endpoint |
| `netbird_control_mgmt_idp_jwks_uri` | `""` | OIDC JWKS URI |

### Other Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `netbird_control_network_name` | `netbird-control` | Dedicated Docker network |
| `netbird_control_mgmt_data_dir` | `{{ localnet_services_dir }}/netbird/management` | Management data path |
| `netbird_control_mgmt_log_level` | `info` | Log level for management |
| `netbird_control_signal_log_level` | `info` | Log level for signal |
| `netbird_control_relay_log_level` | `info` | Log level for relay |

## Dependencies

- `docker-engine` role (declared in `meta/main.yml`)

## Example Playbook

```yaml
- name: Deploy NetBird control plane
  hosts: netbird_control_servers
  become: true
  roles:
    - vpn-netbird-control
```

## License

MIT
