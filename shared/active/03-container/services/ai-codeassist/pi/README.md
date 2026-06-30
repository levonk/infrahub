# Pi - Minimal Terminal Coding Harness

Pi is a minimal terminal coding harness — the agent that actually does the coding work (read, write, edit, bash tools). It is the harness that Omnigent's runner drives to execute AI coding loops.

- **Project**: https://github.com/earendil-works/pi
- **npm**: `@earendil-works/pi-coding-agent`
- **RPC docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **License**: MIT

## Architecture

Pi runs in four modes: interactive (TUI), print/JSON, **RPC** (process integration), and SDK (embedding). This container runs pi in **RPC mode**, exposed via a small HTTP-to-stdin bridge so Omnigent's runner can dispatch work to it over the network.

```
Omnigent (server)
    │
    ▼ runner spawns / dispatches
┌──────────────────────────────────────────────────┐
│  Pi container (RPC mode)                         │
│                                                  │
│  rpc-bridge.py (:8090)                           │
│    └─ spawns `pi --mode rpc` per session         │
│       └─ JSONL over stdin/stdout                 │
│                                                  │
│  LLM requests → AI Dashboard Proxy 1 (:8081)     │
│    (via custom "pipeline" provider in models.json)│
└──────────────────────────────────────────────────┘
    │
    ▼ LLM requests enter the analytics pipeline
AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → ...
```

### Why Containerized Pi?

Omnigent's runner normally spawns `pi --mode rpc` as a **local subprocess** on the runner host (laptop or cloud sandbox). That's the simplest integration — no container needed. This containerized pi exists for **cloud sandbox hosts** (Modal, Daytona) where the runner is remote and needs to reach pi over the network. The `rpc-bridge.py` script exposes the RPC protocol over HTTP so a remote runner can dispatch work to a containerized pi instance.

