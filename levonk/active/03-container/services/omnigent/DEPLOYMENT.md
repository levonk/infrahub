# Omnigent + Pi Deployment - Levonk Client

This directory contains the **levonk client-specific** deployment configuration for the Omnigent + Pi stack, layered on top of the shared stacks at:
- `shared/active/03-container/services/ai-codeassist/omnigent/` (Omnigent server + Postgres)
- `shared/active/03-container/services/ai-codeassist/pi/` (Pi coding agent harness, RPC mode)

## Architecture

Omnigent is the **orchestrator** (server + runner + UI). Pi is the **harness** — the coding agent that actually does the work (read, write, edit, bash tools). Omnigent's runner drives pi via RPC mode. Pi's LLM requests flow through the analytics pipeline.

```
Omnigent (server) → runner drives → Pi (RPC mode) → LLM requests → AI Dashboard Proxy 1 → pipeline
   :8000                                  :8090                          :8081
```

The shared stacks define the container topology. This client overlay provides:

- **Omnigent domain**: `aiif.levonk.com` (public alias "AI InterFace" — defined in `levonk/active/02-config/ansible/infrastructure/domains.yml`)
- **Omnigent ports**: `8000` (server), `5433` (postgres host-side, to avoid clashing with the ai-dashboard postgres on 5432)
- **Pi port**: `8090` (RPC bridge)
- **Secrets**: `OMNIGENT_DB_PASSWORD`, `OMNIGENT_ACCOUNTS_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD`, `PI_API_KEY` sourced from `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml` at deploy time
- **Public access**: https://aiif.levonk.com via Traefik with GeoBlock → CrowdSec Bouncer → Authelia security middleware chain
- **Workspace mount**: client-specific (mount the repos pi should operate on at `/workspace`)

## Pipeline Role

Omnigent + Pi together form the **request origin** of the analytics pipeline. Omnigent orchestrates, pi executes coding loops, and pi's LLM requests flow through the pipeline:

```
Omnigent → Pi (harness) → AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy → NordVPN → Internet
(server)   (RPC mode)        (Entry)              (PII Detection)    (Compression)   (Routing)       (Tool Calling)        (Pre-Egress)    (Security)    (Privacy)
```

See `shared/docs/PIPELINE-AI.md` for the full pipeline architecture.

## Deployment

Deployment is handled by Ansible — never run `docker compose up` directly. The playbook (`deploy-omnigent.yml`) copies the compose/Dockerfile/bridge/models.json to the target server, builds the pi image, generates the env file from the Jinja2 template (`.env.omnigent.j2`) using vault secrets + infrastructure vars, creates networks, and starts the containers.

### Prerequisites

- The shared Omnigent and Pi stacks must be wired into `docker-compose.localnet.yml` (done — see the includes for `services/ai-codeassist/omnigent/docker-compose.yml` and `services/ai-codeassist/pi/docker-compose.yml`).
- Vault secrets must be set in `levonk/active/02-config/ansible/inventories/group_vars/infrahub-levonk-all.vault.yml`:
  - `omnigent_db_password`
  - `omnigent_accounts_cookie_secret` (generate with `openssl rand -hex 32`)
  - `omnigent_accounts_init_admin_password` (for headless deploys)
  - `pi_api_key` (API key pi passes through to the pipeline; the pipeline handles real provider auth via Iron-Proxy)
- DNS record for `aiif.levonk.com` must point to the OCI cloud server IP (managed via Cloudflare Ansible playbook).
- The AI Dashboard pipeline must be running (pi routes LLM requests to `ai-dashboard-proxy-1:8081`).
- Traefik must be deployed (the omnigent container joins `traefik-network` for public routing).

### Deploy to OCI

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

### Register a Runner

After the server is up, register a host so the server can dispatch agent work:

```bash
# Log in (admin account created on first boot — see docker compose logs omnigent
# or use the vault-set OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD)
omni login https://aiif.levonk.com

# Register this machine as a host
omni host https://aiif.levonk.com
```

The runner will spawn pi (either as a local subprocess on the runner host, or by connecting to the containerized pi RPC bridge at `http://pi:8090` for cloud sandbox hosts).

For cloud sandbox hosts (no laptop dependency), see the [Cloud Sandbox Host docs](https://omnigent.ai/docs/deploy/sandbox). Modal and Daytona are supported.

### Verify

```bash
# Omnigent container status
docker ps | grep omnigent

# Pi container status
docker ps | grep pi

# Omnigent server health
curl https://aiif.levonk.com/api/health
# or locally:
curl http://localhost:8000/api/health

# Pi RPC bridge health
curl http://localhost:8090/health

# Logs
docker logs omnigent --tail=50 -f
docker logs omnigent-postgres --tail=50 -f
docker logs pi --tail=50 -f
```

## Configuration Override

The Ansible playbook generates the env file from `.env.omnigent.j2` using vault secrets + infrastructure vars. The shared compose files use `${OMNIGENT_TRAEFIK_HOST:-aiif.levonk.com}` for the Traefik Host rule and `${PI_API_BASE_URL:-http://ai-dashboard-proxy-1:8081/v1}` for pi's LLM endpoint. For levonk, these defaults already match the client infrastructure vars, so the playbook injects vault secrets and the domain/port from the infrastructure vars at deploy time.

To override container IPs, workspace mounts, or other values for the levonk deploy, add the overrides to the Ansible playbook or the vault group_vars — do not create docker-compose override files (deployment is Ansible-only).

## Security

- **Auth enabled** — `OMNIGENT_AUTH_ENABLED=1` (multi-user). Single-user mode is NEVER used for the levonk deploy.
- **Secrets in vault** — all secrets sourced from `infrahub-levonk-all.vault.yml`, never in plaintext.
- **Traefik security chain** — public access goes through GeoBlock (US only) → CrowdSec Bouncer → Authelia (SSO with 2FA).
- **Admin password** — set via `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` in the vault for headless deploys, or create the admin account in the web UI on first boot.
- **Pipeline-routed LLM** — pi's LLM traffic flows through the analytics pipeline (PII detection, egress firewall, VPN), never directly to providers.
- **Workspace isolation** — pi only operates on files within `/workspace`.

## References

- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2`
- **Omnigent shared stack**: `shared/active/03-container/services/ai-codeassist/omnigent/`
- **Pi shared stack**: `shared/active/03-container/services/ai-codeassist/pi/`
- **Omnigent project**: https://github.com/omnigent-ai/omnigent
- **Pi project**: https://github.com/earendil-works/pi
- **Deploy docs**: https://omnigent.ai/docs/deploy/overview
- **Pi RPC docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **Pipeline architecture**: `shared/docs/PIPELINE-AI.md`
