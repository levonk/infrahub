# Ansible Inventories

This directory contains client-specific Ansible inventories for the `levonk` client.

## Files

| File | Purpose |
|------|---------|
| `production.yml` | Template for localnet/production hosts |
| `oci.yml` | OCI cloud-server inventory defining the `cloud_servers` group |

## OCI Inventory (`oci.yml`)

The `oci.yml` inventory defines a single host group `cloud_servers` containing the
`oci-cloud-server` host. All connection parameters are variable-driven:

- `ansible_host`: resolved from `cloud_server_ansible_host_ip` (group_var)
- `ansible_user`: resolved from `cloud_server_admin_user` (group_var)
- `ansible_ssh_private_key_file`: resolved from `cloud_server_ssh_private_key_file` (group_var)
- `ansible_port`: resolved from `cloud_server_ssh_host_port` (group_var / host_var)

Host-specific overrides live in `../host_vars/oci-cloud-server.yml`.

## Usage

```bash
# List inventory
ansible-inventory --list -i levonk/active/02-config/ansible/inventories/oci.yml

# Check connectivity
ansible -i levonk/active/02-config/ansible/inventories/oci.yml cloud_servers -m ping
```

## Variable Sources

Variable resolution follows Ansible's standard precedence:

1. `all.yml` — cross-cutting defaults (user identity, timezone, python interpreter)
2. `cloud_server.yml` — group-specific service variables (ports, IPs, feature flags)
3. `oci-cloud-server.yml` — host-specific overrides (VPN priority, image OCID, DDNS)

## Rules

- **No hardcoded IP addresses** — always use `group_vars` variables.
- **No hardcoded credentials** — SSH keys referenced via variables.
- **Never commit real IPs publicly** — `production.yml` is a template only.
