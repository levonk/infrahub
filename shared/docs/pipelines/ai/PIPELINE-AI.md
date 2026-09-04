# AI Pipeline Configuration

## Architecture

The pipeline spans two tiers: a **development environment** (local machine or homelab dev container) where agents run, and a **remote server** (OCI cloud) where the LLM pipeline, tool registry, agent memory, and egress firewall live.

```mermaid
flowchart LR
    subgraph DevEnv["Development Environment (local/homelab container)"]
        VSC["VS Code\n(local editor)"]
        HERDR["herdr\nTerminal runtime\n(always-running)"]
        ACRYL["acryl\nPersistent dev env\n+ project context"]
        PI["Pi\nCoding harness\n(harness)"]
        PAXM["paxm\nLocal agent memory\n(SQLite)"]
        OMN["Omnigent\nOrchestrator\n(server, goals/work)"]

        VSC -- "remote-SSH" --> HERDR
        HERDR --> ACRYL
        ACRYL --> PI
        ACRYL --> PAXM
        OMN -- "RPC (JSONL)" --> PI
    end

    subgraph Origins["Request Origin Peers"]
        BUZZ["Buzz\n(Nostr relay)"]
        PAPER["Paperclip\n(agent orchestration)"]
    end

    subgraph Remote["Remote Server (OCI cloud)"]
        subgraph Memory["Agent Memory"]
            AMEM["agentmemory\nServer-side persistent memory\n(MCP, iii-engine, SQLite)"]
        end

        subgraph Tools["Tool Call Path"]
            TREG["treg\nTool registry + credential relay\n(OpenRouter for tools)"]
        end

        subgraph Pipeline["LLM Pipeline (Phase 1 MVP)"]
            LIT["LiteLLM — aigate\nEntry: auth, keys,\nPII masking (Presidio),\nspend, Langfuse traces"]
            HEAD["Headroom\nContext compression\n(RTK+Caveman)"]
            OR["OmniRoute — airoute\nProvider fanout\n4-tier fallback"]
            IP["Iron-Proxy\nEgress firewall\nMITM TLS inspection"]
        end

        subgraph Observability["Parallel Observability Sink"]
            LF["Langfuse\nweb → postgres +\nclickhouse + redis + minio"]
        end
    end

    subgraph Egress["Direct Egress"]
        NET(("Internet"))
    end

    PI -- "LLM requests\nOpenAI-compatible\nhttp://litellm:4000/v1" --> LIT
    PI -- "tool calls\n/call/{upstream_url}" --> TREG
    PI -. "memory read/write" .-> AMEM
    PAXM -. "memory sync" .-> AMEM
    BUZZ -. "events/requests" .-> LIT
    PAPER -. "agent tasks" .-> LIT
    LIT -- "forwards traces" -.-> LF
    LIT --> HEAD --> OR --> IP --> NET
    TREG -- "credential-injected\nrelay" --> IP --> NET
```

### Future Evolution (Deferred)

```mermaid
flowchart LR
    subgraph Future["Future Evolution — Deferred to Later Phases"]
        FORGE["Forge\nTool-call repair\n(Phase 2)"]
        NORD["NordVPN\nVPN tunnel\n(Phase 3)"]
        DASH["AI Dashboard Proxy 1/2 + DB\nAnalytics collectors\n(Phase 4)"]
        PRIV["Privacy Orchestrator\nStandalone PII service\n(Phase 5)"]
        TREGPHASE["treg Tool Registry\n(Phase 6 — tool call\nkey management)"]
    end
```

### Web Proxy Chain Relationship (Undecided)

Agent requests (LLM calls and treg tool calls) currently egress through Iron-Proxy directly to the Internet. The web proxy chain (MITM → Privoxy → Varnish → Gost → Direct/Tor) is a separate egress system for general LAN traffic. Two options are documented:

- **Option A (Iron-Proxy only)**: Agent traffic goes through Iron-Proxy directly to the Internet. The web proxy chain is for general LAN traffic only (browsers, IoT). Simpler, fewer hops, no cache/filter interference with API calls.
- **Option B (Chain through both)**: Agent traffic goes through Iron-Proxy, then through the web proxy chain (Gost egress) for Tor/anonymity routing. Adds filtering and caching but may interfere with API responses.

This is a topology decision, not a pipeline architecture decision. See `shared/docs/pipelines/web/complete-web-proxy-chain.md` for the web proxy chain details.

## Recent Changes

