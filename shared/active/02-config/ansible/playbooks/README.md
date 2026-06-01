# Ansible Playbooks

Shared playbooks for the infrahub infrastructure.

## Available Playbooks

### `cloud-server-bootstrap.yml`

Bootstraps cloud servers with foundational infrastructure:
- Host OS bootstrap (`host-os-bootstrap`)
- Nix package manager installation (`nix-installation`)
- Docker engine setup (`docker-engine`)
- Nix core tools installation (`nix-core-tools`)

**Usage:**

```bash
# Syntax check
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml --syntax-check

# Dry-run
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml --check --diff

# Deploy
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-bootstrap.yml
```

**Target group:** `cloud_servers`

**Requires:**
- `cloud_server_admin_user` defined in `group_vars`
- `cloud_server_ansible_host_ip` defined in `group_vars`
- `cloud_server_ssh_host_port` defined in `group_vars`

### `site.yml`

Full site playbook that deploys all enabled stacks.

**Usage:**

```bash
ansible-playbook -i inventories/localnet.yml playbooks/site.yml
```

### `dns-stack.yml`

Deploys the DNS stack.

### `proxy-stack.yml`

Deploys the proxy/web stack.

### `cloud-server-vms.yml`

Sets up the KVM hypervisor on cloud servers for VM workloads:
- CPU virtualization support verification (Intel VT-x / AMD-V)
- KVM packages and libvirtd installation (`common-kvm` role)
- NAT and routed bridge networks
- VM storage pool configuration
- Post-deployment verification of libvirt stack

**Usage:**

```bash
# Syntax check
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml --syntax-check

# Dry-run
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml --check --diff

# Deploy
ansible-playbook -i inventories/oci.yml playbooks/cloud-server-vms.yml
```

**Target group:** `cloud_servers`

**Requires:**
- `cloud_server_admin_user` defined in `group_vars`
- Nested virtualization or bare-metal host with VT-x/AMD-V

### `vpn-stack.yml`

Deploys the VPN stack.
