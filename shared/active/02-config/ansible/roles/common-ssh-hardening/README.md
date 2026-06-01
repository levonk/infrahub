# common-ssh-hardening

Harden SSH configuration on Debian/Ubuntu hosts by enforcing key-only authentication, restricting algorithms, and disabling unnecessary features.

## Requirements

- Ansible >= 2.15
- Target host: Debian 12 (bookworm) or Ubuntu 22.04/24.04
- **CRITICAL PRE-CONDITION**: Passwordless key-based SSH login MUST be configured before applying this role.
  - Misapplication will lock you out of the host permanently.
  - The role includes a safety check that fails if `~/.ssh/authorized_keys` is missing.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ssh_hardening_port` | `{{ cloud_server_ssh_host_port \| default('22') }}` | SSH listener port |
| `ssh_hardening_permit_root_login` | `no` | Disable root login |
| `ssh_hardening_password_authentication` | `no` | Disable password authentication |
| `ssh_hardening_authentication_methods` | `publickey` | Require public-key auth |
| `ssh_hardening_pubkey_accepted_algorithms` | `ssh-ed25519-cert-v01@openssh.com,ssh-ed25519` | Allowed pubkey algorithms |
| `ssh_hardening_host_key_algorithms` | `ssh-ed25519-cert-v01@openssh.com,ssh-ed25519` | Allowed host key algorithms |
| `ssh_hardening_max_auth_tries` | `3` | Max authentication attempts |
| `ssh_hardening_client_alive_interval` | `300` | Keepalive interval (seconds) |
| `ssh_hardening_client_alive_count_max` | `2` | Max missed keepalives before disconnect |
| `ssh_hardening_challenge_response_auth` | `no` | Disable challenge-response |
| `ssh_hardening_use_pam` | `yes` | Keep PAM enabled for session management |
| `ssh_hardening_x11_forwarding` | `no` | Disable X11 forwarding |
| `ssh_hardening_allow_agent_forwarding` | `no` | Disable SSH agent forwarding |
| `ssh_hardening_allow_tcp_forwarding` | `no` | Disable TCP forwarding |
| `ssh_hardening_permit_tunnel` | `no` | Disable tunneling |
| `ssh_hardening_verify_passwordless` | `true` | Fail if `~/.ssh/authorized_keys` is missing |
| `ssh_hardening_backup_config` | `true` | Backup existing `sshd_config` before changes |

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: common-ssh-hardening
      vars:
        ssh_hardening_port: 2222
```

## Security Notes

- **Lockout risk**: This role disables `PasswordAuthentication`. Ensure key-based access works before running.
- **Backup**: `sshd_config` is backed up automatically before any change.
- **Validation**: Every `lineinfile` change validates the config with `sshd -t` before writing.
- **Algorithm restriction**: Only Ed25519 keys are accepted. Ensure your keys use this algorithm.

## License

MIT
