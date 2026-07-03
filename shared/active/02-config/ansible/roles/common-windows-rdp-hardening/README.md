# common-windows-rdp-hardening

Harden or disable RDP on Windows 10/11 hosts.

## Default behavior: RDP disabled

Docker hosts managed via SSH + Ansible don't need RDP. The role disables the
RDP listener and removes all RDP firewall rules (including the default Windows
rule that allows Any source).

## Opt-in: RDP with hardening

Set `win_rdp_hardening_enabled: true` to enable RDP with:
- **NLA enforced** — `UserAuthentication=1` in the registry
- **Tailscale-only firewall** — inbound TCP 3389 restricted to the Tailscale
  CGNAT subnet (`100.64.0.0/10` by default). The default Windows RDP rule
  (Any source) is removed and replaced with a Tailscale-only rule.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `win_rdp_hardening_enabled` | `false` | Enable RDP (with hardening) or disable entirely |
| `win_rdp_hardening_nla_required` | `true` | Require Network Level Authentication |
| `win_rdp_hardening_allowed_subnet` | `100.64.0.0/10` | Inbound subnet restriction (Tailscale CGNAT) |
| `win_rdp_hardening_firewall_rule_name` | `RDP-Tailscale-Only` | Firewall rule name |

## Example: Enable RDP for a host that needs GUI access

```yaml
- hosts: windows_docker_hosts
  roles:
    - role: common-windows-rdp-hardening
      vars:
        win_rdp_hardening_enabled: true
```

## License

MIT
