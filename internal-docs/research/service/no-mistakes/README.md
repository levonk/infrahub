# Research: no-mistakes (Shared Git Gate Service)

## Service Overview

**Upstream**: https://github.com/kunchenguid/no-mistakes
**Docs**: https://kunchenguid.github.io/no-mistakes/
**Language**: Go
**License**: (check repo)
**Stars**: ~7.8k

`no-mistakes` is a local git gate proxy. It intercepts `git push` by placing a
local bare git repo (the "gate") between the working repo and the real remote.
Pushes to the gate trigger an AI-driven validation pipeline
(`intent → rebase → review → test → document → lint → push → pr → ci`).
Only after every check passes does it forward the branch to the configured push
target and open a clean PR.

## Architecture (Native / Local)

```
working repo → git push no-mistakes → local bare gate repo
                                         ↓
                                    daemon (Unix socket)
                                         ↓
                                    disposable worktree
                                         ↓
                                    pipeline (AI agent subprocess)
                                         ↓
                                    push to origin + open PR
```

**Key components:**
- **Gate repo**: Local bare git repo at `~/.no-mistakes/repos/<id>.git` with
  managed pre-receive (admission) and post-receive (notification) hooks
- **Daemon**: Long-running process at `~/.no-mistakes/socket` (JSON-RPC over
  Unix socket). Manages pipeline runs, worktrees, state (SQLite at
  `~/.no-mistakes/state.sqlite`)
- **Pipeline executor**: Runs steps sequentially, manages auto-fix loop
- **AI agent**: Subprocess (claude, codex, grok, etc., or `acp:<target>` via
  `acpx` binary)

**`NM_HOME`**: Relocates all state (config, gates, worktrees, socket, SQLite).
Critical for containerization — set to a mounted volume path.

## Deployment Model: Shared Server (This Project)

no-mistakes is designed as a **per-developer local tool**. This project deploys
it as a **shared server** on the Windows Docker Desktop host (dtop202311) so
all levonk projects can push through a single gate.

### Design Decisions (User-Confirmed)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Git transport | **SSH (git-shell)** | Most git-native, supports push options |
| Multi-project | **Auto-provision on first push** | Frictionless — developers just add remote and push |
| AI agent | **Deferred (likely devin-cli via ACP)** | `devin acp` provides ACP server over stdio; no-mistakes uses `acp:devin` via `acpx` |

### Container Architecture

```
┌─────────────────────────────────────────────────────┐
│  Container (Linux, WSL2 on Windows Docker Desktop)  │
│                                                     │
│  sshd (port 2222)                                   │
│    └─ git-shell wrapper                             │
│         └─ auto-provision gate on first push        │
│         └─ forward to ~/.no-mistakes/repos/<id>.git │
│                                                     │
│  no-mistakes daemon (Unix socket)                   │
│    └─ pipeline executor                             │
│         └─ AI agent (acp:devin via acpx + devin acp)│
│         └─ git push to GitHub (GITHUB_TOKEN)        │
│         └─ gh CLI for PR creation                   │
│                                                     │
│  Volumes:                                           │
│    $NM_HOME → persistent volume (gates, state)      │
│    /etc/ssh → persistent volume (host keys)         │
└─────────────────────────────────────────────────────┘
         │ SSH (port 2222)
         ▼
   no-mistakes.nl.levonk.com (DNS CNAME → dtop202311 TS FQDN)
```

### Auto-Provision Flow

1. Developer adds remote:
   `git remote add no-mistakes ssh://gate@no-mistakes.nl.levonk.com:2222/levonk/infrahub.git`
2. Developer pushes: `git push no-mistakes my-branch`
3. SSH arrives at container sshd → git-shell wrapper
4. Wrapper parses repo path (`levonk/infrahub`)
5. Computes gate ID (SHA-256 of absolute path, first 12 hex chars)
6. If gate doesn't exist at `$NM_HOME/repos/<id>.git`:
   a. Clone upstream: `git clone https://github.com/levonk/infrahub /tmp/provision`
   b. Run `no-mistakes init` in clone (creates gate, registers with daemon)
   c. Remove clone (gate persists in `$NM_HOME`)
