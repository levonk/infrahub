# Archon Deployment - Levonk Client

This directory contains the **levonk client-specific** deployment configuration for Archon, layered on top of the shared stack at:
- `shared/active/03-container/services/ai-codeassist/archon/` (Archon server + PostgreSQL)

## Architecture

Archon is the **workflow layer** of the AI pipeline's request origin stack. It provides YAML DAG workflows with loops, `fresh_context`, `interactive` approval gates, and platform adapters. Archon dispatches workflow nodes via the `IAgentProvider` interface to providers (Claude, Codex, Pi, OpenCode).

```
Archon (workflow) → Omnigent (aiif.levonk.com) → Herdr → Pi → LiteLLM (aigate) → pipeline → Internet
  :3090                  :8000                           :8090      :4000
  Windows Docker          OCI server                     OCI         OCI
```

**Deployment target**: Windows Docker Desktop (`dtop202311.tale-grouper.ts.net`)

The shared stack defines the container topology. This client overlay provides:

- **Archon port**: `3090` (host) → `3000` (container) — avoids conflict with WorldMonitor (3000)
- **PostgreSQL port**: `5436` (host) → `5432` (container) — avoids conflict with other postgres instances
- **Image**: `ghcr.io/coleam00/archon:latest` (pre-built, Claude Code SDK pre-installed)
- **Database**: PostgreSQL 17 Alpine
- **LLM routing**: `ANTHROPIC_BASE_URL=http://100.90.22.85:4000` (LiteLLM on OCI via Tailscale)
- **Access**: `http://dtop202311.tale-grouper.ts.net:3090` (Tailscale, no HTTPS — Tailscale encrypts transport)
- **Platform adapters**: Telegram, Discord, GitHub webhooks
- **Secrets**: sourced from `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`

## Pipeline Role

Archon is the **workflow layer** — the top of the request origin stack. It dispatches work via `IAgentProvider`:

- **Pi provider**: routes through Omnigent → Pi → LiteLLM pipeline (full pipeline integration)
- **Claude provider**: Claude Code SDK calls route through LiteLLM via `ANTHROPIC_BASE_URL` (auth, PII masking, spend tracking, Langfuse traces)

When `ANTHROPIC_BASE_URL` is set to the LiteLLM endpoint, `CLAUDE_API_KEY` becomes a LiteLLM virtual key. All Claude Code SDK calls flow through the pipeline instead of directly to Anthropic.

See `shared/docs/PIPELINE-AI.md` for the full pipeline architecture.

## Deployment

Deployment is handled by Ansible — never run `docker compose up` directly. The playbook (`deploy-archon.yml`) uses `community.docker` modules to pull the pre-built image from GHCR, create networks/volumes, and deploy containers on the Windows Docker Desktop host.

### Prerequisites

- Bootstrap playbook run on Windows: `just ansible-bootstrap-windows-docker`
- Docker Desktop running on `dtop202311.tale-grouper.ts.net`
- Tailscale connected (for LiteLLM pipeline access via OCI server at `100.90.22.85:4000`)
- Vault secrets set in `infrahub-levonk-all.vault.yml`:
  - `vault_archon_claude_api_key` — LiteLLM virtual key (or Claude API key if not pipeline-routed)
  - `vault_archon_postgres_password` — PostgreSQL password
  - `vault_archon_better_auth_secret` — Better Auth session signing secret (generate with `openssl rand -hex 32`)
  - `vault_archon_telegram_bot_token` — Telegram bot token (optional)
  - `vault_archon_discord_bot_token` — Discord bot token (optional)
  - `vault_archon_github_token` — GitHub personal access token (optional)
  - `vault_archon_webhook_secret` — GitHub webhook HMAC secret (optional)
  - `vault_archon_auth_allowed_emails` — comma-separated email allowlist for Web UI signup (optional)

### Deploy to Windows Docker Desktop

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-archon.yml \
  --vault-password-file ~/.ansible/vault_password
```

Dry run (check + diff):

```bash
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/windows-docker.yml \
  shared/active/02-config/ansible/playbooks/deploy-archon.yml \
  --check --diff --vault-password-file ~/.ansible/vault_password
```

### Verify

```bash
# Archon container status (on the Windows host)
docker ps | grep archon

# Archon Web UI health
curl http://dtop202311.tale-grouper.ts.net:3090/api/health
# or from the Windows host itself:
curl http://localhost:3090/api/health

# Logs
docker logs archon --tail=50 -f
docker logs archon-postgres --tail=50 -f
```

### Access the Web UI

Open `http://dtop202311.tale-grouper.ts.net:3090` in a browser from any Tailscale-attached machine. Create an admin account on first boot, or set `vault_archon_auth_allowed_emails` in the vault to pre-allowlist emails.

## Configuration Override

The Ansible playbook deploys containers using `community.docker` modules with env vars from the vault + infrastructure vars. The shared compose file is reference/documentation only. To override ports, image tags, or other values for the levonk deploy, add overrides to `windows_docker_hosts.yml` or the vault — do not create docker-compose override files.

### LLM Routing Configuration

The `ANTHROPIC_BASE_URL` env var tells the Claude Code SDK subprocess inside the Archon container to send API calls to LiteLLM instead of directly to Anthropic. The OCI server's Tailscale IP (`100.90.22.85`) is used with LiteLLM's port (`4000`).

If LiteLLM is not accessible from the Windows box (e.g., Tailscale down), set `archon_anthropic_base_url` to empty in `windows_docker_hosts.yml` and provide a direct Claude API key as `vault_archon_claude_api_key`. This bypasses the pipeline (no PII masking, no Langfuse traces, no spend tracking) but allows Archon to function.

## Security

- **Better Auth enabled** — Web UI requires login. Signup is closed by default; allowlist emails via `vault_archon_auth_allowed_emails`.
- **Secrets in vault** — all secrets sourced from `infrahub-levonk-all.vault.yml`, never in plaintext.
- **Tailscale-only access** — the Web UI is accessible only from Tailscale-attached machines. No public exposure, no HTTPS needed (Tailscale encrypts transport).
- **Pipeline-routed LLM** — when `ANTHROPIC_BASE_URL` is set, all LLM traffic flows through the analytics pipeline (PII detection, egress firewall, VPN), never directly to providers.
- **Container isolation** — Archon runs as non-root `appuser` (UID 1001) inside the container.

## References

- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-archon.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/archon/.env.archon.j2`
- **Archon shared stack**: `shared/active/03-container/services/ai-codeassist/archon/`
- **Archon project**: https://github.com/coleam00/Archon
- **Archon docs**: https://archon.diy/
- **Docker deployment**: https://archon.diy/deployment/docker/
- **Pipeline architecture**: `shared/docs/PIPELINE-AI.md` → "Archon + Omnigent + Herdr + Pi Agent Stack"
