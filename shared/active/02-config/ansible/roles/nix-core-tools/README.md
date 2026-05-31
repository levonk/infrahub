# nix-core-tools

Install core tools (zsh, neovim, mosh, devbox) via the Nix package manager, set zsh as the default shell for the admin user, and configure time synchronization.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- The `nix-installation` role must be applied first (declared as a dependency)

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nix_core_tools_admin_user` | `{{ cloud_server_admin_user \| default('cuser') }}` | Admin username |
| `nix_core_tools_admin_home` | `/home/{{ nix_core_tools_admin_user }}` | Admin user's home directory |
| `nix_core_tools_nix_bin_path` | `/nix/var/nix/profiles/default/bin` | Path to Nix binaries |
| `nix_core_tools_packages` | `[zsh, neovim, mosh, devbox]` | List of Nix packages to install |
| `nix_core_tools_set_zsh_default` | `true` | Set zsh as the default shell |
| `nix_core_tools_zsh_path` | `{{ nix_core_tools_nix_profile_bin }}/zsh` | Path to zsh binary |
| `nix_core_tools_time_sync_method` | `systemd-timesyncd` | Time sync method |
| `nix_core_tools_ntp_servers` | Debian pool servers | NTP servers for timesyncd |
| `nix_core_tools_verify_install` | `true` | Verify tool availability after install |

## Dependencies

- `nix-installation`

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: nix-core-tools
      vars:
        nix_core_tools_admin_user: "admin"
        nix_core_tools_packages:
          - zsh
          - neovim
          - mosh
          - devbox
```

## License

MIT
