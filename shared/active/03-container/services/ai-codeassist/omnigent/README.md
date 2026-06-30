# Omnigent - AI Agent Framework & Meta-Harness

Omnigent is an open-source AI agent framework that orchestrates Claude Code, Codex, Cursor, Pi, and custom agents from a central server. Swap harnesses without rewriting, enforce policies and sandboxing, and collaborate in real time from any device.

- **Project**: https://github.com/omnigent-ai/omnigent
- **Deploy docs**: https://omnigent.ai/docs/deploy/overview
- **License**: Apache 2.0

## Architecture

Omnigent has three components (per [upstream deploy docs](https://omnigent.ai/docs/deploy/overview)):

1. **Server** (this stack) — central coordinator. Manages session history, artifacts, catalog, MCP proxy & policies, skills, and auth & accounts. FastAPI/WebSocket server backed by Postgres (or SQLite).
2. **Runner** (host-registered, NOT in this stack) — per-session process that executes Omnigent loops. Manages the harness (Claude Code, Codex, etc.), runs tools, streams events back to the server over WebSocket. Registers against the server via `omni host <server-url>`.
3. **UI** — web, terminal, and mobile UIs talk to the server, never the runner directly. Cloud-hosted servers allow multi-user collaboration.

```
┌─────────────────────────────────────────────────────────────────┐
│  This stack (shared/active/03-container/services/ai-codeassist/ │
│  omnigent/docker-compose.yml)                                   │
│                                                                 │
│  ┌──────────────┐         ┌──────────────────────┐              │
│  │  omnigent    │ ──────▶ │  omnigent-postgres   │              │
│  │  (server)    │         │  (PostgreSQL 16)     │              │
│  │  :8000       │         │  :5432               │              │
│  └──────┬───────┘         └──────────────────────┘              │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │ WebSocket (events)
          ▼
  ┌────────────────┐
  │  Runner (host) │  ← registered via `omni host <server-url>`
  │  Claude Code,  │     on a laptop or cloud sandbox host
  │  Codex, Pi...  │     (Modal / Daytona)
  └────────────────┘
          ▲
          │ HTTP / WebSocket
  ┌────────────────┐
  │  Web / Mobile  │  ← talk to the server, never the runner
  │  / Terminal UI │
  └────────────────┘
```

## Pipeline Position

Omnigent sits at the **client entry point** of the AI analytics pipeline — it is the agent harness that *originates* requests which then flow through the analytics pipeline. It is not a mid-pipeline stage like Headroom or Forge; it is the source of AI work that the pipeline observes and optimizes.

```
Omnigent (agent harness) → AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
   (originates requests)        (Entry)              (PII Detection)    (Compression)   (Routing)       (Tool Calling)        (Pre-Egress)    (Security)    (Privacy)
```

See `shared/active/03-container/services/ai-dashboard/PIPELINE.md` for the full pipeline architecture and how Omnigent wires in as the request origin.

## Configuration

### Environment Variables

All secrets (`OMNIGENT_DB_PASSWORD`, `OMNIGENT_OIDC_CLIENT_SECRET`, `OMNIGENT_ACCOUNTS_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD`) MUST be sourced from the client Ansible vault at deploy time — NEVER commit real values to `shared/`.

See `.env.example` for the full variable reference. Key variables:

| Variable | Purpose | Default |
| --- | --- | --- |
| `OMNIGENT_DB_PASSWORD` | Postgres password (required) | — (must set) |
| `OMNIGENT_HOST_PORT` | Host port for the server | `8000` |
| `OMNIGENT_AUTH_ENABLED` | Master auth switch | `1` (multi-user) |
| `OMNIGENT_AUTH_PROVIDER` | Force `accounts`/`oidc`/`header` | auto-detect |
| `OMNIGENT_DOMAIN` | Public domain (OIDC redirect + Caddy) | — |
| `OMNIGENT_ACCOUNTS_BASE_URL` | Public base URL for accounts mode | — |
| `OMNIGENT_IMAGE` | Server image | `ghcr.io/omnigent-ai/omnigent-server` |
| `OMNIGENT_IMAGE_TAG` | Image tag (pin for reproducible deploys) | `latest` |

### Auth Modes

- **Accounts (default)** — built-in username + password bootstrap. First boot auto-creates an admin user and prints the password to `docker compose logs omnigent` (saved to `/data/admin-credentials`). Set `OMNIGENT_ACCOUNTS_BASE_URL` for any deploy behind a public domain.
- **OIDC** — native login flow with a signed session cookie. Set `OMNIGENT_OIDC_ISSUER` (plus client id/secret/cookie secret). The server derives the redirect URI as `https://<OMNIGENT_DOMAIN>/auth/callback`.
- **Header** — for deploys behind a trusted proxy that injects `X-Forwarded-Email` (oauth2-proxy, Cloudflare Access, Databricks Apps). Set `OMNIGENT_AUTH_PROVIDER=header`.

Set `OMNIGENT_AUTH_ENABLED=0` ONLY for single-user local dev — NEVER for shared deploys.

## Usage

### Deployment

Deployment is handled by Ansible — never run `docker compose up` directly for deployment. The playbook copies the compose files to the target server, generates the env file from vault secrets + infrastructure vars, builds images, creates networks, and starts containers.

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --vault-password-file ~/.ansible/vault_password
```

Dry run (check + diff):

```bash
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --check --diff --vault-password-file ~/.ansible/vault_password
```

### Register a Runner (Host)

The server is useless without a runner. On a machine with Claude Code / Codex / Pi installed:

```bash
# If auth is enabled, log in first (open the web UI to create the admin account,
# or use the password printed to `docker compose logs omnigent` on first boot)
omni login https://omnigent.levonk.com

# Register this machine as a host so the server can dispatch agent work to it
omni host https://omnigent.levonk.com
```

For cloud sandbox hosts (no laptop dependency), see the [Cloud Sandbox Host docs](https://omnigent.ai/docs/deploy/sandbox). Modal and Daytona are supported.

### View Logs

```bash
docker logs omnigent --tail=50 -f
docker logs omnigent-postgres --tail=50 -f
```

### Health Check

```bash
curl http://localhost:8000/api/health
```

### Access the Web UI

- **Local**: http://localhost:8000
- **Public (levonk)**: https://omnigent.levonk.com (via Traefik with Authelia + CrowdSec + GeoBlock)

## Client Deployment (levonk)

The shared stack defines the container topology. Client-specific values (domain, ports, vault secrets) are injected by the Ansible playbook at deploy time:

- **Domain/port overrides**: `levonk/active/02-config/ansible/infrastructure/{ports,domains}.yml`
- **Vault secrets**: `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2` (Ansible templates this with vault + infra vars)
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Deployment doc**: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`

Deploy to the Levonk OCI cloud server via Ansible:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --vault-password-file ~/.ansible/vault_password
```

## Network Configuration

- **Name**: `omnigent-network`
- **Type**: bridge
- **Subnet**: `172.36.0.0/16`
- **Purpose**: Internal communication between omnigent server and Postgres
- **Traefik network**: `traefik-network` (external) for public routing

## Security Considerations

1. **Auth enabled by default** — `OMNIGENT_AUTH_ENABLED=1` in Docker. Single-user mode (`=0`) is NEVER for shared deploys.
2. **Secret injection at boundary** — DB password, OIDC client secret, and cookie secrets come from the client vault, not plaintext env files.
3. **Traefik security chain** — public access goes through GeoBlock → CrowdSec Bouncer → Authelia.
4. **No admin password auto-generated** — on first boot the server reports `needs_setup`: create the admin account in the web UI, or set `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` for headless deploys.
5. **Image pinning** — pin `OMNIGENT_IMAGE_TAG` to `sha-<short>` or `vX.Y.Z` for reproducible deploys.

## References

- **Omnigent project**: https://github.com/omnigent-ai/omnigent
- **Deploy overview**: https://omnigent.ai/docs/deploy/overview
- **Auth & SSO**: https://omnigent.ai/docs/deploy/auth
- **Cloud Sandbox Host**: https://omnigent.ai/docs/deploy/sandbox
- **Pair Programming (collaboration)**: https://omnigent.ai/docs/deploy/pair-programming
- **REST API**: https://omnigent.ai/docs/reference
