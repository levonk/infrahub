# common-windows-ssh-hardening

Harden OpenSSH server configuration on Windows 10/11 hosts. Mirrors
`common-ssh-hardening` (Linux) where Windows OpenSSH supports the same settings.

## What it does

1. **sshd_config hardening** — disables password auth, restricts algorithms to
   Ed25519, limits auth tries, disables forwarding/tunneling. Settings are
   inserted before the `Match Group administrators` block.
2. **ACL repair** — idempotently re-applies the Microsoft-documented ACL on
   `.ssh` (ansible + Administrators full control) and `authorized_keys`
   (ansible + `NT SERVICE\sshd` read-only). Repairs drift from manual changes
   or Windows updates.
3. **Scheduled drift check** — deploys a PowerShell script and registers a
   scheduled task that runs twice daily. If the ACL is non-conformant, it
   writes a Warning event to the Application log (source: `SSH-AclDriftCheck`).

## Requirements

- Ansible >= 2.15 with `ansible.windows` and `community.windows` collections
- Target: Windows 10/11 with OpenSSH Server installed
- **CRITICAL PRE-CONDITION**: Key-based SSH must already work (run the
  bootstrap script first). This role disables `PasswordAuthentication`.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `win_ssh_hardening_user` | `ansible` | Service account to harden |
| `win_ssh_hardening_sshd_config_path` | `C:\ProgramData\ssh\sshd_config` | sshd_config path |
| `win_ssh_hardening_password_authentication` | `no` | Disable password auth |
| `win_ssh_hardening_pubkey_accepted_algorithms` | `ssh-ed25519-cert-v01@openssh.com,ssh-ed25519` | Allowed pubkey algorithms |
| `win_ssh_hardening_host_key_algorithms` | `ssh-ed25519-cert-v01@openssh.com,ssh-ed25519` | Allowed host key algorithms |
| `win_ssh_hardening_max_auth_tries` | `3` | Max authentication attempts |
| `win_ssh_hardening_client_alive_interval` | `300` | Keepalive interval (seconds) |
| `win_ssh_hardening_client_alive_count_max` | `2` | Max missed keepalives |
| `win_ssh_hardening_allow_agent_forwarding` | `no` | Disable agent forwarding |
| `win_ssh_hardening_allow_tcp_forwarding` | `no` | Disable TCP forwarding |
| `win_ssh_hardening_permit_tunnel` | `no` | Disable tunneling |
| `win_ssh_hardening_backup_config` | `true` | Backup sshd_config before changes |
| `win_ssh_hardening_check_script_dir` | `C:\localnet\scripts` | Where to deploy the check script |
| `win_ssh_hardening_check_task_name` | `SSH-AclDriftCheck` | Scheduled task name |
| `win_ssh_hardening_check_interval_hours` | `12` | Check interval (hours) |

## Event Log

The scheduled task writes to the Windows Application Event Log:
- **Source**: `SSH-AclDriftCheck`
- **Level**: Warning
- **Event ID**: 1
- **Message**: Lists each non-conformant ACE

Query with:
```powershell
Get-EventLog -LogName Application -Source SSH-AclDriftCheck -Newest 10
```

## License

MIT
