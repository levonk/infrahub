# LocalNet Ansible Playbooks

Ansible playbooks to deploy LocalNet infrastructure services:
- **DNS Stack**: DNSDist, CoreDNS, dnscrypt-proxy, AdGuard, blocklist-compiler
- **Proxy/Web Stack**: Traefik, Envoy, Squid, Privoxy, Authelia, CrowdSec, Tor
- **VPN Stack**: Netbird, Tailscale, Gluetun, WireGuard, Twingate

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

Playbooks assume Docker Compose service files exist at:
`../../../container/services/{dns,proxy,vpn}/docker-compose.*.yml`

When running locally (`ansible_connection: local`), files are synchronized automatically. For remote hosts, ensure the LocalNet repository is cloned to the target first.
