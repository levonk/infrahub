# Hermes Agent Access Patterns

**Created**: 2026-06-21  
**Feature**: Enhanced hermes-agent container with direct VPN access  
**Purpose**: Document improved access patterns for hermes-agent container

## Overview

The hermes-agent container has been enhanced to provide direct network access via SSH, Tailscale, and Netbird, transforming it from a hidden service container into a first-class network citizen with full terminal capabilities.

## New Capabilities

### Enhanced Terminal Environment
- **SSH Server**: Direct SSH access to container
- **Tailscale**: Mesh VPN integration for secure access
- **Netbird**: Alternative VPN solution for redundancy
- **tmux**: Terminal multiplexer for session management
- **zsh**: Modern shell with improved features

### Network Integration
- **Direct Tailscale Access**: Container can join Tailscale network
- **Route Advertisement**: VM networks advertised through Tailscale
- **SSH Port Exposure**: Port 2222 on VM maps to container SSH
- **Docker Socket**: Full Docker-in-Docker capabilities retained

## Access Patterns

### Option 1: Direct Tailscale to Container (Recommended)

**When Tailscale is configured in the container:**

```bash
# From your local machine (via Tailscale network)
tailscale status  # Find the hermes-agent Tailscale IP

# Direct SSH via Tailscale
ssh -i ~/.ssh/lzkmbp2016-micro-oracle cuser@<hermes-agent-tailscale-ip>

# Or use Tailscale SSH if enabled
tailscale ssh cuser@<hermes-agent-tailscale-ip>
```

**Benefits:**
- Direct access without intermediate hops
- Encrypted mesh VPN connection
- Container has own network identity
- Works from any network with Tailscale

### Option 2: Tailscale to VM + SSH to Container

**Current setup with VM route advertisement:**

```bash
# From your local machine (via Tailscale network)
tailscale status  # Find the OCI Cloud Server Tailscale IP

# SSH to VM via Tailscale
ssh -i ~/.ssh/lzkmbp2016-micro-oracle cuser@<oci-server-tailscale-ip>

# Then SSH to container from VM
ssh -p 2222 cuser@192.168.100.147

# Or use docker exec
docker exec -it isolation-vm-hermes-agent zsh
```

**Benefits:**
- Leverages existing Tailscale infrastructure
- VM acts as network gateway
- Container access via standard SSH
- Fallback to docker exec available

### Option 3: Traditional Multi-Hop Access

**Before Tailscale route advertisement:**

```bash
# From your local machine
ssh -i ~/.ssh/lzkmbp2016-micro-oracle opc@<oci-public-ip>

# Then SSH to VM
ssh -i ~/.ssh/lzkmbp2016-micro-oracle cuser@192.168.100.147

# Then access container
docker exec -it isolation-vm-hermes-agent zsh
```

**Benefits:**
- Works without Tailscale configuration
- Traditional access pattern
- Useful for troubleshooting

## Configuration

### SSH Configuration

**Container SSH Server:**
- **Port**: 2222 (host) → 22 (container)
- **Authentication**: SSH keys only (no password)
- **User**: cuser (UID 1000)
- **Root login**: Disabled
- **X11 forwarding**: Disabled
- **TCP forwarding**: Enabled

**SSH Keys:**
- Public key configured via Ansible variable
- Stored in `/home/cuser/.ssh/authorized_keys`
- Key path: `isolation_vm_hermes_agent_ssh_public_key`

### Tailscale Configuration

**Container Tailscale:**
- **Auth Key**: Configured via environment variable `TAILSCALE_AUTH_KEY`
- **Hostname**: `hermes-agent`
- **Routes**: Accepts routes from Tailscale network
- **DNS**: Accepts DNS settings from Tailscale admin console

**VM Route Advertisement:**
- **NAT Bridge**: `192.168.100.0/24` advertised
- **Routed Bridge**: `192.168.101.0/24` advertised
- **Accept Routes**: Enabled on OCI Cloud Server

### Netbird Configuration

**Container Netbird:**
- **Setup Key**: Configured via environment variable `NETBIRD_SETUP_KEY`
- **Hostname**: `hermes-agent`
- **Alternative VPN**: Provides redundancy to Tailscale

## Terminal Environment

### Shell Configuration
- **Default Shell**: zsh
- **Terminal Multiplexer**: tmux available
- **Nix Integration**: Nix packages accessible via volume mounts
- **Docker CLI**: Full Docker command access

### Useful Commands