**2026-09-03**: Expanded pipeline to include development environment, agent memory, and tool call path
- Added **herdr** (https://github.com/herdrdev/herdr) as the terminal runtime in the dev container — always-running server for coding agents, survives laptop close/lid drop
- Added **acryl** (https://github.com/acryldev/acryl) as the persistent development environment and project context layer in the dev container
- Added **paxm** (https://github.com/pax-beehive/paxm) as local agent memory (SQLite) in the dev container — carries decisions and context across agent sessions
- Added **treg** (https://github.com/superdesigndev/treg) as the tool registry + credential relay on the remote server — "OpenRouter for tools", manages non-LLM tool API keys, injects credentials server-side
- Documented **agentmemory** (already deployed at `shared/active/03-container/services/agentmemory/`) as the server-side persistent memory layer (MCP, iii-engine, SQLite)
- Added **tool call path**: Pi → treg (credential relay) → Iron-Proxy → Internet, parallel to the LLM request path
- Added **agent memory path**: paxm (local, in dev container) + agentmemory (remote, on OCI) with sync between them
- Documented the **web proxy chain relationship** as undecided (two options documented)
- Added **Phase 6 (Future) — treg Tool Registry** to the pipeline evolution roadmap
- Architecture diagram updated to show dev environment → remote server topology
- Pipeline doc moved from `shared/docs/PIPELINE-AI.md` to `shared/docs/pipelines/ai/PIPELINE-AI.md` as part of pipeline doc consolidation

**2026-07-25**: Added Buzz as a request-origin peer to Paperclip and Omnigent+Pi
- Buzz (https://github.com/block/buzz) is a self-hostable Nostr relay workspace for human + AI agent collaboration
- Deployed as `ai-buzz` Ansible role + `deploy-buzz.yml` playbook on the OCI cloud server
- Domain: https://buzz.<base-domain> (Traefik + GeoBlock + CrowdSec + Authelia)
- Stack: buzz-relay + Postgres 17 + Redis 7 + MinIO; relay URL `wss://buzz.<base-domain>`
- Serves as a request-origin peer alongside Paperclip (agent orchestration) and Omnigent+Pi (agent execution)

**2026-07-23**: Simplified pipeline to MVP, deferred Forge/NordVPN/AI Dashboard/Privacy Orchestrator
- Active MVP pipeline: `Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet`
- LiteLLM's Presidio PII guardrail is the privacy layer (standalone Privacy Orchestrator deferred to Phase 5)
- LiteLLM → Langfuse is the observability source (AI Dashboard Proxy 1/2 + DB deferred to Phase 4)
- Forge (tool-call repair) deferred to Phase 2 — no Ansible role exists yet
- NordVPN (privacy egress) deferred to Phase 3 — Iron-Proxy egresses directly to Internet for now
- See "Pipeline Evolution Roadmap" section for the full phase plan

**2026-07-03**: Documented iron-proxy MITM TLS inspection and CA trust requirement
- Iron-proxy uses man-in-the-middle TLS to inspect HTTPS traffic for allowlist enforcement and per-request auditing
- Clients routing through iron-proxy MUST trust iron-proxy's CA certificate (mounted + `NODE_EXTRA_CA_CERTS` for Node.js)
- Added tunnel listener (port 8870) for CONNECT-based HTTPS proxying (Node.js fetch, curl --proxy)
- iron-proxy chains egress through NordVPN's HTTP proxy for privacy
- Verified end-to-end: Pi → iron-proxy (MITM + audit) → NordVPN → Cognition Cloud (Windsurf)
- See "Iron-Proxy (Egress Firewall — MITM TLS Inspection)" stage for details

**2026-06-29**: Added LiteLLM as the AI gateway entry point (aigate.<base-domain>)
- LiteLLM (https://github.com/BerriAI/litellm) is an OSS AI Gateway with auth, virtual keys, spend tracking, PII guardrail (Presidio), and native Langfuse logging
- Replaces AI Dashboard Proxy 1/2 (analytics collectors) and Privacy Orchestrator (PII detection) as the pipeline entry point
- LiteLLM sits BEFORE Headroom: PII guardrail runs on raw text (more reliable), spend tracking on original request size, auth/keys reject bad requests early
- Domain: aigate.<base-domain> (Traefik + GeoBlock + CrowdSec + Authelia)
- Ansible role: `roles/ai-litellm/`, deploy playbook: `playbooks/deploy-ai-gateway-pipeline.yml`
- **Status**: DEFINED - Ansible role created, vault secrets added, DNS configured

**2026-06-29**: Renamed OmniRoute domain from ai-gateway.<base-domain> to airoute.<base-domain>
- LiteLLM (aigate) is now the gateway entry point; OmniRoute (airoute) is the routing layer
- OmniRoute's unique strengths preserved: 4-tier subscription-draining fallback, 9-factor auto-combo scoring, free-tier maximization, 14 routing strategies
- See PIPELINE-LITELLM-JANUS-NOTES.md for the full LiteLLM vs OmniRoute comparison

**2026-06-28**: Added Langfuse as parallel LLM observability backend
- Langfuse (https://github.com/langfuse/langfuse) is an LLM tracing & observability platform
- Deployed as a parallel analytics sink receiving traces from AI Dashboard Proxy 1 (entry collector)
- NOT a serial forwarding stage — receives trace data alongside the pipeline's own analytics DB
- Stack: langfuse-web (UI + ingestion API) + langfuse-worker (async ingestion) + postgres + clickhouse + redis + minio
- Web UI at https://langfuse.<base-domain> (Traefik + GeoBlock + CrowdSec + Authelia)
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
- *(Note: As of 2026-07-23, Forge is DEFERRED to Phase 2 — see Pipeline Evolution Roadmap)*
- See "Forge Implementation" section for details

**2026-06-24**: Implemented Privacy Orchestrator stage in pipeline architecture
- New stage between AI Dashboard Proxy 1 and Forge
- Implements PII detection and transformation using Rust-based Privacy Orchestrator
- **Status**: IMPLEMENTED - ai-privacy-proxy service deployed
- *(Note: As of 2026-07-23, standalone Privacy Orchestrator is DEFERRED to Phase 5, superseded by LiteLLM Presidio for the MVP — see Pipeline Evolution Roadmap)*
- See "Privacy Orchestrator Implementation" section for details

## Overview

This configuration implements a multi-stage AI analytics pipeline with comprehensive data collection at key stages. The pipeline provides deep visibility into AI usage patterns, optimization effectiveness, and security analytics.

## Pipeline Evolution Roadmap

The pipeline is being delivered in phases. The current MVP is Phase 1; later phases add deferred capabilities without disrupting the active flow.

### Phase 1 (Current MVP)

```text
Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet
```

- **Privacy**: LiteLLM's Presidio PII guardrail masks PII on raw text before compression
- **Observability**: LiteLLM forwards traces to Langfuse (parallel sink)
- **Egress**: Iron-Proxy egresses directly to the Internet (no VPN chaining)

### Phase 2 (Future) — Forge

Add **Forge** (tool-call repair) between OmniRoute and Iron-Proxy. No Ansible role exists yet; this phase begins when tool-call reliability becomes a blocker with non-conforming backends.

### Phase 3 (Future) — NordVPN

Add **NordVPN** after Iron-Proxy for privacy/geo-obfuscation egress. Iron-Proxy will chain egress through NordVPN's HTTP proxy via `HTTP_PROXY`/`HTTPS_PROXY` env vars.

### Phase 4 (Future) — AI Dashboard Proxy 1/2 + DB

Revisit the **AI Dashboard Proxy 1/2 collectors + shared DB** for deeper per-stage analytics. LiteLLM + Langfuse cover observability for the MVP; the dashboard collectors are deferred until richer comparative analytics are needed.

### Phase 5 (Future) — Standalone Privacy Orchestrator

Revisit the standalone **Privacy Orchestrator** (ai-privacy-proxy) if LiteLLM's Presidio PII masking proves insufficient. The standalone service offers Candle ML-based detection across 22+ PII categories with multiple transformation modes.

### Phase 6 (Future) — treg Tool Registry

Add **treg** (https://github.com/superdesigndev/treg) behind Iron-Proxy for non-LLM tool call key management. treg is "OpenRouter for tools" — a tool registry and credential relay that manages tool API keys (Stripe, GitHub, SEO/enrichment APIs), team key-sharing, CLI credential injection, and skill/bundle registration. Iron-Proxy's allowlist expands to permit treg as an egress destination. treg manages tool keys; Iron-Proxy remains the egress firewall. LLM provider keys continue to flow through LiteLLM + OmniRoute.

**Architecture**: Iron-Proxy sits in front of treg. Iron-Proxy holds treg's `X-Treg-Token` (agent never sees it). treg holds all tool API keys and injects them server-side. Iron-Proxy's default-deny ensures the agent can only reach treg, not upstreams directly. This is CB4A Model A — two layers of credential brokering, each protecting the next.

**treg interfaces**: HTTP relay proxy (`/call/{upstream_url}`), MCP server (`/mcp/`), REST API (`/docs`), CLI (`treg call`, `treg run`, `treg shell`). The HTTP relay is the interface Iron-Proxy gates. The CLI/shell features (`treg run`, `treg shell`) run locally and cannot be gated by Iron-Proxy — agents must use only the HTTP relay interface for tool calls that go through the pipeline.

## Pipeline Architecture

The pipeline has three request paths from the development environment to the Internet, all converging on Iron-Proxy as the egress firewall:

```
LLM requests:    Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet
Tool calls:      Pi → treg (credential relay) → Iron-Proxy → Internet
Agent memory:    Pi → paxm (local SQLite) ← sync → agentmemory (remote MCP, iii-engine)
```

### LLM Request Path (Phase 1 MVP)

```
Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet
(server)   (harness)  (Entry)        (Compress)  (Routing)          (Security)   (Direct)
                      (auth, keys,
                       PII, spend,
                       Langfuse)
                      │
                      ↓ (forwards traces)
                Langfuse (LLM Observability — parallel analytics sink)
                langfuse-web → postgres + clickhouse + redis + minio
```

**Note**: LiteLLM is the entry point for the LLM pipeline. It handles auth, virtual keys, spend tracking, PII guardrail (Presidio masking), and forwards traces to Langfuse. LiteLLM routes to Headroom for context compression, then to OmniRoute for provider fanout (tier-based fallback, 9-factor auto-combo scoring, free-tier draining). Iron-Proxy enforces egress firewall policy and egresses directly to the Internet (NordVPN VPN chaining is deferred to Phase 3). Forge (tool-call repair) is deferred to Phase 2.

**Previous architecture** (pre-2026-06-29): AI Dashboard Proxy 1 → Privacy Orchestrator → Headroom → OmniRoute → Forge → AI Dashboard Proxy 2 → Iron-Proxy. The Proxy 1/2 collectors and Privacy Orchestrator are now absorbed into LiteLLM. See PIPELINE-LITELLM-JANUS-NOTES.md for the full analysis.

### Development Environment Architecture

The development environment is where coding agents run. It can be a local dev container on the developer's machine or a container on a homelab server. The key property is that agents are always running and survive laptop close/lid drop — this is the exe.dev "work continues when laptop closes" property, achieved locally via herdr.

```
LOCAL MACHINE
  └─ VS Code (local editor)
       └─ remote-SSH into →
            DEV CONTAINER (local machine or homelab)
              ├─ VS Code Server (remote development)
              ├─ herdr (terminal runtime — agents always running)
              │    └─ acryl (persistent dev environment + project context)
              │         ├─ pi (coding harness — makes LLM + tool requests)
              │         └─ paxm (local agent memory — SQLite)
              │
              ├─ Omnigent runner (orchestrates goals/work, drives pi via RPC)
              │
              └─ → all requests route to REMOTE SERVER (OCI cloud)
```

**Components:**

- **herdr** (https://github.com/herdrdev/herdr) — "the runtime your coding agents live on". A background server (one Rust binary, no Electron) that manages terminal panes for coding agents. Always running: close the lid, drop the network, or restart the machine; agents keep working and sessions come back. Reattach from any terminal or SSH. Agent-native: agents drive herdr through the CLI and socket API to spawn panes, prompt each other, and wait until another agent is genuinely blocked. Runs Claude Code, Codex, Cursor, OpenCode, Pi, and others — herdr doesn't wrap or replace them; it owns their terminals. 35.3k stars, Apache-2.0.

- **acryl** (https://github.com/acryldev/acryl) — "Agent Context Relay Yielding Lifecycles". One persistent development environment, one persistent project context, any coding agent. Agents may come and go; the work continues. Has desktop GUI, terminal CLI, TUI, and web surfaces. Includes acryl-control, acryl-desktop, acryl-development-canvas, acryl-harness-runtime. MIT license, early development (237 stars).

- **pi** (https://github.com/earendil-works/pi) — the minimal terminal coding harness. The agent that actually does the coding work (read, write, edit, bash tools). Runs in RPC mode (JSONL over stdin/stdout). Pi's LLM requests route to LiteLLM on the remote server; pi's tool calls route to treg on the remote server.

- **paxm** (https://github.com/pax-beehive/paxm) — local agent memory. Carries decisions, conventions, and working context into later agent sessions. Works with Codex, Claude Code, OpenCode, Pi, Cursor, Cline, and MCP clients. Starts with local SQLite — no API key, embeddings, or extra memory-layer model calls needed. Memory providers can be swapped later (Zep, Mem0, MemOS, OpenViking, JSON-RPC) without rewiring every agent. Go binary, Apache-2.0, 421 stars.

- **Omnigent** (https://omnigent.ai/docs/deploy/overview) — the AI agent framework & meta-harness that orchestrates coding agents from a central server. Coexists with herdr: herdr manages terminals, Omnigent orchestrates goals and tracks work. Omnigent's runner drives pi via RPC mode.

### Agent Memory Architecture

Agent memory is split into two layers — local (in the dev container) and remote (on the OCI server) — that sync with each other:

```
DEV CONTAINER                          REMOTE SERVER (OCI)
  paxm (local)                         agentmemory (remote)
  ├── SQLite storage                   ├── iii-engine (WebSocket daemon)
  ├── Per-session context carry        ├── HTTP API + MCP server (port 3111)
  ├── Decisions, conventions           ├── SQLite storage (/data/state_store.db)
  └── Works offline                    ├── 53 MCP tools, 126 REST endpoints
                                       └── HMAC bearer token auth
         ↓ memory sync ↓                    ↑ memory sync ↑
         └─────────── Tailscale ────────────┘
```

**paxm** (local, in dev container):
- Carries context into agent sessions before they start (active memory)
- Passively captures completed turns (passive memory via hooks)
- SQLite storage, no external dependencies
- Works with Codex, Claude Code, OpenCode, Pi, Cursor, Cline, MCP clients
- Provider-swappable: Zep, Mem0, MemOS, OpenViking, JSON-RPC

**agentmemory** (remote, on OCI — already deployed):
- Persistent memory server shared across all agents and sessions
- Built on iii-engine (WebSocket daemon, port 49134 internal)
- HTTP API + MCP server on port 3111 (53 MCP tools, 126 REST endpoints)
- SQLite storage at `/data/state_store.db`
- HMAC bearer token auth (`AGENTMEMORY_SECRET`)
- Web viewer at `agentmemory.<base-domain>` (Traefik + Authelia)
- MCP API via Tailscale direct access
- Ansible role: `shared/active/02-config/ansible/roles/agentmemory/`
- Service: `shared/active/03-container/services/agentmemory/`

**Sync between paxm and agentmemory**: paxm captures context locally in the dev container; agentmemory stores it persistently on the remote server. The sync path runs over Tailscale. This gives agents local-fast memory access with remote-persistent backup and cross-session/cross-agent sharing.

### Tool Call Path (treg — Phase 6)

When agents need to call non-LLM APIs (Stripe, GitHub, SEO tools, enrichment APIs), those requests go through treg, not through the LLM pipeline. treg is "OpenRouter for tools" — a tool registry and credential relay that manages tool API keys and injects them server-side so the agent never holds the real key.

```
Pi → treg /call/{upstream_url} → Iron-Proxy → Internet (real upstream API)
     (agent sends X-Treg-Token)    (iron-proxy injects   (treg already injected
                                   treg's real token)     the tool API key)
```

**Architecture (layered credential brokering):**
- Iron-Proxy sits in front of treg. Iron-Proxy's allowlist permits only treg as the egress destination for tool calls.
- Iron-Proxy holds treg's `X-Treg-Token` (the agent never sees it).
- treg holds all tool API keys and injects them server-side at the relay point.
- Iron-Proxy's default-deny ensures the agent cannot bypass treg and call upstreams directly.
- This is CB4A Model A — two layers of credential brokering, each protecting the next.

**treg interfaces:**
- **HTTP relay proxy** (`/call/{upstream_url}`) — the primary interface. Agent builds the real upstream request and prefixes it with treg's base URL. treg resolves the tool by host, injects the credential, and streams the response back faithfully (no body buffering). This is the interface Iron-Proxy gates.
- **MCP server** (`/mcp/`) — exposes catalog endpoints, team-owned tools, and imported skills as MCP tools. Curated `/mcp/v2/` surface for Claude Connectors Directory.
- **REST API** (`/docs`) — everything the CLI does is plain HTTP. OpenAPI docs at `/docs`.
- **CLI** (`treg call`, `treg run`, `treg shell`) — runs locally on the agent's machine. `treg run` executes vendor CLIs with credentials injected. `treg shell` opens a subshell where every registered CLI auto-injects. These cannot be gated by Iron-Proxy — agents must use only the HTTP relay interface for tool calls that go through the pipeline.

**What treg manages that LiteLLM/OmniRoute do not:**
- 2,896 catalogued tool endpoints across 60 providers (SEO, backlinks, social, people enrichment, ads, scraping) — priced per call
- Team key-sharing with org RBAC (owner/admin/member/viewer)
- CLI credential injection (`treg run stripe -- get /v1/balance`)
- Skill/bundle registration (`SKILL.md` + secrets + tools registered together)
- OAuth connect flows with auto-refresh

**What treg does NOT do (Iron-Proxy's role):**
- Default-deny egress (treg is opt-in, not a firewall)
- DNS-rebinding / SSRF protection
- MITM TLS inspection
- Prevent agent bypass (treg cannot stop an agent from calling upstreams directly — Iron-Proxy does that)

**treg vs iron-proxy**: iron-proxy is the egress firewall (security). treg is the tool registry (productivity). They are complementary: iron-proxy as the egress firewall ensures nothing bypasses the proxy layer; treg as the tool registry manages which tools are available and injects their credentials. See the 2ndbrain note "Local Self-Hosted exe.dev From Devbox and Justfile.md" for the full feature matrix comparing treg, iron-proxy, Conduct, agentgateway, Infisical agent-vault, and keys-on-the-wire.

**Status**: DEFERRED — Phase 6. No Ansible role exists yet. treg is documented as a future evolution. For the MVP, agents that need tool calls must use credentials directly (or through Iron-Proxy's secret injection).

### Request Origin

The pipeline originates from one of several **request-origin services** that orchestrate or collaborate with agents before sending LLM requests to the pipeline entry point.

- **herdr + acryl + Pi** is the primary agent execution stack in the development environment. herdr (https://github.com/herdrdev/herdr) is the always-running terminal runtime. acryl (https://github.com/acryldev/acryl) provides persistent development environment and project context. Pi (https://github.com/earendil-works/pi) is the minimal terminal coding harness — the agent that actually does the coding work (read, write, edit, bash tools). Omnigent (https://omnigent.ai/docs/deploy/overview) coexists as the orchestrator that assigns goals and tracks work, driving pi via RPC.
- **Buzz** is a self-hostable Nostr relay workspace where humans and AI agents share rooms. It is a peer to Paperclip and Omnigent+Pi: events and requests originating from Buzz can be forwarded to the AI pipeline.
- **Paperclip** is an agent orchestration platform (assign goals, track work/costs, agent employee management). It is a peer to Buzz and Omnigent+Pi in the request-origin layer.

Omnigent's runner drives pi via **RPC mode** (JSONL over stdin/stdout). Pi's LLM requests are routed to the pipeline entry at **LiteLLM (aigate)** via a custom "pipeline" provider in pi's `models.json` config. The pipeline entry speaks OpenAI-compatible API, so pi treats it as an OpenAI provider with a custom base URL (`http://litellm:4000/v1`). LiteLLM then handles auth, PII masking, spend tracking, and Langfuse logging before forwarding to Headroom for compression and OmniRoute for provider fanout.

Pi's tool calls (non-LLM API calls) route to **treg** via the HTTP relay interface (`/call/{upstream_url}`). treg injects the tool API key server-side and relays through Iron-Proxy to the Internet.

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
   - **Domain**: aigate.<base-domain>
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
   - **Domain**: airoute.<base-domain>
   - **Port**: 20128
   - **Upstream from**: Headroom
   - **Downstream to**: Iron-Proxy (Forge chaining deferred to Phase 2)

4. **Forge (Tool Calling Reliability Layer)** — **DEFERRED — Future Evolution (Phase 2)**
   - Fixes tool calling issues in AI requests
   - Python-based service with guardrails for LLM tool calling
   - Response validation, rescue parsing, retry loop with error tracking
   - Synthetic `respond` tool injection for better model behavior
   - **Implementation**: forge service (https://github.com/antoinezambelli/forge)
   - **Port**: 8081
   - **Upstream from**: OmniRoute
   - **Downstream to**: Iron-Proxy
   - **Status**: **DEFERRED** — No Ansible role exists yet. Planned for Phase 2 between OmniRoute and Iron-Proxy. See "Pipeline Evolution Roadmap" and "Forge Implementation" section for details.

5. **Iron-Proxy (Egress Firewall — MITM TLS Inspection)**
   - Default-deny egress filtering with domain allowlist
   - **MITM TLS termination**: iron-proxy intercepts HTTPS by generating
     on-the-fly leaf certificates signed by its own CA. This is required
     because allowlist enforcement and per-request auditing happen at the
     HTTP layer (host, path, method) — without MITM, HTTPS traffic is
     opaque and iron-proxy can only filter by SNI (which is forgeable and
     insufficient for path-level rules).
   - **Client CA trust requirement**: every client routing through
     iron-proxy MUST trust iron-proxy's CA certificate. Without this, the
     client rejects the MITM'd leaf cert and the connection fails with a
     TLS error. For Node.js clients (pi, pi-windsurf plugin), this means:
       - Mount `ca.crt` into the container (e.g. `/etc/ssl/certs/iron-proxy-ca.crt`)
       - Set `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/iron-proxy-ca.crt`
       - Set `HTTP_PROXY`/`HTTPS_PROXY` to iron-proxy's listener
       - Set `NODE_OPTIONS=--use-env-proxy` so `fetch()` honors the proxy env vars
   - **Tunnel listener** (port 8870): accepts `CONNECT` requests for
     HTTPS proxying (used by clients that send CONNECT, e.g. Node.js
     `fetch()` with `HTTPS_PROXY`, `curl --proxy`). The tunnel listener
     performs MITM on the tunneled traffic.
   - **Upstream proxy chaining**: NordVPN chaining is DEFERRED to Phase 3.
     For the MVP, iron-proxy egresses directly to the Internet.
   - Secret injection at boundary
   - Per-request audit trail (host, SNI, method, path, status, duration)
   - **Ports**: 8080 (HTTP listener), 8870 (tunnel/CONNECT listener)
   - **Chain IP**: 172.29.0.17
   - **Upstream from**: OmniRoute (pipeline) or Pi (direct, bypassing pipeline)
   - **Downstream to**: Internet (direct; NordVPN chaining deferred to Phase 3)

6. **NordVPN (Privacy Layer)** — **DEFERRED — Future Evolution (Phase 3)**
   - VPN tunnel for privacy and geo-obfuscation
   - Routes all egress traffic through VPN
   - **Port**: 1080
   - **Upstream from**: Iron-Proxy
   - **Downstream to**: Internet
   - **Status**: **DEFERRED** — Iron-Proxy egresses directly to the Internet for the MVP. NordVPN chaining is planned for Phase 3. See "Pipeline Evolution Roadmap" for details.

## Analytics Dimensions

**Note**: The analytics dimensions below describe the full planned pipeline. For the Phase 1 MVP, analytics come from LiteLLM (entry stage) and Langfuse (observability sink). The AI Dashboard Proxy 1/2 collectors (Phase 4) will add deeper per-stage analytics when deployed.

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

*Phase 1 MVP: These metrics are collected by LiteLLM. The AI Dashboard Proxy 1 collector is deferred to Phase 4.*

- Original request size and token count
- Client identification and authentication
- Request timing and latency
- Input type classification

### Forge Analytics

*Deferred to Phase 2 (Forge).*

- Tool calling validation rates and categories
- Rescue parsing effectiveness (JSON code fences, Mistral `[TOOL_CALLS]`, Qwen XML)
- Retry loop statistics and success rates
- Processing latency (sub-millisecond expected)
- Synthetic `respond` tool usage patterns
- Backend compatibility metrics (llama-server, Ollama, vLLM, Anthropic)

### Privacy Orchestrator Analytics

*Deferred to Phase 5. For the MVP, PII metrics come from LiteLLM's Presidio guardrail.*

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

*Deferred to Phase 4 (AI Dashboard Proxy 2). For the MVP, pre-egress metrics come from Iron-Proxy audit logs.*

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
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Start with Environment File

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

### View Logs

```bash
# LiteLLM (entry stage — Phase 1 MVP)
docker logs litellm --tail=50 -f

# Langfuse (observability sink — Phase 1 MVP)
docker logs langfuse-web --tail=50 -f

# Entry stage collector (Phase 4 — deferred)
docker logs ai-dashboard-proxy-1 --tail=50 -f

# Privacy Orchestrator (Phase 5 — deferred)
docker logs privacy-orchestrator --tail=50 -f

# Forge (Phase 2 — deferred)
docker logs forge --tail=50 -f

# Pre-egress stage collector (Phase 4 — deferred)
docker logs ai-dashboard-proxy-2 --tail=50 -f

# Database (Phase 4 — deferred)
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

- **AI Dashboard Web Interface**: https://ai-dashboard.<base-domain> (single interface for both proxy collectors)
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
Pi's LLM requests (chat completions, messages) are routed to the pipeline entry at **LiteLLM (aigate)** via a custom "pipeline" provider in pi's `models.json` config. The pipeline entry speaks OpenAI-compatible API, so pi treats it as an OpenAI provider with a custom base URL (`http://litellm:4000/v1`). The pipeline then handles auth, PII masking (Presidio), spend tracking, Langfuse logging, compresses context (Headroom), routes across providers (OmniRoute), enforces egress firewall policy (Iron-Proxy), and egresses to the Internet — all transparent to the pi agent.

### Configuration
**Omnigent:**
- **Server image**: `ghcr.io/omnigent-ai/omnigent-server:latest` (pin `OMNIGENT_IMAGE_TAG` for reproducible deploys)
- **Server port**: 8000 (container), 8000 (host) — `infra_port_ai_omnigent_host`
- **Postgres port**: 5432 (container), 5433 (host, avoids clashing with ai-dashboard postgres) — `infra_port_ai_omnigent_postgres_host`
- **Domain**: `aiif.<base-domain>` (public alias "AI InterFace") — `infra_domain_ai_omnigent`
- **Auth**: multi-user with built-in accounts by default (`OMNIGENT_AUTH_ENABLED=1`); OIDC supported via `OMNIGENT_OIDC_*` vars
- **Secrets**: `OMNIGENT_DB_PASSWORD`, `OMNIGENT_ACCOUNTS_COOKIE_SECRET`, `OMNIGENT_ACCOUNTS_INIT_ADMIN_PASSWORD` sourced from the client Ansible vault

**Pi:**
- **Image**: `localnet-pi:latest` (built from `Dockerfile`, installs `@earendil-works/pi-coding-agent` from npm)
- **RPC bridge port**: 8090 (container), 8090 (host) — `infra_port_ai_pi_host`
- **LLM endpoint**: `http://litellm:4000/v1` (pipeline entry, via custom "pipeline" provider in `models.json`)
- **Default model**: `claude-sonnet-4-20250514` (routed through the pipeline to OmniRoute → real provider)
- **Session storage**: `/data/sessions` (named volume `localnet-pi-sessions-volume`)
- **Workspace**: `/workspace` (code repos mounted by client overlay)
- **Secrets**: `PI_API_KEY` sourced from the client Ansible vault (passed through to pipeline; pipeline handles real provider auth via Iron-Proxy)

### Container Configuration
The Omnigent + Pi stack is deployed as Docker containers with security hardening:
- **Omnigent**: Pre-built slim Python container from GHCR (FastAPI/WebSocket coordinator) + PostgreSQL 16 Alpine
- **Pi**: Node.js 22 slim container with `@earendil-works/pi-coding-agent` installed, running `rpc-bridge.py` (HTTP-to-stdin bridge for pi RPC mode)
- **Networks**: `omnigent-network` (172.36.0.0/16) for Omnigent↔Pi↔Postgres; `ai-dashboard-network` (172.35.0.0/16) for Pi→LiteLLM; `traefik-network` (external) for public routing
- **Volumes**: `omnigent-postgres-data`, `omnigent-artifact-data`, `pi-data`, `pi-sessions`
- **Traefik**: Public access via `aiif.<base-domain>` with GeoBlock → CrowdSec Bouncer → Authelia security middleware chain
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
omni login https://aiif.<base-domain>
omni host https://aiif.<base-domain>
```

### Verification
```bash
# Check omnigent + pi containers
docker ps | grep -E "omnigent|pi"

# Omnigent server health
curl https://aiif.<base-domain>/api/health
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

**Status**: DEFERRED — No Ansible role exists yet. Planned for Phase 2 between OmniRoute and Iron-Proxy. The implementation details below are preserved for planning.

### Overview
Forge is a reliability layer for self-hosted LLM tool-calling that sits between OmniRoute and Iron-Proxy in the AI analytics pipeline. It applies guardrails to LLM tool calls to improve reliability and correctness.

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
Langfuse is an open-source LLM engineering platform that provides tracing, analytics, prompt management, and evaluation for LLM applications. It is deployed as a **parallel analytics sink** that receives traces from LiteLLM (the entry stage for the Phase 1 MVP), giving deep visibility into LLM request/response lifecycle, token usage, costs, and quality — without adding latency to the pipeline's request path.

**Note**: For the Phase 1 MVP, LiteLLM forwards traces to Langfuse via its native Langfuse integration. AI Dashboard Proxy 1 as a trace forwarder is deferred to Phase 4 (future).

- **Project**: https://github.com/langfuse/langfuse
- **Self-hosting docs**: https://langfuse.com/self-hosting/docker-compose

### Architecture
Langfuse is NOT a serial forwarding stage. It runs alongside the pipeline as an observability backend:

```
LiteLLM ──┬──→ (pipeline continues: Headroom → OmniRoute → Iron-Proxy → Internet)
          └──→ (forwards traces) → langfuse-web ingestion API
```

The ingestion API (`/api/public/ingestion`) accepts OpenTelemetry-style trace data. LiteLLM forwards trace events (request, response, generation, span) to Langfuse asynchronously via its native Langfuse integration. Langfuse stores metadata in PostgreSQL, event data in ClickHouse, blobs (media) in MinIO, and uses Redis (BullMQ) for async ingestion processing via the worker.

*(Phase 4 future: AI Dashboard Proxy 1 will forward trace events to Langfuse when deployed.)*

### Stack Components
- **langfuse-web** — Next.js web UI + ingestion API (port 3000 container, 3001 host). Exposed via Traefik at `langfuse.<base-domain>` with GeoBlock → CrowdSec → Authelia security chain.
- **langfuse-worker** — Async ingestion processor consuming from Redis queue, writing to ClickHouse + MinIO (port 3030 container).
- **langfuse-postgres** — Metadata store (orgs, projects, users, prompts, evaluations). PostgreSQL 17 Alpine (port 5432 container, 5434 host).
- **langfuse-clickhouse** — Columnar store for high-volume trace/event data (HTTP 8123, TCP 9000 container).
- **langfuse-redis** — BullMQ queue for async ingestion (port 6379 container, internal only).
- **langfuse-minio** — S3-compatible blob storage for media uploads and batch exports (API 9000 container, 9190 host; console 9001 container).

### Configuration
- **Network**: `langfuse-network` (172.37.0.0/16) for internal service communication
- **Cross-network**: langfuse-web also joins `ai-dashboard-network` (172.35.0.0/16) so LiteLLM can reach the ingestion API at `http://langfuse-web:3000`, and `traefik-network` (172.31.0.0/16) for public routing
- **Domain**: `langfuse.<base-domain>` — `infra_domain_ai_langfuse`
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
  - Play 1: Configures `langfuse.<base-domain>` A record in Cloudflare via the `cloudflare-dns` role
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
curl https://langfuse.<base-domain>/api/public/health
# or locally:
curl http://localhost:3001/api/public/health

# View logs
docker logs langfuse-web --tail=50 -f
docker logs langfuse-worker --tail=50 -f
docker logs langfuse-postgres --tail=50 -f
docker logs langfuse-clickhouse --tail=50 -f
```

### Pipeline Integration
LiteLLM forwards trace data to Langfuse's ingestion API via its native Langfuse integration. LiteLLM sends trace events (requests, responses, generations) to `http://langfuse-web:3000/api/public/ingestion` using the Langfuse public API key for the target project. This is asynchronous and does not block the pipeline request path.

To wire a project: create an organization and project in the Langfuse UI, then configure LiteLLM with the project's public API key (stored in vault or pipeline env).

*(Phase 4 future: AI Dashboard Proxy 1 will forward trace data to Langfuse when deployed.)*

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

- **AI Dashboard**: https://ai-dashboard.<base-domain> *(Phase 4 — deferred)*
  - Single web interface for both proxy collectors (entry and pre-egress)
  - Displays comparative analytics between pipeline stages
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **OmniRoute Dashboard**: https://ai-gateway.<base-domain> *(deprecated — renamed to airoute.<base-domain>)*
  - Provider management and configuration interface
  - Auto-fallback chain configuration
  - Usage analytics and provider performance metrics
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **LiteLLM Admin (aigate)**: https://aigate.<base-domain> *(active — Phase 1 MVP)*
  - LiteLLM admin dashboard for spend, keys, teams, models
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **OmniRoute (airoute)**: https://airoute.<base-domain> *(active — Phase 1 MVP)*
  - OmniRoute provider management and configuration interface
  - Authenticated via Authelia with security middleware chain
  - SSL certificates managed by Let's Encrypt via Traefik

- **Langfuse Observability**: https://langfuse.<base-domain> *(active — Phase 1 MVP)*
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

The primary deployment playbook for the Phase 1 MVP is `deploy-ai-gateway-pipeline.yml`:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
```

The legacy `deploy-ai-dashboard-pipeline.yml` playbook is deprecated and retained only for Iron-Proxy deployment:

```bash
cd ~/p/gh/levonk/infrahub
devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml \
  --vault-password-file ~/.ansible/vault_password
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

1. **PII Protection**: LiteLLM's Presidio PII guardrail masks PII on raw text before compression (standalone Privacy Orchestrator deferred to Phase 5)
2. **Default-Deny**: Iron-Proxy enforces default-deny egress policy
3. **Secret Injection**: Credentials injected at boundary, not in workloads
4. **Audit Trail**: Complete request logging at multiple stages
5. **VPN Privacy**: NordVPN egress routing *(deferred to Phase 3 — Iron-Proxy egresses directly to the Internet for the MVP)*
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
**DEFERRED** — Future Evolution (Phase 5). Superseded by LiteLLM's Presidio PII guardrail for the MVP. The implementation details below are preserved for planning.

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

**Note**: Troubleshooting for AI Dashboard Proxy 1/2 and Privacy Orchestrator is deferred to their respective phases (Phase 4, Phase 5). For the MVP, troubleshoot LiteLLM, Headroom, OmniRoute, and Iron-Proxy.

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

   *(Phase 4/Phase 5 — deferred: proxy-1/proxy-2 and privacy-orchestrator logs are not available in the MVP.)*

### Privacy Orchestrator Issues

*DEFERRED (Phase 5) — The standalone Privacy Orchestrator is not deployed in the MVP. For PII issues, troubleshoot LiteLLM's Presidio guardrail.*

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

*(Phase 4 — deferred: proxy-1/proxy-2 collectors are not deployed in the MVP. For the MVP, analytics come from LiteLLM and Langfuse.)*

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

### Development Environment Components
- **herdr (terminal runtime)**: https://github.com/herdrdev/herdr
- **herdr docs**: https://herdr.dev/docs
- **acryl (persistent dev environment)**: https://github.com/acryldev/acryl
- **acryl docs**: https://acryl.dev
- **paxm (local agent memory)**: https://github.com/pax-beehive/paxm
- **paxm docs**: https://github.com/pax-beehive/paxm#docs

### Agent Memory
- **agentmemory (server-side memory — already deployed)**: https://github.com/rohitg00/agentmemory
- **agentmemory service**: `shared/active/03-container/services/agentmemory/`
- **agentmemory Ansible role**: `shared/active/02-config/ansible/roles/agentmemory/`
- **agentmemory SQLite vs Postgres decision**: `shared/active/03-container/services/agentmemory/docs/why-sqlite-not-postgres.md`

### Tool Call Path
- **treg (tool registry + credential relay — Phase 6)**: https://github.com/superdesigndev/treg
- **treg docs**: https://treg.to
- **treg llms.txt** (agent onboarding): https://treg.to/llms.txt
- **CB4A feature matrix** (treg vs iron-proxy vs Conduct vs agentgateway vs Infisical vs keys-on-the-wire): `~/p/gh/lrepo52/2ndbrain/2ndbrain/Default/Processes/Technology/Artificial Intelligence/Agents/Local Self-Hosted exe.dev From Devbox and Justfile.md`

### Request Origins
- **Omnigent (orchestrator / request origin)**: https://github.com/omnigent-ai/omnigent
- **Omnigent deploy docs**: https://omnigent.ai/docs/deploy/overview
- **Omnigent shared stack**: `shared/active/03-container/services/ai-codeassist/omnigent/`
- **Pi (coding harness / request origin)**: https://github.com/earendil-works/pi
- **Pi RPC docs**: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md
- **Pi shared stack**: `shared/active/03-container/services/ai-codeassist/pi/`
- **Deployment playbook**: `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml`
- **Env template**: `shared/active/03-container/services/ai-codeassist/omnigent/.env.omnigent.j2`
- **Omnigent + Pi levonk deployment**: `levonk/active/03-container/services/omnigent/DEPLOYMENT.md`
- **Buzz (Nostr relay workspace)**: https://github.com/block/buzz
- **Paperclip (agent orchestration)**: (see existing deployment docs)

### LLM Pipeline Stages
- **LiteLLM (AI Gateway — entry stage, Phase 1 MVP)**: https://github.com/BerriAI/litellm
- **Langfuse (LLM observability — Phase 1 MVP)**: https://github.com/langfuse/langfuse
- **AI Dashboard Project** *(deferred — Phase 4)*: https://github.com/levonk/ai-dashboard
- **AI Dashboard PRD** *(deferred — Phase 4)*: `~/p/gh/levonk/ai-dashboard/docs/feature/prd-multi-tenant-ai-analytics.md`
- **Headroom**: Context compression service
- **OmniRoute**: AI gateway with 177+ providers
- **Iron-Proxy**: Egress firewall and secret injection
- **NordVPN** *(deferred — Phase 3)*: Privacy and geo-obfuscation
- **Forge** *(deferred — Phase 2)*: Tool-call repair reliability layer
- **Privacy Orchestrator** *(deferred — Phase 5)*: Standalone PII detection/transformation service

### Related Pipeline Docs
- **Web proxy chain**: `shared/docs/pipelines/web/complete-web-proxy-chain.md`
- **DNS chain**: `shared/docs/pipelines/dns/complete-dns-chain.md`
- **NTP chain**: `shared/docs/pipelines/ntp/ntp-chain.md`
- **Overall architecture**: `shared/docs/pipelines/overall-architecture.md`
- **Pipeline docs index**: `shared/docs/pipelines/README.md`