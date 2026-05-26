# NetBird Gateway Agent Ansible Role

This Ansible role installs and configures the NetBird gateway agent on hosts/VMs.

## Requirements

- Target host must support NetBird (Linux, macOS, Windows)
- Internet connectivity for downloading NetBird agent
- NetBird management server URL and setup key

## Role Variables

### Default Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `netbird_agent_version` | `latest` | NetBird agent version to install |
| `netbird_agent_install_dir` | `/usr/local/bin` | Installation directory for NetBird agent |
| `netbird_agent_config_dir` | `/etc/netbird` | Configuration directory |
| `netbird_agent_service_enabled` | `true` | Enable NetBird agent service on boot |
| `netbird_agent_service_state` | `started` | Desired service state |

### Required Variables

These variables must be defined in inventory or playbook:

| Variable | Description |
|----------|-------------|
| `netbird_management_url` | NetBird management server URL |
| `netbird_setup_key` | NetBird setup key for registration |
| `netbird_agent_hostname` | Hostname to register with NetBird (defaults to inventory_hostname) |

## Dependencies

None

## Usage

### Example Playbook

```yaml
---
- name: Install NetBird Gateway Agent
  hosts: homelab_servers
  become: true
  roles:
    - netbird-gateway-agent
  vars:
    netbird_management_url: "https://netbird.example.com"
    netbird_setup_key: "your-setup-key-here"
```

### Override Variables

```yaml
- hosts: cloud_vps
  roles:
    - role: netbird-gateway-agent
      vars:
        netbird_agent_version: "0.25.0"
        netbird_agent_service_state: "restarted"
```

## Tasks

The role performs the following tasks:

1. **System Detection**: Detects OS family and architecture
2. **Package Installation**: Installs required dependencies (curl, wget)
3. **Agent Download**: Downloads NetBird agent binary
4. **Agent Installation**: Installs agent to system path
5. **Configuration**: Creates NetBird configuration file
6. **Service Setup**: Configures and enables NetBird system service
7. **Service Start**: Starts NetBird agent service

## Security Features

- Downloads from official NetBird GitHub releases
- Verifies binary checksum (when available)
- Runs as non-root user where supported
- Minimal system dependencies

## Architecture Note

NetBird uses a single agent binary that serves as both client and gateway. This role installs the agent in "gateway mode" which allows routing traffic for other peers in the mesh.

## License

MIT

## Author Information

LocalNet Project
