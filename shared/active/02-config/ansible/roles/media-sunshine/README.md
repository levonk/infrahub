# media-sunshine

Deploys [Sunshine](https://github.com/LizardByte/Sunshine) — the self-hosted
GameStream host for Moonlight clients — as a **native Windows install** on
`windows_docker_hosts` (dtop202311). Streams the real Windows desktop over
Tailscale. **Not a container**: Docker Desktop on Windows can only stream a
virtualized Linux desktop — native install is required for Windows display
capture + NVENC/AMF/QSV encode (see `internal-docs/research/service/sunshine/`).

## What it does

1. **Install** — `winget install LizardByte.Sunshine` (idempotent: checks for
   `C:\Program Files\Sunshine\sunshine.exe` first; mirrors the
   bootstrap-windows-docker-host.yml `INSTALLED`/`NOT_INSTALLED` pattern).
2. **Config** — renders `sunshine.conf` into `C:\Program Files\Sunshine\config\`
   with `origin_web_ui_allowed = wan` (Tailscale's 100.64.0.0/10 CGNAT range is
   NOT RFC1918, so the default `lan` refuses the Web UI over Tailscale) and
   `upnp = disabled`.
3. **Credentials** — `sunshine.exe --creds <user> <pass>` (headless Web UI
   admin provisioning) when `media_sunshine_web_username` /
   `media_sunshine_web_password` are non-empty. Runs `no_log: true`.
4. **Firewall** — ensures `Sunshine-*` inbound allow rules for the full
   GameStream port family (idempotent Get-NetFirewallRule → New-NetFirewallRule).
5. **Service** — ensures `SunshineService` (auto-start) is running.

## Requirements

- Target: Windows 10/11 host reachable over OpenSSH (`ansible_shell_type:
  powershell`), already bootstrapped via `bootstrap-windows-docker-host.yml`
  (winget present, Tailscale connected).
- `ansible.windows` collection (bundled with Ansible core).
- **No Python on target by design** — all tasks are `ansible.windows`/`meta`
  PowerShell modules.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `media_sunshine_enabled` | `true` | Master switch |
| `media_sunshine_winget_id` | `LizardByte.Sunshine` | winget package id |
| `media_sunshine_install_dir` | `C:\Program Files\Sunshine` | MSI install dir |
| `media_sunshine_config_dir` | `<install>\config` | sunshine.conf dir |
| `media_sunshine_service_name` | `SunshineService` | Windows service name |
| `media_sunshine_name` | `windows_tailscale_hostname` | Moonlight display name |
| `media_sunshine_port_*` | `infra_port_stream_sunshine_*` | Port family (see below) |
| `media_sunshine_web_username` | `vault_sunshine_web_username` or `''` | Web UI admin user |
| `media_sunshine_web_password` | `vault_sunshine_web_password` or `''` | Web UI admin password |
| `media_sunshine_origin_web_ui_allowed` | `wan` | Web UI origin ACL |
| `media_sunshine_firewall_rules` | TCP+UDP rule list | Windows Firewall rules |

### Ports (infrastructure vars — see `infrastructure/ports.yml` for values)

| Var | Proto | Purpose |
|-----|-------|---------|
| `infra_port_stream_sunshine_https` | TCP | GameStream HTTPS client API |
| `infra_port_stream_sunshine_http` | TCP | GameStream HTTP (base port — all others offset from it) |
| `infra_port_stream_sunshine_webui` | TCP | Web UI HTTPS + `/api/pin` pairing |
| `infra_port_stream_sunshine_rtsp` | TCP+UDP | RTSP stream negotiation |
| `infra_port_stream_sunshine_video` | UDP | Video RTP |
| `infra_port_stream_sunshine_control` | UDP | Control/input |
| `infra_port_stream_sunshine_audio` | UDP | Audio Opus |
| `infra_port_stream_sunshine_mic` | UDP | Microphone (reserved) |

UDP 5353 (mDNS auto-discovery) is LAN-only and intentionally NOT opened —
mDNS does not cross Tailscale; Moonlight clients must "Add Host Manually"
with the Tailscale FQDN (`dtop202311.tale-grouper.ts.net`).

## Secrets (vault handoff)

Web UI credentials come from the client vault:

```yaml
vault_sunshine_web_username: "<user>"
vault_sunshine_web_password: "<generated>"
```

Agent workflow: generate a value, hand the user a `scripts/edit-vault.sh`
command to add the vars to `infrahub-levonk-all.vault.yml`, then re-run the
deploy. When unset, the creds task is skipped and the Web UI first-run wizard
creates the admin account interactively.

## Usage

```bash
ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-sunshine.yml \
  --vault-password-file ~/.ansible/vault_password

# validate afterwards
ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/validate-sunshine.yml \
  --vault-password-file ~/.ansible/vault_password
```

Tags: `sunshine`, `check`, `install`, `configure`, `credentials`, `firewall`,
`service`, `summary`, `validate` (pre-flight asserts).

## License

MIT
