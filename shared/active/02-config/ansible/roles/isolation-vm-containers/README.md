# isolation-vm-containers Ansible Role

Deploys containers inside the Isolation VM for AI agent operations, including nix-sidecar and base-kalinix containers.

## Role Variables

### Nix Sidecar Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_deploy_nix_sidecar` | `true` | Control nix-sidecar deployment |
| `isolation_vm_nix_sidecar_container_name` | `isolation-vm-nix-sidecar` | Container name |
| `isolation_vm_nix_sidecar_image_name` | `isolation-vm-nix-sidecar:latest` | Image name |
| `isolation_vm_nix_sidecar_network_name` | `isolation-vm-network` | Docker network name |
| `isolation_vm_nix_sidecar_volume_path` | `/var/lib/isolation-vm/nix-sidecar` | Volume mount path |

### User Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_user` | `cuser` | Non-root user in VM |
| `isolation_vm_user_uid` | `1000` | User UID |
| `isolation_vm_user_gid` | `1000` | User GID |
| `isolation_vm_timezone` | `UTC` | Timezone setting |

### Healthcheck Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_nix_sidecar_healthcheck_interval` | `240s` | Healthcheck interval |
| `isolation_vm_nix_sidecar_healthcheck_timeout` | `120s` | Healthcheck timeout |
| `isolation_vm_nix_sidecar_healthcheck_retries` | `3` | Healthcheck retries |
| `isolation_vm_nix_sidecar_healthcheck_start_period` | `240s` | Healthcheck start period |
| `isolation_vm_nix_sidecar_startup_timeout` | `600` | Container startup timeout |

### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_nix_sidecar_mem_limit` | `2g` | Memory limit |
| `isolation_vm_nix_sidecar_cpu_limit` | `2.0` | CPU limit |

### Base KaliNix Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_deploy_base_kalinix` | `true` | Control base-kalinix deployment |
| `isolation_vm_base_kalinix_container_name` | `isolation-vm-base-kalinix` | Container name |
| `isolation_vm_base_kalinix_image_name` | `isolation-vm-base-kalinix:latest` | Image name |
| `isolation_vm_base_kali_image_name` | `isolation-vm-base-kali:latest` | Base Kali image name |
| `isolation_vm_base_kalinix_volume_path` | `/var/lib/isolation-vm/base-kalinix` | Volume mount path |

### Base KaliNix Healthcheck Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_base_kalinix_healthcheck_interval` | `30s` | Healthcheck interval |
| `isolation_vm_base_kalinix_healthcheck_timeout` | `30s` | Healthcheck timeout |
| `isolation_vm_base_kalinix_healthcheck_retries` | `3` | Healthcheck retries |
| `isolation_vm_base_kalinix_healthcheck_start_period` | `60s` | Healthcheck start period |
| `isolation_vm_base_kalinix_startup_timeout` | `300` | Container startup timeout |

### Base KaliNix Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `isolation_vm_base_kalinix_mem_limit` | `2g` | Memory limit |
| `isolation_vm_base_kalinix_cpu_limit` | `1.0` | CPU limit |

## Dependencies

- `isolation-vm-docker` - Docker server must be installed in VM
- `isolation-vm-config` - VM networking and user configuration

## Usage

### Basic Usage

```yaml
- hosts: isolation_vms
  roles:
    - role: isolation-vm-containers
```

### With Custom Configuration

```yaml
- hosts: isolation_vms
  roles:
    - role: isolation-vm-containers
      vars:
        isolation_vm_nix_sidecar_container_name: my-nix-sidecar
        isolation_vm_nix_sidecar_network_name: custom-network
```

## Deployment

Deploy to Isolation VM:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-isolation-vm-containers.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Verification

Check nix-sidecar container status:

```bash
# From within the Isolation VM
docker ps | grep nix-sidecar
docker exec isolation-vm-nix-sidecar nix --version
```

Check base-kalinix container status:

```bash
# From within the Isolation VM
docker ps | grep base-kalinix
docker exec isolation-vm-base-kalinix nix --version
docker exec isolation-vm-base-kalinix which nmap
docker exec isolation-vm-base-kalinix nmap --version
```

Run comprehensive test playbook:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/test-base-kalinix.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Architecture

### Nix Sidecar

The nix-sidecar container provides Nix package management to other containers via volume mounts:

- `/nix` - Nix store (read-only)
- `/etc/nix` - Nix configuration (read-only)
- `/root/.cache/nix` - Nix cache (read-only)

This pattern avoids installing Nix directly in each container and provides a centralized Nix environment.

### Base KaliNix

The base-kalinix container provides Kali Linux security tools with Nix package management:

- **Kali Linux Tools**: Includes nmap, netcat, tcpdump, wireshark-common, burpsuite, gobuster, dirb, nikto, sqlmap, metasploit-framework, john, hashcat, and many more security testing tools
- **Nix Integration**: Access to Nix package management via volume mounts from nix-sidecar
- **User Environment**: Runs as non-root user (cuser:1000) with sudo access
- **Home Directory**: Persistent home directory for tool configurations and data

#### Available Kali Tools

The base-kalinix container includes the following categories of security tools:

- **Network Tools**: nmap, netcat-traditional, tcpdump, wireshark-common, dnsutils
- **Web Security**: burpsuite, gobuster, dirb, nikto, sqlmap
- **Exploitation**: metasploit-framework, exploitdb
- **Password Cracking**: john, hashcat
- **Forensics**: autopsy, sleuthkit
- **Reconnaissance**: recon-ng, theharvester, maltego
- **Development**: python3, golang, rustc, cargo

Additional tools can be installed via Nix package management.

## Security Notes

- Container runs as non-root user (cuser:1000)
- Privileged mode is required for Nix operations
- Volume mounts are read-only where appropriate
- Healthchecks ensure container availability

## Compliance

- Follows AGENTS.md variable-driven configuration requirements
- No hardcoded IPs or ports
- Uses Docker Compose service standards from base services
- Implements Nix sidecar pattern from localnet architecture