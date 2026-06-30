# AI Dashboard Pipeline Configuration

## Recent Changes

**2026-06-29**: Added LiteLLM as the AI gateway entry point (aigate.levonk.com)
- LiteLLM (https://github.com/BerriAI/litellm) is an OSS AI Gateway with auth, virtual keys, spend tracking, PII guardrail (Presidio), and native Langfuse logging
- Replaces AI Dashboard Proxy 1/2 (analytics collectors) and Privacy Orchestrator (PII detection) as the pipeline entry point
- LiteLLM sits BEFORE Headroom: PII guardrail runs on raw text (more reliable), spend tracking on original request size, auth/keys reject bad requests early
- Domain: aigate.levonk.com (Traefik + GeoBlock + CrowdSec + Authelia)
- Ansible role: `roles/ai-litellm/`, deploy playbook: `playbooks/deploy-ai-gateway-pipeline.yml`
- **Status**: DEFINED - Ansible role created, vault secrets added, DNS configured

**2026-06-29**: Renamed OmniRoute domain from ai-gateway.levonk.com to airoute.levonk.com
- LiteLLM (aigate) is now the gateway entry point; OmniRoute (airoute) is the routing layer
- OmniRoute's unique strengths preserved: 4-tier subscription-draining fallback, 9-factor auto-combo scoring, free-tier maximization, 14 routing strategies
- See PIPELINE-LITELLM-JANUS-NOTES.md for the full LiteLLM vs OmniRoute comparison

**2026-06-28**: Added Langfuse as parallel LLM observability backend
- Langfuse (https://github.com/langfuse/langfuse) is an LLM tracing & observability platform
- Deployed as a parallel analytics sink receiving traces from AI Dashboard Proxy 1 (entry collector)
- NOT a serial forwarding stage — receives trace data alongside the pipeline's own analytics DB
- Stack: langfuse-web (UI + ingestion API) + langfuse-worker (async ingestion) + postgres + clickhouse + redis + minio
- Web UI at https://langfuse.levonk.com (Traefik + GeoBlock + CrowdSec + Authelia)
- **Status**: DEFINED - shared stack at `services/ai-dashboard/langfuse/`, deploy playbook at `playbooks/deploy-langfuse.yml`
- See "Langfuse Observability Backend" section for details

**2026-06-28**: Added Omnigent + Pi as the agent stack that originates pipeline requests
- Omnigent (https://omnigent.ai/docs/deploy/overview) is the AI agent framework & meta-harness that orchestrates Claude Code, Codex, Cursor, Pi, and custom agents
- Pi (https://github.com/earendil-works/pi) is the minimal terminal coding harness — the agent that actually does the coding work (read, write, edit, bash tools)
- Omnigent's runner drives pi via RPC mode (JSONL over stdin/stdout); pi's LLM requests flow through the analytics pipeline
- Together they form the **request origin**: Omnigent orchestrates, pi executes, pipeline observes/optimizes/secures
- Deployed as omnigent server + Postgres + pi (RPC mode) containers; runners register against the server via `omni host`
- **Status**: DEFINED - shared stacks at `services/ai-codeassist/omnigent/` and `services/ai-codeassist/pi/`, levonk deployment at `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`
- See "Omnigent + Pi Agent Stack" section for details

**2026-06-24**: Repositioned Forge tool calling reliability layer in pipeline architecture
- Moved from between Privacy Orchestrator and Headroom to after OmniRoute
- Better positioning: Forge now operates on LLM responses after routing
- Prevents compression from interfering with tool call fixes
- **Status**: IMPLEMENTED - forge service deployed
- See "Forge Implementation" section for details

**2026-06-24**: Implemented Privacy Orchestrator stage in pipeline architecture
- New stage between AI Dashboard Proxy 1 and Forge
- Implements PII detection and transformation using Rust-based Privacy Orchestrator
- **Status**: IMPLEMENTED - ai-privacy-proxy service deployed
- See "Privacy Orchestrator Implementation" section for details

## Overview

This configuration implements a multi-stage AI analytics pipeline with comprehensive data collection at key stages. The pipeline provides deep visibility into AI usage patterns, optimization effectiveness, and security analytics.

## Pipeline Architecture

```
Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Forge → Iron-Proxy → NordVPN → Internet
(server)   (harness)  (Entry)        (Compress)  (Routing)          (Tool Fix) (Security)   (Privacy)
                      (auth, keys,
                       PII, spend,
                       Langfuse)
                      │
                      ↓ (forwards traces)
                Langfuse (LLM Observability — parallel analytics sink)
                langfuse-web → postgres + clickhouse + redis + minio
```

**Note**: LiteLLM is the entry point for the pipeline. It handles auth, virtual keys, spend tracking, PII guardrail (Presidio masking), and forwards traces to Langfuse. LiteLLM routes to Headroom for context compression, then to OmniRoute for provider fanout (tier-based fallback, 9-factor auto-combo scoring, free-tier draining). Forge repairs tool-call format issues from non-conforming backends. Iron-Proxy enforces egress firewall policy. NordVPN provides privacy/geo-obfuscation.

**Previous architecture** (pre-2026-06-29): AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy. The Proxy 1/2 collectors and Privacy Orchestrator are now absorbed into LiteLLM. See PIPELINE-LITELLM-JANUS-NOTES.md for the full analysis.

### Request Origin

The pipeline originates from the **Omnigent + Pi agent stack**. Omnigent (https://omnigent.ai/docs/deploy/overview) is the AI agent framework & meta-harness that orchestrates coding agents from a central server. Pi (https://github.com/earendil-works/pi) is the minimal terminal coding harness — the agent that actually does the coding work (read, write, edit, bash tools).

Omnigent's runner drives pi via **RPC mode** (JSONL over stdin/stdout). Pi's LLM requests are routed to the pipeline entry at **LiteLLM (aigate)** via a custom "pipeline" provider in pi's `models.json` config. The pipeline entry speaks OpenAI-compatible API, so pi treats it as an OpenAI provider with a custom base URL (`http://litellm:4000/v1`). LiteLLM then handles auth, PII masking, spend tracking, and Langfuse logging before forwarding to Headroom for compression and OmniRoute for provider fanout.

Omnigent + Pi are NOT mid-pipeline transformation stages like Headroom or Forge — they are the **source of AI work** that the pipeline observes, optimizes, and secures. The pipeline stages below describe what happens to a request after pi emits it.

### Compression Strategy

**Headroom-Primary Compression:**
- Headroom handles all compression (60-95% token savings)
- OmniRoute compression disabled to avoid redundancy
- OmniRoute focuses on intelligent provider routing
- Caveman compression available as fallback in OmniRoute if needed
- This eliminates compression redundancy and optimizes routing decisions

### Pipeline Stages

1. **LiteLLM (AI Gateway — Entry Stage)**
   - Auth, virtual keys, spend tracking per key/user/team/org
   - PII guardrail (Presidio masking) — runs on raw text before compression
   - Native Langfuse logging integration (parallel observability sink)
   - Admin dashboard UI for spend, keys, teams, models
   - Routes all requests to Headroom as upstream
   - **Implementation**: LiteLLM (https://github.com/BerriAI/litellm)
   - **Domain**: aigate.levonk.com
   - **Port**: 4000
   - **Chain IP**: 172.29.0.18
   - **Traefik IP**: 172.31.0.18
   - **Upstream to**: Headroom
   - **Status**: **DEFINED** - Ansible role at `roles/ai-litellm/`

2. **Headroom (Context Compression)**
   - Compresses LLM context to reduce token usage
   - Applies RTK+Caveman stacked compression (15-95% token savings)
   - **Port**: 8787
   - **Upstream from**: LiteLLM
   - **Downstream to**: OmniRoute

3. **OmniRoute (AI Gateway — Provider Fanout)**
   - Smart routing across 177+ AI providers (50+ free)
   - 4-tier auto-fallback: Subscription → API → Cheap → Free
   - 9-factor auto-combo scoring (health, quota, cost, latency, success rate, freshness)
   - 14 routing strategies (priority, cost-optimized, context-relay, lkgp, reset-aware, etc.)
   - **Compression completely disabled** (Headroom handles compression)
   - **RTK disabled** (avoids redundancy with Headroom)
   - **Caveman disabled** (avoids redundancy with Headroom)
   - **Domain**: airoute.levonk.com
   - **Port**: 20128
   - **Upstream from**: Headroom
   - **Downstream to**: Forge

4. **Forge (Tool Calling Reliability Layer)**
   - Fixes tool calling issues in AI requests
   - Python-based service with guardrails for LLM tool calling
   - Response validation, rescue parsing, retry loop with error tracking
   - Synthetic `respond` tool injection for better model behavior
   - **Implementation**: forge service (https://github.com/antoinezambelli/forge)
   - **Port**: 8081
   - **Upstream from**: OmniRoute
   - **Downstream to**: Iron-Proxy
   - **Status**: **IMPLEMENTED** - deployed as Python service

5. **Iron-Proxy (Egress Firewall)**
   - Default-deny egress filtering
   - Secret injection at boundary
   - Per-request audit trail
   - **Port**: 8880 (levonk override)
   - **Upstream from**: Forge
   - **Downstream to**: NordVPN

6. **NordVPN (Privacy Layer)**
   - VPN tunnel for privacy and geo-obfuscation
   - Routes all egress traffic through VPN
   - **Port**: 1080
   - **Upstream from**: Iron-Proxy
   - **Downstream to**: Internet

## Analytics Dimensions

The AI Dashboard collects multi-dimensional analytics across:

- **Company Clients**: Multi-tenant client identification and isolation
- **AI Clients**: Claude Code, Codex, Pi, Devin, Cursor, Cline, etc.
- **Teams**: Team/sub-organization hierarchy within clients
- **Pipeline Stages**: Entry, compression, routing, pre-egress analytics
- **AI Model Suppliers**: Anthropic, OpenAI, Google, Microsoft, AWS, OpenRouter, etc.
- **Models**: GPT-4, Claude 3.5 Opus, Gemini Pro, etc.
- **Input Types**: Text/chat, image, audio, video, code, etc.

## Key Metrics Tracked

### Entry Stage (Proxy 1)
- Original request size and token count
- Client identification and authentication
- Request timing and latency
- Input type classification

### Forge Analytics
- Tool calling validation rates and categories
- Rescue parsing effectiveness (JSON code fences, Mistral `[TOOL_CALLS]`, Qwen XML)
- Retry loop statistics and success rates
- Processing latency (sub-millisecond expected)
- Synthetic `respond` tool usage patterns
- Backend compatibility metrics (llama-server, Ollama, vLLM, Anthropic)

### Privacy Orchestrator Analytics
- PII detection rates and categories
- Transformation effectiveness metrics (redaction, masking, tokenization)
- Processing latency (sub-millisecond expected)
- False positive/negative rates
- Multi-language coverage statistics
- Transformation mode usage patterns

### Compression Analytics (Headroom comparison)
- Token savings percentage (Headroom: 60-95%)
- Compression ratio (measured by Headroom)
- Processing time overhead
- Context preservation metrics
- **Note**: OmniRoute compression disabled to avoid redundancy

### Routing Analytics (OmniRoute comparison)
- Provider selection patterns
- Fallback events
- Format translation overhead
- Provider performance metrics

### Pre-Egress Stage (Proxy 2)
- Optimized request size and token count
- Final provider selection
- Cost calculation
- Security classification

### Security Analytics (Iron-Proxy)
- Domain allowlist hits/blocks
- Secret injection events
- Anomaly detection
- Audit trail completeness

## Configuration Files

### docker-compose.ai-dashboard-pipeline.yml
Main Docker Compose configuration for the pipeline. Defines:
- Dual AI Dashboard proxy collectors
- Shared PostgreSQL database
- Network configuration
- Health checks and dependencies

### .env.pipeline
Environment variables for pipeline configuration:
- Database connection settings
- Collector IP addresses and ports
- Stage identification
- Upstream service URLs

## Usage

### Start the Pipeline

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- docker compose -f shared/active/03-container/docker-compose.localnet.yml --profile ai-dashboard-pipeline up -d
```

### Start with Environment File

```bash
cd ~/p/gh/levonk/infrahub/shared/active/03-container/services/ai-dashboard
docker compose -f docker-compose.ai-dashboard-pipeline.yml --env-file .env.pipeline up -d
```

### View Logs

```bash
# Entry stage collector
docker logs ai-dashboard-proxy-1 --tail=50 -f

# Privacy Orchestrator
docker logs privacy-orchestrator --tail=50 -f

# Forge
docker logs forge --tail=50 -f

# Pre-egress stage collector
docker logs ai-dashboard-proxy-2 --tail=50 -f

# Database
docker logs ai-dashboard-db --tail=50 -f
```

### Check Health

```bash
# Entry stage health
curl http://localhost:8081/health

# Privacy Orchestrator health
curl http://localhost:9090/health

# Forge health
curl http://localhost:8083/health

# Pre-egress stage health
curl http://localhost:8082/health

# Database health
docker exec ai-dashboard-db pg_isready -U postgres
```

### Access Analytics

- **AI Dashboard Web Interface**: https://ai-dashboard.levonk.com (single interface for both proxy collectors)
- **Entry Stage API**: http://localhost:9081
- **Privacy Orchestrator API**: http://localhost:9090
- **Forge API**: http://localhost:8083
- **Pre-Egress Stage API**: http://localhost:9082
- **Database**: postgresql://postgres:postgres@localhost:5432/analytics

## Omnigent + Pi Agent Stack

### Overview
The Omnigent + Pi stack is the **request origin** of the analytics pipeline — the source of AI work that the pipeline observes, optimizes, and secures. It is NOT a mid-pipeline transformation stage like Headroom or Forge.

- **Omnigent** (https://omnigent.ai/docs/deploy/overview) — the AI agent framework & meta-harness that orchestrates coding agents from a central server.
- **Pi** (https://github.com/earendil-works/pi) — the minimal terminal coding harness that actually does the coding work (read, write, edit, bash tools). This is the harness Omnigent's runner drives.

### Architecture
Omnigent has three components:
- **Server** (deployed in this stack) — central coordinator managing session history, artifacts, catalog, MCP proxy & policies, skills, and auth & accounts. FastAPI/WebSocket server backed by Postgres.
- **Runner** (host-registered, NOT in the pipeline stack) — per-session process that manages the harness. Registers against the server via `omni host <server-url>`.
- **UI** — web, terminal, and mobile UIs talk to the server, never the runner directly.

Pi runs in **RPC mode** (`pi --mode rpc`) — a JSONL protocol over stdin/stdout. Omnigent's runner drives pi via this protocol. For local-runner deploys (laptop), the runner spawns pi as a local subprocess. For cloud sandbox hosts, the runner connects to a containerized pi via an HTTP-to-stdin RPC bridge (`rpc-bridge.py`, port 8090).

### Pipeline Integration
Pi's LLM requests (chat completions, messages) are routed to the pipeline entry at **AI Dashboard Proxy 1** via a custom "pipeline" provider in pi's `models.json` config. The pipeline entry speaks OpenAI-compatible API, so pi treats it as an OpenAI provider with a custom base URL (`http://ai-dashboard-proxy-1:8081/v1`). The pipeline then collects analytics, detects/transforms PII, compresses context, routes across providers, fixes tool calling, collects pre-egress analytics, enforces egress firewall policy, and routes through VPN — all transparent to the pi agent.

### Configuration
**Omnigent:**
- **Server image**: `ghcr.io/omnigent-ai/omnigent-server:latest` (pin `OMNIGENT_IMAGE_TAG` for reproducible deploys)
- **Server port**: 8000 (container), 8000 (host) — `infra_port_ai_omnigent_host`
- **Postgres port**: 5432 (container), 5433 (host, avoids clashing with ai-dashboard postgres) — `infra_port_ai_omnigent_postgres_host`
- **Domain**: `aiif.levonk.com` (public alias "AI InterFace") — `infra_domain_ai_omnigent`
- **Auth**: multi-user with built-in accounts by default (`OMNIGENT_AUTH_ENABLED=1`); OIDC supported via `OMNIGENT_OIDC_*` vars
- **Secrets**: `OMNIGENT_DB_PASSWORD`, `OMNIGENT_ACCOUNTS_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` sourced from the client Ansible vault

**Pi:**
- **Image**: `localnet-pi:latest` (built from `Dockerfile`, installs `@earendil-works/pi-coding-agent` from npm)
- **RPC bridge port**: 8090 (container), 8090 (host) — `infra_port_ai_pi_host`
- **LLM endpoint**: `http://ai-dashboard-proxy-1:8081/v1` (pipeline entry, via custom "pipeline" provider in `models.json`)
- **Default model**: `claude-sonnet-4-20250514` (routed through the pipeline to OmniRoute → real provider)
- **Session storage**: `/data/sessions` (named volume `localnet-pi-sessions-volume`)
- **Workspace**: `/workspace` (code repos mounted by client overlay)
- **Secrets**: `PI_API_KEY` sourced from the client Ansible vault (passed through to pipeline; pipeline handles real provider auth via Iron-Proxy)

### Container Configuration
The Omnigent + Pi stack is deployed as Docker containers with security hardening:
- **Omnigent**: Pre-built slim Python container from GHCR (FastAPI/WebSocket coordinator) + PostgreSQL 16 Alpine
- **Pi**: Node.js 22 slim container with `@earendil-works/pi-coding-agent` installed, running `rpc-bridge.py` (HTTP-to-stdin bridge for pi RPC mode)
- **Networks**: `omnigent-network` (172.36.0.0/16) for Omnigent↔Pi↔Postgres; `ai-dashboard-network` (172.35.0.0/16) for Pi→AI Dashboard Proxy 1; `traefik-network` (external) for public routing
- **Volumes**: `omnigent-postgres-data`, `omnigent-artifact-data`, `pi-data`, `pi-sessions`
- **Traefik**: Public access via `aiif.levonk.com` with GeoBlock → CrowdSec Bouncer → Authelia security middleware chain
- **Profile**: `omnigent` (both Omnigent and Pi start under this profile)

### Deployment
Deployment is handled by Ansible — never run `docker compose up` directly for deployment.

Shared stacks (topology definitions, copied to the server by the playbook):
- `shared/active/03-container/services/ai-codeassist/omnigent/docker-compose.yml`
- `shared/active/03-container/services/ai-codeassist/pi/docker-compose.yml`

Ansible playbook (copies files, builds images, generates env from vault + infra vars, creates networks, starts containers):
- `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`

Env template (Jinja2, templated by Ansible with vault secrets + infrastructure vars):
- `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2`

Levonk client overlay: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`

```bash
# Deploy to OCI (levonk)
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --vault-password-file ~/.ansible/vault_password

# Dry run
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-omnigent.yml \
  --check --diff --vault-password-file ~/.ansible/vault_password

# Register a runner (host) so the server can dispatch agent work
omni login https://aiif.levonk.com
omni host https://aiif.levonk.com
```

### Verification
```bash
# Check omnigent + pi containers
docker ps | grep -E "omnigent|pi"

# Omnigent server health
curl https://aiif.levonk.com/api/health
# or locally:
curl http://localhost:8000/api/health

# Pi RPC bridge health
curl http://localhost:8090/health

# View logs
docker logs omnigent --tail=50 -f
docker logs omnigent-postgres --tail=50 -f
docker logs pi --tail=50 -f
```

### References
- **Omnigent project**: https://github.com/omnigent-ai/omnigent
- **Omnigent deploy docs**: https://omnigent.ai/docs/deploy/overview
- **Omnigent auth & SSO**: https://omnigent.ai/docs/deploy/auth
- **Omnigent cloud sandbox host**: https://omnigent.ai/docs/deploy/sandbox
- **Pi project**: https://github.com/earendil-works/pi
- **Pi RPC docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **Pi SDK docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sdk.md
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2`
- **Omnigent shared stack**: `shared/active/03-container/services/ai-codeassist/omnigent/`
- **Pi shared stack**: `shared/active/03-container/services/ai-codeassist/pi/`
- **Levonk deployment**: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`

## Forge Implementation

### Overview
Forge is a reliability layer for self-hosted LLM tool-calling that sits between OmniRoute and AI Dashboard Proxy 2 in the AI analytics pipeline. It applies guardrails to LLM tool calls to improve reliability and correctness.

### Key Features
- **Response Validation**: Each tool call is checked against the tools array in the request
- **Rescue Parsing**: Extracts tool calls from wrong formats (JSON in code fences, Mistral `[TOOL_CALLS]`, Qwen XML)
- **Retry Loop**: Retries inference with corrective messages on validation failure (up to 3 retries)
- **Synthetic `respond` Tool**: Injects a synthetic tool the model calls instead of producing bare text

### Configuration
- **Backend URL**: Points to OmniRoute service (`http://omniroute:20128`)
- **Max Retries**: 3 (configurable via `FORGE_MAX_RETRIES`)
- **Reasoning Replay**: `none` (most token-efficient policy)
- **Host Port**: 8083
- **Container Port**: 8081
- **Container IP**: 172.35.0.16
- **Chain IP**: 172.29.0.16

### Container Configuration
The forge service is built from a Python 3.12 base image with the following structure:
- **Dockerfile**: Multi-stage build with security hardening
- **Requirements**: `forge-guardrails[anthropic]>=0.7.0`
- **User**: Non-root execution (UID/GID 1000)
- **Security**: Read-only filesystem, capability dropping, no-new-privileges

### Deployment
Forge is deployed via the AI dashboard pipeline playbook:
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Verification
```bash
# Check forge container status
docker ps | grep forge

# View forge logs
docker logs forge --tail=50 -f

# Health check
curl http://localhost:8081/health
```

### References
- Project: https://github.com/antoinezambelli/forge
- Documentation: https://github.com/antoinezambelli/forge#proxy-server
- PyPI: https://pypi.org/project/forge-guardrails/

## Langfuse Observability Backend

### Overview
Langfuse is an open-source LLM engineering platform that provides tracing, analytics, prompt management, and evaluation for LLM applications. It is deployed as a **parallel analytics sink** that receives traces from AI Dashboard Proxy 1 (the entry collector), giving deep visibility into LLM request/response lifecycle, token usage, costs, and quality — without adding latency to the pipeline's request path.

- **Project**: https://github.com/langfuse/langfuse
- **Self-hosting docs**: https://langfuse.com/self-hosting/docker-compose

### Architecture
Langfuse is NOT a serial forwarding stage. It runs alongside the pipeline as an observability backend:

```
AI Dashboard Proxy 1 ──┬──→ (pipeline continues: Privacy Orchestrator → Headroom → ...)
                       └──→ (forwards traces) → langfuse-web ingestion API
```

The ingestion API (`/api/public/ingestion`) accepts OpenTelemetry-style trace data. AI Dashboard Proxy 1 forwards trace events (request, response, generation, span) to Langfuse asynchronously. Langfuse stores metadata in PostgreSQL, event data in ClickHouse, blobs (media) in MinIO, and uses Redis (BullMQ) for async ingestion processing via the worker.

### Stack Components
- **langfuse-web** — Next.js web UI + ingestion API (port 3000 container, 3001 host). Exposed via Traefik at `langfuse.levonk.com` with GeoBlock → CrowdSec → Authelia security chain.
- **langfuse-worker** — Async ingestion processor consuming from Redis queue, writing to ClickHouse + MinIO (port 3030 container).
- **langfuse-postgres** — Metadata store (orgs, projects, users, prompts, evaluations). PostgreSQL 17 Alpine (port 5432 container, 5434 host).
- **langfuse-clickhouse** — Columnar store for high-volume trace/event data (HTTP 8123, TCP 9000 container).
- **langfuse-redis** — BullMQ queue for async ingestion (port 6379 container, internal only).
- **langfuse-minio** — S3-compatible blob storage for media uploads and batch exports (API 9000 container, 9190 host; console 9001 container).

### Configuration
- **Network**: `langfuse-network` (172.37.0.0/16) for internal service communication
- **Cross-network**: langfuse-web also joins `ai-dashboard-network` (172.35.0.0/16) so Proxy 1 can reach the ingestion API at `http://langfuse-web:3000`, and `traefik-network` (172.31.0.0/16) for public routing
- **Domain**: `langfuse.levonk.com` — `infra_domain_ai_langfuse`
- **Secrets**: All sensitive values (postgres password, salt, encryption key, nextauth secret, redis auth, clickhouse password, minio credentials) sourced from the client Ansible vault (`vault_langfuse_*` variables)
- **Telemetry**: Disabled (`TELEMETRY_ENABLED=false`) — no data leaves the deployment
- **Headless init**: Optional — set `vault_langfuse_init_*` vars to bootstrap org/project/user on first start

### Container Configuration
- **Images**: Official Langfuse v3 images from Docker Hub (`langfuse/langfuse:3`, `langfuse/langfuse-worker:3`)
- **Volumes**: Named Docker volumes for persistence (`localnet-langfuse-*-volume`)
- **Security**: Non-root execution where possible (ClickHouse runs as UID 101), json-file logging with rotation
- **Profile**: `langfuse` (langfuse-web and langfuse-worker start under this profile; infra services start unconditionally)

### Deployment
Deployment is handled by Ansible — never run `docker compose up` directly for deployment.

Shared stack (topology definition, copied to the server by the playbook):
- `shared/active/03-container/services/ai-dashboard/langfuse/docker-compose.langfuse.yml`

Ansible playbook (configures Cloudflare DNS, copies files, generates env from vault + infra vars, creates networks, starts containers):
- `shared/active/02-config/ansible/playbooks/deploy-langfuse.yml`
  - Play 1: Configures `langfuse.levonk.com` A record in Cloudflare via the `cloudflare-dns` role
  - Play 2: Deploys Langfuse containers to the OCI cloud server

Env template (Jinja2, templated by Ansible with vault secrets + infrastructure vars):
- `shared/active/03-container/services/ai-dashboard/langfuse/.env.langfuse.j2`

```bash
# Deploy to OCI (levonk)
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-langfuse.yml \
  --vault-password-file ~/.ansible/vault_password

# Dry run
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-langfuse.yml \
  --check --diff --vault-password-file ~/.ansible/vault_password
```

### Verification
```bash
# Check langfuse containers
docker ps | grep langfuse

# Langfuse web health
curl https://langfuse.levonk.com/api/public/health
# or locally:
curl http://localhost:3001/api/public/health

# View logs
docker logs langfuse-web --tail=50 -f
docker logs langfuse-worker --tail=50 -f
docker logs langfuse-postgres --tail=50 -f
docker logs langfuse-clickhouse --tail=50 -f
```

### Pipeline Integration
AI Dashboard Proxy 1 forwards trace data to Langfuse's ingestion API. The proxy sends trace events (requests, responses, generations) to `http://langfuse-web:3000/api/public/ingestion` using the Langfuse public API key for the target project. This is asynchronous and does not block the pipeline request path.

To wire a project: create an organization and project in the Langfuse UI, then configure AI Dashboard Proxy 1 with the project's public API key (stored in vault or pipeline env).

### References
- Project: https://github.com/langfuse/langfuse
- Self-hosting docs: https://langfuse.com/self-hosting/docker-compose
- Configuration guide: https://langfuse.com/self-hosting/configuration
- Ingestion API: https://langfuse.com/docs/tracing-data
- Deployment playbook: `shared/active/02-config/ansible/playbooks/deploy-langfuse.yml`
- Env template: `shared/active/03-container/services/ai-dashboard/langfuse/.env.langfuse.j2`
- Shared stack: `shared/active/03-container/services/ai-dashboard/langfuse/docker-compose.langfuse.yml`

## Domain Configuration and Traefik Routing

### Web Interface Access

The AI Dashboard web interface is accessible via Traefik with proper domain names and SSL certificates:

- **AI Dashboard**: https://ai-dashboard.levonk.com
  - Single web interface for both proxy collectors (entry and pre-egress)
  - Displays comparative analytics between pipeline stages
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **OmniRoute Dashboard**: https://ai-gateway.levonk.com
  - Provider management and configuration interface
  - Auto-fallback chain configuration
  - Usage analytics and provider performance metrics
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **Langfuse Observability**: https://langfuse.levonk.com
  - LLM tracing, analytics, and prompt management
  - Trace visualization and evaluation
  - Cost and token usage analytics
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

### Security Middleware Chain

Both web interfaces are protected by the same security middleware chain:
1. **GeoBlock** - Restricts access to specific countries (US only)
2. **CrowdSec Bouncer** - IP reputation filtering and threat protection
3. **Authelia** - Single sign-on authentication with 2FA

### DNS Configuration

DNS records are managed via Cloudflare:
- A records point to OCI cloud server IP (100.90.22.85)
- DNS-only mode (not full proxy) for better performance
- TTL: 300 seconds for quick propagation
- Managed via Ansible playbook: `configure-cloudflare-dns.yml`

## Deployment

### Local Development

For local development, ensure all dependent services are running:
- Privacy Orchestrator service (ai-privacy-proxy)
- Headroom service
- OmniRoute service
- Iron-Proxy service
- NordVPN service

### Cloud Deployment (OCI)

For deployment to the Levonk OCI cloud server, use the Ansible playbook:
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml --vault-password-file ~/.ansible/vault_password
```

## Network Configuration

### AI Dashboard Network
- **Name**: ai-dashboard-network
- **Type**: bridge
- **Subnet**: 172.28.0.0/16
- **Purpose**: Internal communication between collectors and database

### Proxy Chain Network
- **Name**: proxy-chain-network
- **Type**: bridge
- **Subnet**: 172.29.0.0/16
- **Gateway**: 172.29.0.1
- **Subnet**: 172.29.0.0/16
- **Purpose**: Communication with pipeline services (Headroom, OmniRoute, Iron-Proxy, NordVPN)

## Security Considerations

1. **PII Protection**: Privacy Orchestrator detects and transforms PII before data leaves the system
2. **Default-Deny**: Iron-Proxy enforces default-deny egress policy
3. **Secret Injection**: Credentials injected at boundary, not in workloads
4. **Audit Trail**: Complete request logging at multiple stages
5. **VPN Privacy**: All egress traffic routed through NordVPN
6. **Data Isolation**: Multi-tenant client isolation in database schema

## Compression Strategy

**Headroom-Primary Approach:**
- **Headroom** handles all compression (60-95% token savings)
- **OmniRoute** compression completely disabled to avoid redundancy
- **OmniRoute** focuses on intelligent provider routing
- **No fallback compression** in OmniRoute (Caveman also disabled)
- **Environment Variables**:
  - `COMPRESSION_STRATEGY=headroom-primary`
  - `OMNIROUTE_COMPRESSION_ENABLED=false`
  - `OMNIROUTE_RTK_ENABLED=false`
  - `OMNIROUTE_CAVEMAN_ENABLED=false`

**Benefits:**
- Eliminates all compression redundancy between Headroom and OmniRoute
- Optimizes OmniRoute's routing decisions (works with compressed content)
- Headroom's superior compression algorithms (60-95% vs 15-95%)
- Single compression point simplifies debugging and analytics
- Cleaner separation of concerns (compression vs routing)

## Privacy Orchestrator Implementation

### Current Status
**IMPLEMENTED** - The Privacy Orchestrator stage is fully implemented and deployed.

### Implementation Details

The Privacy Orchestrator is a Rust-based service that provides PII detection and transformation capabilities:

**Core Functionality:**
- HTTP server/proxy that intercepts AI requests
- PII detection using Candle ML framework
- Multiple transformation modes (redaction, masking, tokenization)
- Support for 22+ PII categories across multiple languages
- CLI and HTTP proxy interfaces
- Real-time analytics and monitoring

**Technical Stack:**
- Rust with Candle ML framework
- HTTP proxy interface (port 9090)
- Docker containerization
- Health check endpoints
- Configurable PII detection thresholds
- Comprehensive logging and metrics

**Repository:**
- Project: https://github.com/levonk/ai-privacy-proxy
- Documentation: See project README and internal docs

**Architecture:**
- Rust-based service (consistent with other pipeline services)
- Candle ML framework for PII detection
- HTTP proxy interface with request/response interception
- Configurable transformation modes and thresholds
- Analytics integration with AI Dashboard
- TUI interface for monitoring and management

### Benefits of Privacy Orchestrator Service

**Architectural:**
- Separation of concerns (privacy transformation vs analytics collection)
- Reusable across different pipelines/projects
- Independent testing and validation
- Follows microservices best practices

**Operational:**
- Can scale independently based on PII processing load
- Privacy transformation updates don't affect analytics collection
- Easier to monitor and debug PII detection issues
- Can be deployed/updated independently
- TUI interface for real-time monitoring

**Performance:**
- Leverages Candle ML framework for efficient inference
- Sub-millisecond PII detection latency
- Efficient memory usage
- CPU and GPU inference options

## Troubleshooting

### Pipeline Not Starting

1. Check if all dependent services are running:
   ```bash
   docker ps | grep -E "privacy-orchestrator|headroom|omniroute|iron-proxy|nordvpn"
   ```

2. Verify network connectivity:
   ```bash
   docker network inspect proxy-chain-network
   docker network inspect ai-dashboard-network
   ```

3. Check collector logs for errors:
   ```bash
   docker logs ai-dashboard-proxy-1
   docker logs ai-dashboard-proxy-2
   docker logs privacy-orchestrator
   ```

### Privacy Orchestrator Issues

#### Privacy Orchestrator Not Starting

1. Check container status:
   ```bash
   docker ps | grep privacy-orchestrator
   docker logs privacy-orchestrator --tail=50
   ```

2. Verify configuration file:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml
   ```

3. Check database connectivity:
   ```bash
   docker exec privacy-orchestrator env | grep DATABASE_URL
   docker exec ai-dashboard-db pg_isready -U postgres
   ```

4. Verify network configuration:
   ```bash
   docker inspect privacy-orchestrator | grep IPAddress
   docker network inspect proxy-chain-network
   ```

#### PII Detection Not Working

1. Check detection configuration:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml | grep -A 10 "\[detection\]"
   ```

2. Test detection endpoint:
   ```bash
   curl -X POST http://localhost:9090/detect \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com"}'
   ```

3. Check model availability:
   ```bash
   docker exec privacy-orchestrator ls -la /models/
   ```

4. Verify GPU/CPU configuration:
   ```bash
   docker exec privacy-orchestrator env | grep use_gpu
   docker exec privacy-orchestrator nvidia-smi  # if GPU enabled
   ```

#### Transformation Not Applied

1. Check transformation mode:
   ```bash
   docker exec privacy-orchestrator cat /config/config.toml | grep -A 5 "\[transformation\]"
   ```

2. Test transformation endpoint:
   ```bash
   curl -X POST http://localhost:9090/transform \
     -H "Content-Type: application/json" \
     -d '{"text": "My email is test@example.com", "mode": "redaction"}'
   ```

3. Verify upstream connection:
   ```bash
   docker exec privacy-orchestrator curl -f http://headroom:8787/health
   ```

#### High Latency Issues

1. Check resource usage:
   ```bash
   docker stats privacy-orchestrator --no-stream
   docker top privacy-orchestrator
   ```

2. Review performance metrics:
   ```bash
   curl http://localhost:9090/analytics
   ```

3. Check for bottlenecks:
   ```bash
   docker logs privacy-orchestrator | grep "latency"
   ```

4. Optimize configuration:
   - Reduce detection categories if not all needed
   - Enable GPU if available
   - Increase worker threads
   - Enable caching

### Database Connection Issues

1. Verify database is running:
   ```bash
   docker ps | grep ai-dashboard-db
   ```

2. Check database logs:
   ```bash
   docker logs ai-dashboard-db
   ```

3. Test database connection:
   ```bash
   docker exec ai-dashboard-db psql -U postgres -d analytics -c "SELECT 1"
   ```

### Analytics Not Being Collected

1. Verify collectors are in analytics mode:
   ```bash
   docker exec ai-dashboard-proxy-1 env | grep AI_ANALYTICS_PROXY_MODE
   docker exec ai-dashboard-proxy-2 env | grep AI_ANALYTICS_PROXY_MODE
   ```

2. Check upstream connectivity:
   ```bash
   docker exec ai-dashboard-proxy-1 curl -f http://headroom:8787/health
   docker exec ai-dashboard-proxy-2 curl -f http://omniroute:20128/health
   ```

3. Verify database connectivity:
   ```bash
   docker exec ai-dashboard-proxy-1 env | grep DATABASE_URL
   docker exec ai-dashboard-proxy-2 env | grep DATABASE_URL
   ```

## Performance Optimization

### Database Indexing
Ensure proper indexes on:
- client_id, ai_client, team_id
- pipeline_stage, timestamp
- model_supplier, model_name
- request_fingerprint (for correlation)

### Collector Performance
- Adjust log levels (INFO vs DEBUG)
- Configure batch size for database writes
- Tune connection pooling parameters

### Network Optimization
- Use dedicated networks for different traffic types
- Configure proper MTU for VPN traffic
- Monitor network latency between stages

## Monitoring

### Health Checks
All services include Docker health checks:
- Collectors: HTTP endpoint `/health`
- Database: `pg_isready` command
- Interval: 30s
- Timeout: 10s
- Retries: 3

### Metrics
Key metrics to monitor:
- Request throughput per stage
- Token compression ratios
- Provider selection distribution
- Error rates by stage
- End-to-end latency

### Alerts
Configure alerts for:
- Collector downtime
- Database connection failures
- High error rates
- Anomalous traffic patterns
- Cost overruns

## References

- **Omnigent (orchestrator / request origin)**: https://github.com/omnigent-ai/omnigent
- **Omnigent deploy docs**: https://omnigent.ai/docs/deploy/overview
- **Omnigent shared stack**: `shared/active/03-container/services/ai-codeassist/omnigent/`
- **Pi (coding harness / request origin)**: https://github.com/earendil-works/pi
- **Pi RPC docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **Pi shared stack**: `shared/active/03-container/services/ai-codeassist/pi/`
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2`
- **Omnigent + Pi levonk deployment**: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`
- **AI Dashboard Project**: https://github.com/levonk/ai-dashboard
- **AI Dashboard PRD**: `~/p/gh/levonk/ai-dashboard/docs/feature/prd-multi-tenant-ai-analytics.md`
- **Headroom**: Context compression service
- **OmniRoute**: AI gateway with 177+ providers
- **Iron-Proxy**: Egress firewall and secret injection
- **NordVPN**: Privacy and geo-obfuscation