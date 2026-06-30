# cloudflare-ddns Ansible Role

Deploys a lightweight Alpine container on each Tailscale-attached host that updates a Cloudflare A record (`{hostname}.mach.{domain}`) with the host's **public IP** every 5 minutes.

## Purpose

This role provides a **non-Tailscale fallback path** for DNS resolution. The infrastructure uses a two-layer DNS architecture:

| Layer | Record type | Target | Purpose |
|-------|------------|--------|---------|
| `*.levonk.com` | CNAME | `*.tale-grouper.ts.net` (Tailscale FQDN) | Primary access via Tailscale |
| `*.mach.levonk.com` | A | Public IP (auto-updated by this role) | Fallback when Tailscale DNS is down |

The CNAME layer handles Tailscale access. This DDNS role handles the fallback layer — it tracks the host's public IP so services remain reachable even when Tailscale MagicDNS is unavailable.

## How It Works

1. An Alpine container is deployed with `curl` installed at startup
2. The container runs a shell script in an infinite loop
3. Every `cloudflare_ddns_update_interval` seconds (default: 300):
   - Detects the public IP via external services (`api.ipify.org`, `ifconfig.me`, `icanhazip.com`)
   - Queries Cloudflare for the existing A record
   - Creates the record if missing, updates it if the IP changed, or skips if unchanged
4. No `network_mode: host` needed — the container makes outbound HTTPS calls only

## Requirements

- Docker on the target host
- Cloudflare API token with DNS edit permissions (from vault)
- The target host must have internet access (to reach the IP detection services and Cloudflare API)

## Role Variables

### Required (per-host)

```yaml
# MUST be set in inventory vars for each host — the Tailscale hostname
cloudflare_ddns_hostname: "oci"  # or "kckinai", etc.
```

### Required (from vault)

```yaml
cloudflare_ddns_api_token: "{{ vault_cloudflare_api_token }}"
cloudflare_ddns_zone_id: "{{ vault_cloudflare_zone_id }}"
```

### Optional

```yaml
cloudflare_ddns_enabled: true
cloudflare_ddns_data_dir: "/opt/cloudflare-ddns"
cloudflare_ddns_container_name: "cloudflare-ddns"
cloudflare_ddns_image: "alpine"
cloudflare_ddns_image_tag: "3.20"
cloudflare_ddns_update_interval: 300  # seconds
cloudflare_ddns_record_ttl: 300
cloudflare_ddns_record_proxied: false
cloudflare_ddns_log_max_size: "1m"
cloudflare_ddns_log_max_file: "3"
```

### Derived

```yaml
# Record name is built from hostname + mach subdomain + base domain
cloudflare_ddns_record_name: "{{ cloudflare_ddns_hostname }}.mach.{{ infra_domain_base | default('levonk.com') }}"
```

## Example Playbook

```yaml
---
- name: Deploy Cloudflare DDNS
  hosts: all
  become: true
  vars_files:
    - "group_vars/infrahub-levonk-all.vault.yml"
  vars:
    cloudflare_ddns_api_token: "{{ vault_cloudflare_api_token }}"
    cloudflare_ddns_zone_id: "{{ vault_cloudflare_zone_id }}"
  roles:
    - cloudflare-ddns
```

## Deploying to a New Host

1. Add `cloudflare_ddns_hostname: "<hostname>"` to the host's inventory vars
2. Run the playbook:

```bash
ansible-playbook \
  -i inventories/oci.yml \
  -i inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/deploy-cloudflare-ddns.yml \
  --vault-password-file ~/.ansible/vault_password
```

3. Verify the record was created:

```bash
dig +short <hostname>.mach.levonk.com A
```

## Clients Using This Feature

- **levonk**: hosts `oci` (`oci.mach.levonk.com`) and `kckinai` (`kckinai.mach.levonk.com`)

## Security Considerations

- The Cloudflare API token is templated into the script file on the target host — the script is owned by root with mode `0755` (readable but not world-writable)
- The container runs with `no-new-privileges:true`
- Only outbound HTTPS is used (no inbound ports published)
- The API token is stored in the Ansible vault and never committed to git in plaintext

## Compliance

This role follows AGENTS.md guidelines:
- Variable-driven configuration (no hardcoded domains or IPs)
- Secure credential management via Ansible vault
- Container managed via `community.docker.docker_container` (not `docker compose`)
- See AGENTS.md → "Cloudflare DDNS (Public IP Redundancy)" for the full feature documentation
