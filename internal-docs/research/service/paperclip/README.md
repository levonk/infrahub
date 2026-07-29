# Paperclip — Research

## Service

- **Name**: Paperclip
- **Upstream**: https://github.com/paperclipai/paperclip
- **Docs**: https://docs.paperclip.ing
- **License**: MIT
- **Language**: Node.js 20+ / TypeScript / pnpm 9.15+
- **Category**: AI agent orchestration (ai-codeassist)

## What It Is

Open-source orchestration platform for teams of AI agents. Node.js server +
React UI that orchestrates a team of AI agents to run a business. Bring your
own agents, assign goals, track work and costs from one dashboard.

"If OpenClaw is an _employee_, Paperclip is the _company_."

Four pillars: Agentic Task Manager, Org Chart for Agents, Agent Employee
Training, Agentic OS.

## Architecture

- **Server**: Node.js API at port 3100 + embedded React UI
- **Database**: Embedded PostgreSQL (dev) or external Postgres (prod)
- **Agents**: Bring-your-own via adapter system — adapters call out to local
  CLIs or remote API servers
- **Heartbeats**: Agents wake on schedule, check work, act, report back

## Existing Infrahub State

- **Stub directory exists**: `shared/active/03-container/services/ai-codeassist/paperclip/`
  - `Dockerfile` — multi-stage Node 20 build (builder + runtime)
  - `docker-compose.yml` — reference topology (paperclip + postgres)
  - `.env.example`, `.envrc`, `README.md`
  - **No Ansible role exists yet** — this is what needs to be built
- **Port**: 3100 (default, not yet allocated in infra ports.yml)
- **No domain allocated** yet (candidate: `paperclip.levonk.com`)

## Built-in Adapters (from `packages/adapters/`)

Paperclip ships with these adapter types:

| Adapter | Type Key | Mode |
|---------|----------|------|
| claude-local | `claude_local` | Local CLI subprocess |
| codex-local | `codex_local` | Local CLI subprocess |
| cursor-cloud | `cursor_cloud` | Cloud API |
| cursor-local | `cursor_local` | Local CLI subprocess |
| gemini-local | `gemini_local` | Local CLI subprocess |
| grok-local | `grok_local` | Local CLI subprocess |
| **hermes** | `hermes_local` | Local CLI subprocess (`hermes chat`) |
| **hermes-gateway** | `hermes_gateway` | Remote HTTP/SSE API server |
| openclaw-gateway | `openclaw_gateway` | Remote HTTP API |
| opencode-local | `opencode_local` | Local CLI subprocess |
| **pi-local** | `pi_local` | Local CLI subprocess |

**No `omnigent` adapter exists.**

## Integration Feasibility Analysis

User preferences (first one that's possible):
1. paperclip -> hermes
2. paperclip -> omnigent
3. paperclip -> pi

### 1. paperclip -> hermes

**Paperclip adapter**: `hermes_local` (CLI subprocess) or `hermes_gateway`
(remote API server).

**What paperclip expects**: Nous Research's Hermes Agent
(https://github.com/NousResearch/hermes-agent) — a Python CLI with 30+ tools,
persistent memory, 80+ skills, MCP support, multi-provider model access.
Install via `pip install hermes-agent`.

**What infrahub has**: `shared/active/03-container/services/base/hermes-agent/`
— a custom sandbox container (SSH + Docker CLI + Tailscale + Netbird + tmux +
zsh). This is a **runner/sandbox**, NOT the Nous Research Hermes Agent CLI.
Deployed to isolation-vm, not OCI cloud server.

**Verdict**: ❌ **NOT directly possible**. The infrahub hermes-agent is a
different thing. Would need to install Nous Research's hermes-agent separately
(either in the paperclip container or as a sidecar API server).

### 2. paperclip -> omnigent

**Paperclip adapter**: None. No omnigent adapter exists in paperclip's
`packages/adapters/`.

**What infrahub has**: Omnigent deployed on OCI at `aiif.levonk.com`
(server + Postgres). Pi in RPC mode as the runner.

**Verdict**: ❌ **NOT possible**. Would require custom adapter development.

### 3. paperclip -> pi

**Paperclip adapter**: `pi_local` — runs pi as a local CLI subprocess.

**What infrahub has**: Pi deployed on OCI in RPC mode (via
`deploy-omnigent.yml` playbook) at port 8090. Pi is the coding agent harness
from https://github.com/earendil-works/pi.

**Verdict**: ✅ **POSSIBLE**. The `pi_local` adapter exists. Pi is already
on OCI. Paperclip can run pi as a subprocess inside its container, or
potentially connect to the existing pi RPC instance.

**Caveat**: `pi_local` runs pi as a subprocess (not RPC). The existing pi
container on OCI runs in RPC mode for omnigent. Paperclip would either:
- (a) Run its own pi subprocess inside the paperclip container, OR
- (b) Need a `pi_gateway` adapter (does not exist) to connect to the
  already-running pi RPC instance.

Option (a) is the path of least resistance — paperclip runs pi locally.

## Deployment Plan (Draft)

1. **Image**: Locally-built (existing Dockerfile in stub dir). Multi-stage
   Node 20 build. Register in `build-and-push-images.sh`.
2. **Port**: 3100 (host + container) — check for conflicts
3. **Domain**: `paperclip.levonk.com` (Traefik + Authelia)
4. **Database**: External PostgreSQL container (not embedded)
5. **Network**: Join `traefik-network` for routing
6. **Secrets**: `vault_paperclip_postgres_password`,
   `vault_paperclip_api_key` (for agent auth)
7. **Ansible role**: `ai-paperclip` (following `ai-litellm` pattern)
8. **Playbook**: Add to `deploy-omnigent.yml` or create
   `deploy-paperclip.yml`
9. **Agent backend**: `pi_local` adapter (pi subprocess inside paperclip
   container)
10. **Pipeline position**: Request origin (alongside Omnigent) — paperclip
    orchestrates agents that originate pipeline requests

## References

- Paperclip GitHub: https://github.com/paperclipai/paperclip
- Paperclip docs: https://docs.paperclip.ing
- Paperclip developing: https://github.com/paperclipai/paperclip/blob/master/doc/DEVELOPING.md
- Hermes adapter: https://github.com/paperclipai/paperclip/tree/master/packages/adapters/hermes
- Pi-local adapter: https://github.com/paperclipai/paperclip/tree/master/packages/adapters/pi-local
- Docker quickstart: `docker/docker-compose.quickstart.yml` in paperclip repo
