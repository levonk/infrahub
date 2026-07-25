# p2p-freenet

Deploy a [freenet-core](https://github.com/freenet/freenet-core) peer node on a
Windows Docker Desktop host.

## What it does

- Pulls the locally-built `localnet-p2p-freenet` image from the OCI registry
- Creates a dedicated `freenet-network` bridge network (172.39.0.0/16)
- Creates a `localnet-freenet-data-volume` named volume for persistent node data
- Runs the `freenet network` daemon in peer mode, exposing the WebSocket API
  on port 7509

## Target

Windows Docker Desktop hosts (the `windows_docker_hosts` inventory group,
host `dtop202311`). The role uses the SSH-tunneled Docker CLI pattern
(`delegate_to: localhost` + `DOCKER_HOST: ssh://ansible@<host>.<tailnet>`)
because `community.docker` modules break on Windows — see
`roles/security-wazuh/tasks/main.yml` for the reference implementation.

## Access

Tailscale-only. No public domain, no Traefik routing. Reach the WS API at:

```
http://dtop202311.tale-grouper.ts.net:7509
```

## Variables

All variables have sensible defaults in `defaults/main.yml` and reference the
shared `infra_*` infrastructure schemas. No client-specific overrides are
required for the levonk client.

| Variable | Default | Source |
|----------|---------|--------|
| `p2p_freenet_image_name` | `{{ local_registry }}/localnet-p2p-freenet` | role defaults |
| `p2p_freenet_ws_api_host_port` | `7509` | `infra_port_p2p_freenet_ws_api_host` |
| `p2p_freenet_network_name` | `freenet-network` | `infra_network_p2p_freenet_network_name` |
| `p2p_freenet_volume_name` | `localnet-freenet-data-volume` | `infra_storage_freenet_data_volume` |
| `p2p_freenet_docker_host` | `ssh://ansible@dtop202311.tale-grouper.ts.net` | `infra_tailscale_fqdn_windows_docker` |

## Build the image first

The image is not on Docker Hub. Build and push it before deploying:

```bash
PLATFORM=linux/amd64 scripts/build-and-push-images.sh localnet-p2p-freenet
```

## Deploy

```bash
devbox run -- ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-freenet.yml \
  --vault-password-file ~/.ansible/vault_password
```