```bash
# Start tmux session
tmux new -s work

# List tmux sessions
tmux ls

# Attach to tmux session
tmux attach -t work

# Check Docker status
docker ps

# Check Tailscale status
tailscale status

# Check Netbird status
netbird status

# Nix operations
nix-shell -p package_name
nix-env -iA nixpkgs.package_name
```

## Security Considerations

### SSH Security
- **Key-based authentication only**: No password authentication
- **Non-root user**: Container runs as cuser (UID 1000)
- **Root login disabled**: SSH server configured to deny root access
- **X11 forwarding disabled**: Reduces attack surface

### VPN Security
- **Auth keys in vault**: Tailscale and Netbird keys stored securely
- **Network isolation**: Container on dedicated Docker network
- **Route control**: Only specific VM networks advertised
- **DNS security**: DNS settings from trusted VPN provider

### Container Security
- **Docker socket access**: Restricted to hermes-agent only
- **Read-only mounts**: Nix store and config are read-only
- **Resource limits**: CPU and memory constraints applied
- **Health checks**: Monitoring for SSH, VPN, and Docker services

## Deployment

### Rebuild Container

After updating the Dockerfile and configuration:

```bash
# From the infrahub directory
cd ~/p/gh/levonk/infrahub

# Rebuild and deploy hermes-agent container
devbox run -- rtk ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-isolation-vm-containers.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Configure VPN Keys

Add VPN auth keys to Ansible vault:

```bash
# Edit vault file
ansible-vault edit levonk/active/02-config/ansible/inventories/group_vars/all/vault.yml

# Add keys:
# vault_hermes_agent_tailscale_auth_key: "tskey-auth-..."
# vault_hermes_agent_netbird_setup_key: "..."
```

### Verify Access

```bash
# Check container is running
docker ps | grep hermes-agent

# Check health status
docker inspect isolation-vm-hermes-agent | grep -A 10 Health

# Test SSH access
ssh -p 2222 cuser@192.168.100.147

# Test Tailscale (if configured)
docker exec isolation-vm-hermes-agent tailscale status
```

## Troubleshooting

### SSH Connection Issues

```bash
# Check SSH server is running in container
docker exec isolation-vm-hermes-agent pgrep sshd

# Check SSH port mapping
docker port isolation-vm-hermes-agent

# Check SSH logs
docker logs isolation-vm-hermes-agent | grep ssh

# Test SSH from VM
ssh -p 2222 -v cuser@localhost
```

### Tailscale Connection Issues

```bash
# Check Tailscale status in container
docker exec isolation-vm-hermes-agent tailscale status

# Check Tailscale logs
docker logs isolation-vm-hermes-agent | grep tailscale

# Restart Tailscale in container
docker exec isolation-vm-hermes-agent tailscale down
docker exec isolation-vm-hermes-agent tailscale up --authkey=$KEY
```

### Netbird Connection Issues

```bash
# Check Netbird status in container
docker exec isolation-vm-hermes-agent netbird status

# Check Netbird logs
docker logs isolation-vm-hermes-agent | grep netbird

# Restart Netbird in container
docker exec isolation-vm-hermes-agent netbird down
docker exec isolation-vm-hermes-agent netbird up --setup-key=$KEY
```

## Future Enhancements

### Potential Improvements
- **Web Terminal**: Add web-based terminal access (ttyd, gotty)
- **SFTP Access**: Enable SFTP for file transfer
- **VS Code Remote**: Configure for remote development
- **Session Persistence**: Add persistent tmux sessions
- **Multi-User Support**: Add additional user accounts

### Network Enhancements
- **Tailscale Funnel**: Expose local services via Tailscale
- **Netbird Relay**: Improve Netbird connectivity
- **Custom DNS**: Configure custom DNS resolution
- **Network Policies**: Implement fine-grained network controls

## Related Documentation

- **Network Topology**: `shared/active/08-docs/network/isolation-vm-network-topology.md`
- **Tailscale Role**: `shared/active/02-config/ansible/roles/vpn-tailscale/README.md`
- **Container Standards**: `shared/active/03-container/AGENTS.md`
- **Isolation VM Tasks**: `internal-docs/feature/isolation-vm/tasks/index-isolation-vm.md`

## Summary

The enhanced hermes-agent container provides multiple access patterns for different use cases:

1. **Direct Tailscale**: Best for everyday use (simplest, most direct)
2. **Tailscale + SSH**: Good fallback with existing infrastructure
3. **Traditional Multi-Hop**: Useful for troubleshooting without VPN

The container now serves as a full-featured remote terminal environment with VPN integration, making it ideal for AI agent operations and remote development work.