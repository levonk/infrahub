# agentmemory — Shared Container Service

Persistent memory system for AI coding agents, built on iii-engine.

Upstream: https://github.com/rohitg00/agentmemory

## Architecture

- **iii-engine**: WebSocket daemon (port 49134, internal) running the iii-sdk workers
- **agentmemory CLI**: HTTP API + MCP server (port 3111) + stream (port 3112, internal)
- **Storage**: File-based SQLite via iii-engine StateModule at `/data/state_store.db`
- **Auth**: HMAC bearer token (`AGENTMEMORY_SECRET`)

## Ports

| Port  | Purpose              | Exposure                          |
|-------|----------------------|-----------------------------------|
| 3111  | HTTP API + web viewer | Published to host (Tailscale MCP); Traefik proxy (web UI with Authelia) |
| 3112  | iii-stream           | Internal (container-only)         |
| 49134 | iii-engine WebSocket | Internal (container-only)         |
| 9464  | Observability metrics| Internal (container-only)         |

## Deployment

This service is deployed via the `agentmemory` Ansible role to the levonk cloud server.
See `shared/active/02-config/ansible/roles/agentmemory/` for deployment configuration.

### Manual build (for testing)

```bash
cd shared/active/03-container/services/agentmemory
docker compose -f docker-compose.agentmemory.yml build
docker compose -f docker-compose.agentmemory.yml up -d
```

## Configuration

- **HMAC secret**: Set via `AGENTMEMORY_SECRET` env var (from Ansible vault), or auto-generated on first boot and persisted to `/data/.hmac`
- **LLM keys**: `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` (optional, enables LLM compression + hybrid vector search)
- **iii-config**: Mounted at `/app/config.yaml` (read-only), copied by entrypoint to overwrite npm-bundled config

## Version Pinning

- agentmemory: 0.9.25
- iii-engine: 0.11.2 (pinned — v0.11.6+ requires sandbox-everything worker model not yet supported by agentmemory CLI)
- iii-sdk: 0.11.2 (must match iii-engine version)
