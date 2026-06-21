# Isolation VM Network Topology

**Created**: 2026-06-20  
**Feature**: Isolation VM for AI Agent Isolation  
**Purpose**: Document network architecture, routing rules, and security boundaries

## Overview

The Isolation VM uses a multi-layered network architecture to provide secure isolation for AI agent operations while maintaining connectivity to external resources through VPN/proxy routing.

## Network Layers

### Layer 1: Host Hypervisor Networks
- **kvm-nat-br0**: NAT bridge for VM outbound connectivity (192.168.100.0/24)
- **kvm-route-br0**: Routed bridge for VM external access (192.168.101.0/24)

### Layer 2: VM Internal Networks
- **isolation-vm-br0**: Docker bridge network for container communication (172.28.0.0/16)
- **Gateway**: 172.28.0.1
- **Subnet Size**: /24 per address pool

### Layer 3: Container Networks
All containers connect to `isolation-vm-network` (Docker bridge network 172.28.0.0/16)

## Container Network Configuration

### Container IP Allocation
- **nix-sidecar**: 172.28.0.2 (first container on network)
- **base-kalinix**: 172.28.0.3 (second container)
- **hermes-agent**: 172.28.0.4 (third container)

### Volume Mount Architecture

#### Nix Sidecar Pattern
The nix-sidecar container provides Nix package management to other containers via read-only volume mounts:

**nix-sidecar volumes**:
- `/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-store:ro` (Nix store - read-only)
- `/etc/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-config:ro` (Nix config - read-only)
- `/root/.cache/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-cache` (Nix cache - read-write)

**base-kalinix volumes** (inherits from nix-sidecar):
- `/home/cuser` → `/var/lib/isolation-vm/base-kalinix/home` (user home directory)
- `/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-store:ro` (Nix store - read-only)
- `/etc/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-config:ro` (Nix config - read-only)
- `/root/.cache/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-cache` (Nix cache - read-write)

**hermes-agent volumes** (inherits from nix-sidecar + Docker socket):
- `/data/hermes-agent` → `/var/lib/isolation-vm/hermes-agent/data` (agent data directory)
- `/config/hermes-agent` → `/var/lib/isolation-vm/hermes-agent/config` (agent config directory)
- `/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-store:ro` (Nix store - read-only)
- `/etc/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-config:ro` (Nix config - read-only)
- `/root/.cache/nix` → `/var/lib/isolation-vm/nix-sidecar/nix-cache` (Nix cache - read-write)
- `/var/run/docker.sock` → `/var/run/docker.sock` (Docker socket for container management)

## Routing Rules

### Default Routing (No VPN)
When VPN routing is disabled (`isolation_vm_enable_vpn_routing: false`):
- Container traffic uses default Docker bridge routing
- External access via host's default gateway
- NAT masquerading enabled in Docker daemon

### VPN Routing (Optional)
When VPN routing is enabled (`isolation_vm_enable_vpn_routing: true`):
- Custom routing table `isolation-vm` (table 200)
- Container traffic (172.28.0.0/16) routed through VPN gateway
- Default route via VPN gateway (default: 192.168.101.1)
- IP forwarding enabled on host
- Bridge netfilter enabled for firewall rules

### System Network Configuration
**IP Forwarding**: Enabled in `/etc/sysctl.d/99-isolation-vm-networking.conf`
```bash
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

**Docker Daemon Configuration**: `/etc/docker/daemon.json`
```json
{
  "iptables": true,
  "ip-masq": true,
  "userland-proxy": false,
  "default-address-pools": [
    {
      "base": "172.28.0.0/16",
      "size": 24
    }
  ],
  "metrics-addr": "127.0.0.1:9323"
}
```

## Firewall Rules

### Firewalld Configuration (When Available)
- **Zone**: trusted
- **Interface**: isolation-vm-br0
- **Source**: 172.28.0.0/16 (container network)
- **Policy**: Allow all container network communication

### Security Boundaries
1. **Container-to-Container**: Full communication allowed on isolation-vm-network
2. **Container-to-Host**: Restricted via Docker bridge security
3. **Container-to-External**: Controlled by routing rules (VPN vs direct)
4. **Host-to-Container**: Limited to Docker daemon management

## Inter-Container Communication

### Communication Matrix
| Source | Destination | Protocol | Purpose |
|--------|-------------|----------|---------|
| base-kalinix | nix-sidecar | TCP/UDP | Nix package access |
| hermes-agent | nix-sidecar | TCP/UDP | Nix package access |
| hermes-agent | base-kalinix | TCP/UDP | Agent operations |
| hermes-agent | Docker socket | Unix socket | Container management |

### DNS Resolution
Containers use Docker's embedded DNS server (127.0.0.11:53) for:
- Container name resolution (nix-sidecar, base-kalinix, hermes-agent)
- External DNS queries (forwarded to host DNS)

## Security Considerations

### Volume Security
- **Read-only mounts**: Nix store and config are read-only to prevent accidental modification
- **Permission isolation**: Each volume owned by `cuser` (UID 1000, GID 1000)
- **Docker socket access**: Restricted to hermes-agent only (for container management)

### Network Isolation
- **Bridge isolation**: Containers on dedicated bridge network (isolation-vm-br0)
- **Subnet separation**: Container network (172.28.0.0/16) separate from host networks
- **Firewall zones**: Trusted zone for container communication
- **IP masquerading**: NAT for container external access

### VPN Integration
- **Optional routing**: VPN routing can be enabled/disabled via configuration
- **Traffic segregation**: Container traffic can be forced through VPN gateway
- **Fallback support**: Direct routing available when VPN is disabled
- **Current state**: VPN routing disabled (`isolation_vm_enable_vpn_routing: false`)
- **VPN gateway**: 192.168.101.1 (routed bridge kvm-route-br0)
- **Custom routing table**: Table 200 (isolation-vm) when VPN routing enabled

## VPN Routing Testing

### Test Infrastructure
- **Test playbook**: `shared/active/02-config/ansible/playbooks/test-vpn-routing.yml`
- **Test role**: `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/vpn-routing.yml`
- **Test plan**: `internal-docs/feature/isolation-vm/test-results/vpn-routing-test-plan.md`

### Test Coverage
- Basic connectivity from all containers to external networks
- External IP verification (NAT masquerading vs VPN gateway)
- DNS resolution through Docker embedded DNS
- Split-tunneling configuration (local vs external routing)
- Firewall rules enforcement (iptables/firewalld)
- VPN fallback behavior (manual test documented)
- Packet capture capability (tcpdump for advanced routing verification)

### Test Execution
```bash
# Run VPN routing tests
ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/test-vpn-routing.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Expected Results (VPN Disabled)
- All containers can reach external networks
- External IP matches host public IP (NAT masquerading)
- DNS resolution works via Docker embedded DNS
- Local network traffic uses Docker bridge routing
- External traffic uses host default gateway
- Firewall rules allow container network communication

