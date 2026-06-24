# nix-installation

Install the Nix package manager in multi-user daemon mode, enable flakes, and add the admin user to the `nixbld` group.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- Internet connectivity to download the official Nix installer

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nix_installation_version` | `2.28.3` | Expected Nix version |
| `nix_installation_installer_url` | `https://nixos.org/nix/install` | Official installer URL |
| `nix_installation_installer_checksum` | `""` | Optional SHA-256 checksum |
| `nix_installation_daemon_mode` | `true` | Install in multi-user daemon mode |
| `nix_installation_admin_user` | `{{ cloud_server_admin_user \| default('cuser') }}` | Admin username |
| `nix_installation_nixbld_group` | `nixbld` | Nix build group name |
| `nix_installation_nixbld_gid` | `30000` | GID for the nixbld group |
| `nix_installation_nix_conf_path` | `/etc/nix/nix.conf` | Path to nix.conf |
| `nix_installation_experimental_features` | `[nix-command, flakes]` | Enabled experimental features |
| `nix_installation_extra_nix_conf` | `{}` | Extra nix.conf key-value pairs |
| `nix_installation_daemon_service_name` | `nix-daemon` | systemd service name |
| `nix_installation_verify_nix_version` | `true` | Verify installed Nix version |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: nix-installation
      vars:
        nix_installation_admin_user: "admin"
        nix_installation_experimental_features:
          - nix-command
          - flakes
          - repl-flake
```

## License

MIT
