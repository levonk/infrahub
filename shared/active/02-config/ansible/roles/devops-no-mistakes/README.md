# devops-no-mistakes

Deploys [no-mistakes](https://github.com/kunchenguid/no-mistakes) — a local git
gate proxy that intercepts `git push` and runs an AI-driven validation pipeline
(intent → rebase → review → test → document → lint → push → pr → ci) before
forwarding the branch and opening a clean PR.

This role deploys it as a **shared server** on the Windows Docker Desktop host
(dtop202311) so all levonk projects can push through a single gate.

## Architecture

- **Image**: Local registry (`localnet-devops-no-mistakes:latest`) — built by
  story 03-001
- **Target**: Windows Docker Desktop hosts (via SSH-tunneled Docker CLI)
- **Transport**: SSH (git-shell) on port 2222 — does NOT route through Traefik
- **Network**: Joins `traefik-windows-network` for cross-machine visibility
- **Config injection**: Templates rendered on localhost, then `docker cp` into
  the running container, followed by a restart so the entrypoint copies them
  into `NM_HOME`

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `no_mistakes_enabled` | `true` | Enable flag |
| `no_mistakes_container_name` | `localnet-no-mistakes` | Container name |
| `no_mistakes_image_name` | `{{ local_registry }}/localnet-devops-no-mistakes` | Local registry image |
| `no_mistakes_image_tag` | `latest` | Image tag |
| `no_mistakes_ssh_host_port` | `{{ infra_port_devops_no_mistakes_ssh_host }}` | SSH host port (2222) |
| `no_mistakes_ssh_container_port` | `{{ infra_port_devops_no_mistakes_ssh_container }}` | SSH container port (2222) |
| `no_mistakes_domain` | `{{ infra_domain_devops_no_mistakes }}` | Public domain |
| `no_mistakes_data_volume` | `{{ infra_storage_no_mistakes_volume }}` | Data volume (NM_HOME) |
| `no_mistakes_network_name` | `traefik-windows-network` | Docker network |
| `no_mistakes_docker_host` | `ssh://ansible@dtop202311...` | SSH-tunneled Docker host |

## Secrets

Vault variables (added via handoff):

| Variable | Purpose |
|----------|---------|
| `vault_no_mistakes_github_token` | GitHub token for push/PR/clone |
| `vault_no_mistakes_gate_ssh_public_key` | SSH public key for gate user |
| `vault_no_mistakes_devin_api_key` | Devin/Windsurf API key for AI agent |

All secrets are referenced with `| default('')` fallbacks in `defaults/main.yml`.

## Usage

Developers add a remote and push:

```
git remote add no-mistakes ssh://gate@{{ no_mistakes_domain }}:2222/<org>/<repo>.git
git push no-mistakes my-branch
```
