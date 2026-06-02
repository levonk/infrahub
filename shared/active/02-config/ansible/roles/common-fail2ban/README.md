# common-fail2ban

Install and configure fail2ban for SSH brute-force protection.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `fail2ban_bantime` | `cloud_server_fail2ban_bantime` or `3600` | Duration (seconds) a host is banned |
| `fail2ban_maxretry` | `cloud_server_fail2ban_maxretry` or `5` | Max failed attempts before ban |
| `fail2ban_findtime` | `cloud_server_fail2ban_findtime` or `600` | Time window (seconds) for counting retries |
| `fail2ban_ignoreip` | `cloud_server_fail2ban_ignoreip` or `['127.0.0.1/8', '::1']` | IPs/CIDRs to never ban |
| `fail2ban_sshd_port` | `cloud_server_ssh_host_port` or `22` | SSH port to monitor |
| `fail2ban_backend` | `systemd` | Log backend (systemd or auto) |

## Client Overrides

Override defaults in `group_vars/cloud_server.yml`:

```yaml
cloud_server_fail2ban_bantime: 3600
cloud_server_fail2ban_maxretry: 3
cloud_server_fail2ban_findtime: 300
cloud_server_fail2ban_ignoreip:
  - "127.0.0.1/8"
  - "::1"
  - "{{ tailscale_subnet }}"
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: common-fail2ban
```

## License

MIT
