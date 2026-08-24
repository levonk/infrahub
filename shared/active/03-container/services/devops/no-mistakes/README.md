# no-mistakes Shared Git Gate

A shared [no-mistakes](https://github.com/kunchenguid/no-mistakes) git gate
service deployed as a container on the Windows Docker Desktop host
(dtop202311). All levonk projects push through a single gate that runs an
AI-driven validation pipeline before forwarding to GitHub.

## How It Works

```
developer → git push no-mistakes → sshd (port 2222)
                                      → git-shell wrapper
                                         → auto-provision gate (first push)
                                         → forward to ~/.no-mistakes/repos/<id>.git
                                            → no-mistakes daemon
                                               → pipeline (intent → rebase → review →
                                                  test → document → lint → push → pr → ci)
                                               → push to GitHub + open PR
```

### Auto-Provision

When a developer pushes to a repo that doesn't have a gate yet, the
`git-shell-commands/no-mistakes-gate` wrapper:

1. Parses the repo path from the git-receive-pack command
2. Computes a gate ID (first 12 hex chars of SHA-256 of the absolute path)
3. Clones the upstream repo using `GITHUB_TOKEN`
4. Runs `no-mistakes init` to create the gate repo in `$NM_HOME`
5. Forwards the push to the gate repo

Subsequent pushes skip provisioning and go directly to the existing gate.

## Container Image

**Locally built** — no upstream container exists. Multi-stage Dockerfile:

- **Stage 1** (`golang:1.23-alpine`): builds `no-mistakes` from source via
  `go install`
- **Stage 2** (`alpine:3.20`): runtime with sshd, git, git-shell, gh CLI,
  devin-cli, acpx, and the auto-provision wrapper

### Build

```bash
# Build and push to the local registry (linux/amd64 only)
PLATFORMS=linux/amd64 devbox run -- scripts/build-and-push-images.sh localnet-devops-no-mistakes
```

### Files

| File | Purpose |
|------|---------|
| `docker/Dockerfile.no-mistakes` | Multi-stage build definition |
| `docker/entrypoint.sh` | Container entrypoint (sshd + no-mistakes daemon) |
| `docker/git-shell-commands/no-mistakes-gate` | Auto-provision git-shell wrapper |
| `docker/config.yaml.j2` | no-mistakes global config (Jinja2 template, rendered by Ansible) |
| `docker-compose.no-mistakes.yml` | Reference compose (NOT used for deployment) |

## Configuration

The `config.yaml.j2` template is rendered by Ansible at deploy time and
mounted into the container. It configures:

- `agent: acp:devin` — use Devin CLI via the Agent Client Protocol
- `acpx_path: /usr/local/bin/acpx` — path to the acpx binary
- `acp_registry_overrides` — maps `devin` to `devin acp` (the ACP server subcommand)
- `auto_fix` — retry limits per pipeline step

## Secrets (Vault)

| Variable | Purpose |
|----------|---------|
| `vault_no_mistakes_github_token` | GitHub token for clone/push/PR |
| `vault_no_mistakes_gate_ssh_private_key` | SSH key for gate user auth |
| `vault_no_mistakes_devin_api_key` | Devin/Windsurf API key for AI agent |

## SSH Access

Developers configure `~/.ssh/config`:

```
Host no-mistakes.nl.levonk.com
  User gate
  Port 2222
  IdentityFile ~/.ssh/no-mistakes-gate
```

Then add the remote and push:

```bash
git remote add no-mistakes ssh://gate@no-mistakes.nl.levonk.com:2222/levonk/infrahub.git
git push no-mistakes my-branch
```

## Ports

| Port | Purpose |
|------|---------|
| 2222 | SSH git endpoint (container + host) |

## Network

The container joins `traefik-network` for cross-machine visibility, though
SSH traffic does not route through Traefik (HTTP/HTTPS only). The domain
`no-mistakes.nl.levonk.com` resolves via DNS CNAME to the host's Tailscale
FQDN, and SSH connects directly on port 2222.
