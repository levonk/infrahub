# common-fwknop-client

Installs the fwknop SPA (Single Packet Authorization) client and deploys configuration to all machines.

## What this role does

1. Installs the fwknop client package (`fwknop-client` on Debian/Ubuntu, `fwknop` on EL)
2. Deploys `~/.fwknoprc` with vault-backed SPA/HMAC keys
3. Deploys `~/.ssh/config.d/infrahub` with SPA-aware SSH config
4. Ensures `~/.ssh/config` includes `~/.ssh/config.d/*`

## SSH access paths

| Alias | Path | Knock needed? |
|-------|------|---------------|
| `ssh oci` | Tailscale | No — always works |
| `ssh ocispa` | Public IP + auto-knock | Yes (automatic via ProxyCommand) |

## Requirements

- Ansible vault must contain `vault_fwknop_spa_key` and `vault_fwknop_hmac_key`
- The `common-fwknop-server` role must be deployed on the OCI cloud server
- Tailscale must be running on the target machine (for the no-knock path)

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `fwknop_client_enabled` | `true` | Whether to install and configure |
| `fwknop_client_spa_server` | `oci.mach.levonk.com` | SPA server public hostname |
| `fwknop_client_spa_port` | `62271` | SPA UDP port |
| `fwknop_client_ssh_key` | `~/.ssh/lzkmbp2016-micro-oracle` | SSH key for OCI server |
| `fwknop_client_tailscale_ip` | `100.90.22.85` | OCI Tailscale IP |
| `fwknop_client_deploy_ssh_config` | `true` | Whether to deploy SSH config.d file |
