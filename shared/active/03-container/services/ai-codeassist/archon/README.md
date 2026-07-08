# Archon — Workflow Layer

Archon is the **workflow layer** of the AI pipeline's request origin stack. It provides YAML DAG workflows with loops, `fresh_context` (fresh agent session per iteration), `interactive` approval gates, and platform adapters (Slack, Telegram, Discord, GitHub webhooks).

- **Project**: https://github.com/coleam00/Archon
- **Docs**: https://archon.diy/
- **Docker deployment**: https://archon.diy/deployment/docker/
- **Workflow authoring**: https://archon.diy/guides/authoring-workflows/

## Pipeline Position

```
Archon (workflow) → Omnigent (session) → Herdr (mux) → Pi (exec) → LiteLLM (aigate) → ...
```

Archon dispatches workflow nodes via the `IAgentProvider` interface. Built-in providers: `claude`, `codex`. Community providers: `pi`, `opencode`, `copilot`. The Pi provider routes LLM calls through the pipeline (Pi → LiteLLM → Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN → Internet).

When using the Claude provider directly, set `ANTHROPIC_BASE_URL` to the LiteLLM endpoint so Claude Code SDK calls route through the pipeline (auth, PII masking, spend tracking, Langfuse traces).

## Stack Components

| Component | Image | Purpose |
|-----------|-------|---------|
| archon | `ghcr.io/coleam00/archon:latest` | Bun + TypeScript server (Hono) + React web UI |
| archon-postgres | `postgres:17-alpine` | Workflow runs, conversations, sessions, artifacts |

The pre-built GHCR image ships with Claude Code SDK pre-installed (`CLAUDE_BIN_PATH` pre-set). No extra configuration needed for the Claude binary.

## Files

- `docker-compose.yml` — Reference topology (documentation only, per AGENTS.md)
- `.env.archon.j2` — Jinja2 env template (Ansible generates `.env.archon` from vault + infra vars)
- `.env.example` — Example env for local reference

## Deployment

Deployment is handled by Ansible — never run `docker compose up` directly. The playbook (`deploy-archon.yml`) uses `community.docker` modules to pull the pre-built image, create networks/volumes, and deploy containers.

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-archon.yml \
  --vault-password-file ~/.ansible/vault_password
```

See `levonk/active/03-container/services/archon/DEPLOYMENT.md` for client-specific deployment details.

## Secrets

All secrets sourced from the client Ansible vault (`infrahub-levonk-all.vault.yml`):

| Secret | Purpose |
|--------|---------|
| `archon_claude_api_key` | LiteLLM virtual key (when pipeline-routed) or Claude API key |
| `archon_postgres_password` | PostgreSQL database password |
| `archon_better_auth_secret` | Web UI auth session signing secret |
| `archon_telegram_bot_token` | Telegram adapter (optional) |
| `archon_discord_bot_token` | Discord adapter (optional) |
| `archon_github_token` | GitHub adapter + webhooks (optional) |
| `archon_webhook_secret` | GitHub webhook HMAC verification (optional) |

## References

- **Pipeline architecture**: `shared/docs/PIPELINE-AI.md` → "Archon + Omnigent + Herdr + Pi Agent Stack"
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-archon.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/archon/.env.archon.j2`
- **Levonk deployment**: `levonk/active/03-container/services/archon/DEPLOYMENT.md`
