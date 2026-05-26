# LocalNet Ansible Playbooks

Ansible playbooks to deploy LocalNet infrastructure services using direct Docker container management:
- **DNS Stack**: DNSDist, CoreDNS, dnscrypt-proxy, AdGuard, blocklist-compiler, tor-proxy
- **Proxy/Web Stack**: Traefik, Envoy, Squid, Privoxy, 9Router
- **VPN Stack**: Netbird, Tailscale, Gluetun, WireGuard (direct + transparent), Twingate

## Architecture

This playbook uses **direct `community.docker` modules** instead of wrapping `docker compose` commands. Each service has:
- Individual tasks for image building (when needed)
- Direct container management with `community.docker.docker_container`
- Granular volume management with `community.docker.docker_volume`
- Per-container health checks
- Network configuration with proper IP assignment
- Environment variable templating via Ansible

This approach provides:
- **Granular control** - manage each service independently
- **Better secrets management** - use Ansible Vault for sensitive values
- **Idempotence** - safe to run multiple times
- **Dependency management** - explicit service start order
- **Native Ansible features** - variables, conditionals, loops

## Quick Start

```bash
# Install required collections
ansible-galaxy collection install -r requirements.yml

# Deploy everything
ansible-playbook -i inventories/localnet.yml playbooks/site.yml

# Deploy individual stacks
ansible-playbook -i inventories/localnet.yml playbooks/dns-stack.yml
ansible-playbook -i inventories/localnet.yml playbooks/proxy-stack.yml
ansible-playbook -i inventories/localnet.yml playbooks/vpn-stack.yml
```

## Directory Structure

```
.
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Required collections
├── inventories/
│   └── localnet.yml         # Local inventory (update for remote hosts)
├── group_vars/
│   └── all.yml              # Common variables (ports, IPs, networks)
├── playbooks/
│   ├── site.yml             # Full deployment
│   ├── dns-stack.yml        # DNS services only
│   ├── proxy-stack.yml      # Proxy services only
│   └── vpn-stack.yml        # VPN services only
└── roles/
    ├── common/              # Docker, networks, volumes
    ├── dns/                 # DNS stack tasks
    ├── proxy/               # Proxy stack tasks
    └── vpn/                 # VPN stack tasks
```

## Inventory

Edit `inventories/localnet.yml` to target remote hosts:

```yaml
localnet_hosts:
  hosts:
    localnet-primary:
      ansible_host: 192.168.1.100
      ansible_user: admin
      ansible_ssh_private_key_file: ~/.ssh/localnet
```

## Variables

Key variables in `group_vars/all.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `localnet_base_dir` | `~/localnet` | Base installation path |
| `dns_stack_enabled` | `true` | Enable DNS deployment |
| `proxy_stack_enabled` | `true` | Enable Proxy deployment |
| `vpn_stack_enabled` | `true` | Enable VPN deployment |
| `dns_transparent_host_port` | `5500` | DNSDist transparent mode port |
| `dns_coredns_main_host_port` | `15354` | CoreDNS direct port |
| `proxy_direct_port` | `3128` | Squid direct proxy port |
| `wireguard_direct_port` | `51820` | WireGuard UDP port |

## Tags

Use tags to run specific roles:

```bash
ansible-playbook -i inventories/localnet.yml playbooks/site.yml --tags common,dns
ansible-playbook -i inventories/localnet.yml playbooks/site.yml --tags proxy
ansible-playbook -i inventories/localnet.yml playbooks/site.yml --tags vpn
```

## Service Files

Playbooks use Docker build contexts and configuration files from the LocalNet repository. Ensure the repository is cloned at the path specified in `localnet_base_dir` (default: `~/localnet`).

For local deployment (`ansible_connection: local`), playbooks assume the repository is at the correct path. For remote deployment, ensure the repository is cloned to the target host first.

## Secrets Management

Sensitive values (WireGuard keys, Twingate tokens, etc.) should be managed via Ansible Vault:

1. Create `group_vars/all.vault` with secrets:
   ```yaml
   ---
   wireguard_private_key: "your-private-key"
   wireguard_preshared_key: "your-preshared-key"
   twingate_tenant_url: "https://tenant.twingate.com"
   twingate_access_token: "your-access-token"
   twingate_refresh_token: "your-refresh-token"
   traefik_acme_email: "your-email@example.com"
   ```

2. Encrypt the vault file:
   ```bash
   ansible-vault encrypt group_vars/all.vault --vault-id localnet
   ```

3. Run playbooks with vault password:
   ```bash
   ansible-playbook -i inventories/localnet.yml playbooks/site.yml --ask-vault-pass
   ```

See `group_vars/all.yml` for the complete secrets section with vault variable references.
