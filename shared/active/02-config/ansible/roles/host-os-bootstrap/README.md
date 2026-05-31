# host-os-bootstrap

Bootstrap role for fresh cloud server hosts. Handles package refresh, OpenSSH setup, timezone enforcement, user creation, sudo configuration, and automatic security updates.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `host_os_bootstrap_admin_user` | `cuser` | Admin username |
| `host_os_bootstrap_admin_uid` | `1000` | Admin user UID |
| `host_os_bootstrap_admin_gid` | `1000` | Admin group GID |
| `host_os_bootstrap_admin_shell` | `/bin/bash` | Admin user shell |
| `host_os_bootstrap_admin_groups` | `sudo` | Supplementary groups |
| `host_os_bootstrap_ssh_port` | `22` | SSH listen port |
| `host_os_bootstrap_ssh_permit_root_login` | `prohibit-password` | Root login policy |
| `host_os_bootstrap_ssh_password_auth` | `no` | Password authentication |
| `host_os_bootstrap_ssh_pubkey_auth` | `yes` | Public key authentication |
| `host_os_bootstrap_timezone` | `UTC` | System timezone |
| `host_os_bootstrap_unattended_upgrades_enabled` | `true` | Enable auto-updates |
| `host_os_bootstrap_auto_reboot` | `false` | Reboot automatically after updates |
| `host_os_bootstrap_packages` | see `defaults/main.yml` | Packages to install |
| `host_os_bootstrap_admin_authorized_keys` | `[]` | SSH public keys for admin user |
| `host_os_bootstrap_root_authorized_keys` | `[]` | SSH public keys for root |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: host-os-bootstrap
      vars:
        host_os_bootstrap_admin_user: "admin"
        host_os_bootstrap_admin_authorized_keys:
          - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
```

## License

MIT
