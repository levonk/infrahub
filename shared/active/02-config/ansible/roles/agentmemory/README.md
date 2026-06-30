# agentmemory — Ansible Role

Deploy [agentmemory](https://github.com/rohitg00/agentmemory) — persistent memory for AI coding agents — as a Docker container on the cloud server.

## Architecture

- **iii-engine**: WebSocket daemon running the iii-sdk workers (state, queue, pubsub, cron, stream, observability)
- **agentmemory CLI**: HTTP API + MCP server on port 3111 (53 MCP tools, 126 REST endpoints)
- **Storage**: File-based SQLite via iii-engine StateModule at `/data/state_store.db`
- **Auth**: HMAC bearer token (`AGENTMEMORY_SECRET`)

## Exposure

| Interface | Access Method |
|-----------|---------------|
| Web viewer | Traefik + Authelia SSO at `https://agentmemory.levonk.com` |
| MCP API | Tailscale-only direct access at `http://<tailscale-ip>:3111` |

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `agentmemory_enabled` | `true` | Enable the service |
| `agentmemory_version` | `0.9.25` | agentmemory npm package version |
| `agentmemory_iii_version` | `0.11.2` | iii-engine version (pinned) |
| `agentmemory_iii_sdk_version` | `0.11.2` | iii-sdk version (must match engine) |
| `agentmemory_container_port` | `3111` | Container HTTP API port |
| `agentmemory_host_port` | `3111` | Host port (published for Tailscale MCP) |
| `agentmemory_container_ip` | `172.31.0.7` | Container IP on traefik-network |
| `agentmemory_domain` | `agentmemory.levonk.com` | Traefik domain for web UI |
| `agentmemory_secret` | (from vault) | HMAC secret for API auth |
| `agentmemory_anthropic_api_key` | (from vault) | Anthropic API key for LLM compression |
| `agentmemory_openai_api_key` | (from vault) | OpenAI API key for embeddings |

## Vault Variables

The following vault variables must be defined in `infrahub-levonk-all.vault.yml`:

- `vault_agentmemory_hmac_secret` — HMAC secret for API authentication (optional; auto-generated if not set)
- `vault_anthropic_api_key` — Anthropic API key (optional; enables LLM compression)
- `vault_openai_api_key` — OpenAI API key (optional; enables hybrid vector search)

## Dependencies

- `common` role (base system configuration)
- Docker engine must be installed and running
- Traefik + Authelia must be deployed for web UI access
- Tailscale must be configured for MCP direct access

## Example Playbook

```yaml
- hosts: cloud_servers
  become: true
  roles:
    - role: agentmemory
      tags: ["ai", "agentmemory", "mcp"]
```
