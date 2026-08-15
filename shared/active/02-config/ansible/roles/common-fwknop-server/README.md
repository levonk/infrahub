# common-fwknop-server

Ansible role that installs and configures **fwknop-server** (Single Packet
Authorization) to hide SSH port 22 from port scanners.

## What it does

1. Installs `fwknop-server` via apt
2. Deploys `/etc/fwknop/fwknopd.conf` and `/etc/fwknop/access.conf` (0600, no_log)
3. Opens the SPA UDP port (default 62201) through UFW
4. Allows SSH on the Tailscale interface (`tailscale0`) as a parallel no-knock path
5. Optionally removes the public SSH UFW rule (closes port 22 to the internet)
6. Enables and starts the `fwknop-server` systemd service

## Safety gates

- **`fwknop_close_public_ssh: false`** (default) — port 22 stays open until the
  operator explicitly sets this to `true` after testing SPA access
- **`fwknop_enabled: true`** (default) — the role runs; set to false to skip
- **Tailscale stays open** — `tailscale0` interface always allows SSH regardless
  of the public rule, providing a fallback if SPA is misconfigured

## Required vault variables

```yaml
vault_fwknop_spa_key: "<KEY_BASE64 from fwknop --key-gen>"
vault_fwknop_hmac_key: "<HMAC_KEY_BASE64 from fwknop --key-gen>"
```

Generate keys with `fwknop --key-gen` on any machine with the fwknop client
installed (`brew install fwknop` on macOS, `apt install fwknop-client` on Linux).

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `fwknop_enabled` | `true` | Master switch for the role |
| `fwknop_close_public_ssh` | `false` | Remove public SSH UFW rule (close port 22) |
| `fwknop_spa_port` | `62201` | UDP port for SPA packets |
| `fwknop_ssh_port` | `22` | SSH port to protect |
| `fwknop_access_timeout` | `120` | Seconds port stays open after valid SPA |
| `fwknop_spa_key` | vault | Encryption key (KEY_BASE64) |
| `fwknop_hmac_key` | vault | HMAC key (HMAC_KEY_BASE64) |
| `fwknop_tailscale_interface` | `tailscale0` | Tailscale interface name |
| `fwknop_allow_tailscale_ssh` | `true` | Allow SSH on Tailscale without SPA |

## Deployment

```bash
# Deploy fwknop-server (port 22 stays open)
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-fwknop.yml \
  --vault-password-file ~/.ansible/vault_password

# After testing SPA, close port 22 publicly
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-fwknop.yml \
  --vault-password-file ~/.ansible/vault_password \
  -e fwknop_close_public_ssh=true
```

## Client-side setup

Install the fwknop client and configure `~/.fwknoprc`:

```ini
[default]
SPA_SERVER_PROTO     udp
HMAC_DIGEST_TYPE     SHA512
USE_HMAC             Y
ALLOW_IP             resolve
ACCESS               tcp/22
KEY_BASE64           <your-key>
HMAC_KEY_BASE64      <your-hmac-key>

[oci-cloud-server]
SPA_SERVER           <server-public-ip>
SPA_SERVER_PORT      62201
```

Then knock before SSH:

```bash
fwknop -n oci-cloud-server
ssh opc@<server-public-ip>
```

Or use ProxyCommand for transparent knocking (see `~/.ssh/config`).

## See also

- `internal-docs/research/service/fwknop/research.md` — architecture and alternatives analysis
- https://www.michelebologna.net/2026/ssh-port-22-fwknop-single-packet-authorization/ — reference article
- https://www.cipherdyne.org/fwknop/ — upstream documentation