## Testing and Validation

### Network Tests
- Inter-container ping tests (base-kalinix ↔ nix-sidecar ↔ hermes-agent)
- Volume mount verification (mountpoint checks)
- Nix access tests (nix --version from containers)
- Docker socket access (docker ps from hermes-agent)
- External connectivity (ping 8.8.8.8 from containers)

### Health Checks
Each container includes health check scripts:
- **nix-sidecar**: `/nix-sidecar/healthcheck-nix-sidecar.sh`
- **base-kalinix**: `/base-kalinix/healthcheck-base-kalinix.sh`
- **hermes-agent**: `/hermes-agent/healthcheck-hermes-agent.sh`

Volume health check scripts:
- **nix-sidecar**: `/var/lib/isolation-vm/nix-sidecar/check-volumes.sh`
- **base-kalinix**: `/var/lib/isolation-vm/base-kalinix/check-volumes.sh`
- **hermes-agent**: `/var/lib/isolation-vm/hermes-agent/check-volumes.sh`

## Configuration Variables

All network and volume configurations are variable-driven per AGENTS.md requirements:

**Network Variables**:
- `isolation_vm_network_subnet`: "172.28.0.0/16"
- `isolation_vm_network_gateway`: "172.28.0.1"
- `isolation_vm_network_subnet_size`: 24
- `isolation_vm_enable_vpn_routing`: false
- `isolation_vm_vpn_gateway`: "192.168.101.1"
- `isolation_vm_docker_metrics_address`: "127.0.0.1:9323"

**Volume Variables**:
- `isolation_vm_nix_sidecar_volume_path`: "/var/lib/isolation-vm/nix-sidecar"
- `isolation_vm_base_kalinix_volume_path`: "/var/lib/isolation-vm/base-kalinix"
- `isolation_vm_hermes_agent_volume_path`: "/var/lib/isolation-vm/hermes-agent"
- `isolation_vm_hermes_agent_data_dir`: "/data/hermes-agent"
- `isolation_vm_hermes_agent_config_dir`: "/config/hermes-agent"

## Troubleshooting

### Common Issues

**Containers cannot communicate**:
- Check Docker bridge network: `docker network inspect isolation-vm-network`
- Verify firewall rules: `firewall-cmd --list-all --zone=trusted`
- Check IP forwarding: `sysctl net.ipv4.ip_forward`

**Volume mounts failing**:
- Verify volume directories exist: `ls -la /var/lib/isolation-vm/`
- Check permissions: `ls -ld /var/lib/isolation-vm/*/`
- Test mount points: `docker exec <container> mountpoint -q /nix`

**Nix not accessible from containers**:
- Verify nix-sidecar is running: `docker ps | grep nix-sidecar`
- Check volume mounts: `docker inspect nix-sidecar | grep Mounts`
- Test Nix access: `docker exec base-kalinix nix --version`

**VPN routing not working**:
- Check routing table: `ip route show table isolation-vm`
- Verify sysctl settings: `sysctl net.ipv4.ip_forward`
- Check VPN gateway connectivity: `ping 192.168.101.1`

## Related Documentation

- **PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`
- **Ansible Role**: `shared/active/02-config/ansible/roles/isolation-vm-containers/`
- **Test Playbook**: `shared/active/02-config/ansible/playbooks/test-isolation-vm-networking.yml`
- **OCI Cloud Server Host PRD**: `shared/active/08-docs/reqs/2026/20260619-oci-cloud-server-host.md`
