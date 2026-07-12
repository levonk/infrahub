# common-hosts-blocklist

Sinkholes IP-logger, IP-tracker, and IP-grabber domains via the hosts file.

## Why

These services generate tracking links that covertly log the visitor's IP
address, browser fingerprint, and geolocation without consent. They are
privacy-violating traps. Blocking them at the hosts-file level (`0.0.0.0`
sinkhole) prevents any application on the machine from ever resolving them.

## How it works

The role writes a marked block into the hosts file (`/etc/hosts` on Linux/macOS,
`C:\Windows\System32\drivers\etc\hosts` on Windows) that maps every blocklisted
domain to `0.0.0.0`. The block is delimited by `BEGIN`/`END` markers so re-runs
are idempotent — the old block is replaced with the current list, no duplicates.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hosts_blocklist_sinkhole` | `0.0.0.0` | Address to point domains at (null-routed on every platform) |
| `hosts_blocklist_domains` | (see defaults) | List of domains to sinkhole — override to extend |
| `hosts_blocklist_marker_begin` | `# >>> BEGIN LEVONK HOSTS BLOCKLIST ...` | Block start marker |
| `hosts_blocklist_marker_end` | `# >>> END LEVONK HOSTS BLOCKLIST <<<` | Block end marker |

## Deployment

The role is included in the hardening playbooks:
- `harden-windows-host.yml` — Windows hosts
- `cloud-server-bootstrap.yml` — OCI cloud server + isolation VMs (Linux)
- `bootstrap-macos-host.yml` — macOS hosts
- `localnet-tailscale.yml` — localnet hosts (Linux)

Deploy the blocklist to all machines:

```bash
just ansible-deploy-hosts-blocklist
```
