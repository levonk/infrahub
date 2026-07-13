# tools-croc-relay

Deploys a self-hosted [Croc](https://github.com/schollz/croc) relay on Windows
Docker Desktop hosts.

## Variables

See `defaults/main.yml` for the full list. The most important ones are:

- `croc_relay_enabled` — enable/disable the relay (default: `true`)
- `croc_relay_password` — relay password (required, must be in vault)
- `croc_relay_start_port` / `croc_relay_end_port` — published TCP port range
- `croc_relay_docker_host` — SSH-tunneled Docker host URL for Windows targets

## Usage

```yaml
- hosts: windows_docker_hosts
  become: false
  roles:
    - role: tools-croc-relay
      tags: ["deploy", "croc-relay"]
```

## Client usage

```bash
croc --pass <relay-password> --relay "croc.levonk.com:9009" send <file>
```

`croc.levonk.com` is a CNAME to the Windows Docker host's Tailscale FQDN
(`dtop202311.tale-grouper.ts.net`).