For local-runner deploys (laptop), you typically don't need this container — just install pi on the runner host and let Omnigent's runner spawn it directly. See the [Omnigent runner docs](https://omnigent.ai/docs/deploy/overview#runner).

## Pipeline Position

Pi is the **harness layer** — it sits between Omnigent (the orchestrator) and the analytics pipeline (the observer/optimizer). Pi's LLM requests flow through the pipeline:

```
Omnigent → Pi (harness) → AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
(server)   (RPC mode)        (Entry)              (PII Detection)    (Compression)   (Routing)       (Tool Calling)        (Pre-Egress)    (Security)    (Privacy)
```

Pi is configured with a custom "pipeline" provider (see `models.json`) that points its LLM requests at `http://ai-dashboard-proxy-1:8081/v1` — the pipeline entry point. This ensures all pi LLM traffic flows through the analytics pipeline for collection, PII detection, compression, routing, and security enforcement.

See `shared/active/03-container/services/ai-dashboard/PIPELINE.md` for the full pipeline architecture.

## Configuration

### Environment Variables

All secrets (`PI_API_KEY`) MUST be sourced from the client Ansible vault at deploy time — NEVER commit real values to `shared/`.

See `.env.example` for the full variable reference. Key variables:

| Variable | Purpose | Default |
| --- | --- | --- |
| `PI_API_KEY` | API key passed through to the pipeline (required) | — (vault) |
| `PI_RPC_PORT` | RPC HTTP bridge port | `8090` |
| `PI_PROVIDER` | LLM provider name | `openai` |
| `PI_MODEL` | Default model ID | `claude-sonnet-4-20250514` |
| `PI_API_BASE_URL` | LLM endpoint (pipeline entry) | `http://ai-dashboard-proxy-1:8081/v1` |
| `PI_SESSION_DIR` | Session JSONL storage | `/data/sessions` |
| `PI_WORKSPACE_DIR` | Code repo mount point | `/workspace` |

### Custom Provider (models.json)

Pi reads custom providers from `~/.pi/agent/models.json`. This container ships with a `pipeline` provider that routes LLM requests to the analytics pipeline entry (AI Dashboard Proxy 1). The pipeline speaks OpenAI-compatible API, so pi treats it as an OpenAI provider with a custom base URL.

The `PI_API_KEY` is passed through to the pipeline as the upstream auth token. The pipeline itself handles real provider auth via Iron-Proxy secret injection at the egress boundary.

### RPC Bridge

The `rpc-bridge.py` script exposes pi's RPC protocol over HTTP:

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/health` | GET | Liveness probe |
| `/session/start` | POST | Start a new pi RPC subprocess, return session id |
| `/session/:id/prompt` | POST | Send a prompt to a session, stream events |
| `/session/:id/abort` | POST | Abort the current operation in a session |
| `/session/:id` | DELETE | Stop a session subprocess |
| `/rpc` | POST | Single-shot RPC command (advanced) |

`ponytail:` single-process, in-memory session map. Ceiling: one bridge instance can't be horizontally scaled (sessions are local subprocess state). Upgrade path: move session state to a shared store (Redis) and run multiple bridge replicas behind a load balancer with sticky sessions.

## Usage

### Deployment

Deployment is handled by the Ansible playbook `deploy-omnigent.yml` — pi starts alongside Omnigent under the `omnigent` profile. Never run `docker compose up` directly for deployment.

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --vault-password-file ~/.ansible/vault_password
```

The playbook copies the pi compose/Dockerfile/bridge/models.json to the target server, builds the `localnet-pi` image, generates the env file from vault secrets + infrastructure vars, creates networks, and starts the containers.

### Health Check

```bash
curl http://localhost:8090/health
```

### Start a Coding Session

```bash
# Start a session
curl -X POST http://localhost:8090/session/start
# → {"session_id": "abc-123"}

# Send a prompt (streams JSONL events)
curl -X POST http://localhost:8090/session/abc-123/prompt \
  -H "Content-Type: application/json" \
  -d '{"message": "Read the README and summarize it"}'
```

In practice, Omnigent's runner handles this automatically — you interact with Omnigent's web/terminal/mobile UI, and the runner dispatches work to pi via the RPC bridge.

### View Logs

```bash
docker logs pi --tail=50 -f
```

## Client Deployment (levonk)

- **Secrets**: `PI_API_KEY` sourced from `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`
- **Workspace mount**: client-specific (mount the repos pi should operate on)
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2` (covers both Omnigent and Pi vars)
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Deployment doc**: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md` (covers the full Omnigent + Pi stack)

## Network Configuration

Pi joins three networks to bridge Omnigent and the analytics pipeline:
- **omnigent-network** (172.36.0.0/16) — communication with the Omnigent server
- **ai-dashboard-network** (172.35.0.0/16) — LLM requests to AI Dashboard Proxy 1
- **proxy-chain-network** (172.29.0.0/16) — access to downstream pipeline services

## Security Considerations

1. **API key from vault** — `PI_API_KEY` is sourced from the client Ansible vault, never in plaintext.
2. **Pipeline-routed LLM** — all LLM traffic flows through the analytics pipeline (PII detection, egress firewall, VPN), never directly to providers.
3. **Non-root execution** — pi runs as UID 1000, not root.
4. **Workspace isolation** — pi only operates on files within `/workspace` (mounted by the client overlay).
5. **Session persistence** — sessions stored in a named volume (`localnet-pi-sessions-volume`), surviving container restarts.

## References

- **Pi project**: https://github.com/earendil-works/pi
- **Pi coding agent (npm)**: https://www.npmjs.com/package/@earendil-works/pi-coding-agent
- **RPC mode docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **SDK docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sdk.md
- **Omnigent (orchestrator)**: `shared/active/03-container/services/ai-codeassist/omnigent/`
- **Pipeline architecture**: `shared/active/03-container/services/ai-dashboard/PIPELINE.md`