7. Forward `git-receive-pack` to gate repo
8. Gate hooks fire → daemon runs pipeline → push to GitHub + open PR

### SSH Authentication

- Dedicated `gate` user in container
- SSH key pair generated during deployment:
  - **Public key**: Stored in container config (non-secret, can be in shared/)
  - **Private key**: Stored in vault (`vault_no_mistakes_gate_ssh_private_key`),
    distributed to authorized developers
- Developers configure `~/.ssh/config`:
  ```
  Host no-mistakes.nl.levonk.com
    User gate
    Port 2222
    IdentityFile ~/.ssh/no-mistakes-gate
  ```

### AI Agent: devin-cli via ACP

no-mistakes supports `acp:<target>` agents via the `acpx` binary. Devin CLI
provides `devin acp` — an ACP server over stdio.

**Configuration** (`$NM_HOME/config.yaml`):
```yaml
agent: acp:devin
acpx_path: /usr/local/bin/acpx
acp_registry_overrides:
  devin: devin acp
```

**Credentials**: `WINDSURF_API_KEY` env var or `devin auth login` credentials,
passed to the container via vault secrets.

## Pipeline Steps

Fixed order (not configurable): `intent → rebase → review → test → document →
lint → push → pr → ci`

Each step can be configured per-repo via `.no-mistakes.yaml`:
- `commands.test`, `commands.lint`, `commands.format` — shell commands
- `agent` — override agent per-repo
- `auto_fix` — auto-fix attempt limits per step
- `no_ci` — declare repo has no CI

**Security**: `commands.*` and `agent` are read from the **default branch**
(not pushed SHA) to prevent supply-chain attacks.

## Container Image Build

**Decision**: Locally-built image (no upstream container exists).

- **Base**: Alpine or Debian slim (Linux x86_64 — dtop202311 is X86)
- **Build method**: Multi-stage Dockerfile
  - Stage 1: Go build no-mistakes from source (or download release binary)
  - Stage 2: Runtime with sshd, git, no-mistakes, devin-cli, acpx, gh CLI
- **Multi-arch**: x86_64 only (dtop202311 is X86 Windows). Note: no-mistakes
  itself supports arm64, but the target host is X86.
- **Registry**: Push to local registry (100.90.22.85:5000)

## Ports

| Variable | Value | Purpose |
|----------|-------|---------|
| `infra_port_devops_no_mistakes_ssh_host` | 2222 | SSH git endpoint (host) |
| `infra_port_devops_no_mistakes_ssh_container` | 2222 | SSH git endpoint (container) |

Port 2222 is free — no conflicts in shared or client port files.

## Domain

| Variable | Value |
|----------|-------|
| `infra_domain_devops_no_mistakes` | `no-mistakes.nl.levonk.com` |

DNS: CNAME → `dtop202311.tale-grouper.ts.net` (Tailscale FQDN)

**Note**: This domain is for DNS resolution only. SSH traffic does NOT go
through Traefik (Traefik is HTTP/HTTPS only). The domain resolves to the
Windows host's Tailscale IP, and SSH connects on port 2222 directly.

## Secrets (Vault)

| Variable | Purpose |
|----------|---------|
| `vault_no_mistakes_github_token` | GitHub token for push/PR/clone operations |
| `vault_no_mistakes_gate_ssh_private_key` | SSH private key for gate user auth |
| `vault_no_mistakes_devin_api_key` | Devin/Windsurf API key for AI agent |

## Network

The container joins `traefik-network` for potential future web UI access and
cross-machine visibility, even though SSH doesn't route through Traefik.

## References

- [Gate Model](https://kunchenguid.github.io/no-mistakes/concepts/gate-model/)
- [Global Config](https://kunchenguid.github.io/no-mistakes/reference/global-config/)
- [Repo Config](https://kunchenguid.github.io/no-mistakes/reference/repo-config/)
- [Environment Variables](https://kunchenguid.github.io/no-mistakes/reference/environment/)
- [CLI Commands](https://kunchenguid.github.io/no-mistakes/reference/cli/)
- [Installation](https://kunchenguid.github.io/no-mistakes/start-here/installation/)
- [Devin ACP](https://agentclientprotocol.com/) — `devin acp` subcommand
