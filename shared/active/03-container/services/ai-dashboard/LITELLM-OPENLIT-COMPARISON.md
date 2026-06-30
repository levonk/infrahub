# LiteLLM vs OpenLIT — Comparison Note

## TL;DR

**LiteLLM and OpenLIT are NOT competitors. They serve different layers and are complementary.**

- **LiteLLM** = AI **Gateway** (sits in the request path: auth, routing, keys, spend, guardrails, proxy)
- **OpenLIT** = AI **Observability Platform** (instrumentation layer: tracing, evaluation, prompt management, GPU monitoring)

OpenLIT explicitly supports LiteLLM as an integration target — it instruments LiteLLM proxy calls to capture performance and operation stats. They can run together: LiteLLM as the gateway, OpenLIT as the observability backend.

## At-a-Glance

| | LiteLLM | OpenLIT |
|---|---|---|
| **Category** | AI Gateway / LLM Proxy | AI Observability / Engineering Platform |
| **Sits in request path?** | Yes — all LLM traffic flows through it | No — SDK instrumentation sends telemetry async |
| **Primary job** | Route requests to providers, auth, spend tracking | Observe, evaluate, and manage AI applications |
| **OpenTelemetry-native?** | No (has Langfuse/OTel callbacks but not native) | Yes — core architecture is OTel-based |
| **Self-host?** | Yes (proxy + Postgres) | Yes (Next.js + ClickHouse + OTel Collector) |
| **SaaS option?** | Yes (litellm.ai) | No (self-hosted only) |
| **License** | MIT | Apache-2.0 |
| **Tech stack** | Python (FastAPI/uvicorn) | TypeScript (Next.js) + Python/TS/Go SDKs + Go GPU collector |
| **Database** | PostgreSQL (keys, spend, teams) | ClickHouse (traces, metrics) |
| **GitHub stars** | ~18k | ~2.6k |

## Feature Comparison

### What LiteLLM does that OpenLIT does NOT

| Feature | LiteLLM | OpenLIT |
|---|---|---|
| **Provider routing** | 100+ LLM providers, auto-router, fallbacks, load balancing | None — not a proxy |
| **Virtual keys** | Per-key/per-team/per-org API keys with spend limits | Vault stores API keys but doesn't issue virtual keys |
| **Spend tracking** | Real-time $ spend per key/user/team/org, budget enforcement | Cost estimation per request, but no budget enforcement or key-level tracking |
| **PII guardrail (Presidio)** | Built-in Presidio PII masking as pre-call guardrail | PII detection/redaction guardrail, but runs as SDK instrumentation, not gateway-level |
| **Protocol translation** | OpenAI <-> Anthropic <-> Custom format translation | None |
| **Admin dashboard for keys/teams** | Full key/team/org/budget management UI | No key management UI |
| **Per-provider $ budget limits** | Redis-backed spend tracking, skip providers over budget | None |
| **Health-check driven routing** | Proactively removes unhealthy deployments | None |

### What OpenLIT does that LiteLLM does NOT

| Feature | OpenLIT | LiteLLM |
|---|---|---|
| **OpenTelemetry-native tracing** | SDKs (Python/TS/Go) auto-instrument LLM calls, vector DBs, agent frameworks | Has OTel/Langfuse callbacks but not native OTel architecture |
| **LLM evaluations** | 11 built-in evaluation types (hallucination, bias, toxicity, coherence, faithfulness, etc.), LLM-as-a-judge | None |
| **Prompt management** | Prompt Hub with versioning (major/minor/patch), dynamic variables, AI prompt improvement | None |
| **GPU monitoring** | Go-based GPU collector (NVIDIA/AMD/Intel), utilization/memory/temp/power, eBPF CUDA tracing | None |
| **Zero-code observability** | eBPF-based Controller discovers LLM API calls without code changes | None — LiteLLM is always in-path |
| **Rule engine** | AND/OR conditional rules matching runtime trace attributes, dynamic context/prompt/eval retrieval | None |
| **Secrets vault** | AES-256-GCM encrypted API key storage, tag-based retrieval, team sharing | Stores keys in config/env but no vault concept |
| **LLM playground** | OpenGround — compare LLMs side-by-side (cost, duration, tokens) | None |
| **Fleet management** | OpAMP protocol for managing OpenTelemetry Collectors across infrastructure | None |
| **Agent framework tracing** | LangChain, LangGraph, CrewAI, LlamaIndex, AutoGen, Claude Agent SDK, OpenAI Agents, etc. | None — LiteLLM sees the request but not the agent's internal flow |
| **Vector DB observability** | ChromaDB, Pinecone, Qdrant, Milvus, Weaviate instrumentation | None |
| **60+ integrations** | LLM providers, agent frameworks, vector DBs, HTTP frameworks | 100+ LLM providers only |
| **Coding agent observability** | CLI installs vendor hooks for Claude Code, Cursor, Codex — traces sessions, tool calls, file edits | None |

### Overlapping features (both have, different approaches)

| Feature | LiteLLM approach | OpenLIT approach |
|---|---|---|
| **Cost tracking** | Gateway-level: real $ spend per key/team, budget enforcement, provider $ limits | Instrumentation-level: per-request cost estimation, custom model pricing, no enforcement |
| **PII guardrail** | Gateway-level: Presidio pre-call masking, blocks before request reaches provider | SDK-level: PII detection/redaction in application code, runs before/after LLM call |
| **Guardrails** | Presidio PII, LlamaGuard moderation, prompt injection detection, secret hiding — all gateway-level | Prompt injection, sensitive topics, topic restriction, PII, schema validation — all SDK-level |
| **Request logging** | Logs all requests/responses in DB, Langfuse integration | OTel-native traces with full request/response content (configurable) |
| **Dashboard** | Admin UI for spend/keys/teams/models | Analytics dashboard for metrics/costs/traces/exceptions |

## Architecture Comparison

### LiteLLM (Gateway — in-path)

```
Client → LiteLLM Proxy → [Auth → Guardrails → Routing → Provider] → Response
                ↓                                          ↓
           Postgres                                    Langfuse/OTel
           (keys, spend)                              (traces, logs)
```

- All LLM traffic MUST flow through LiteLLM
- Synchronous — adds latency (minimal, but in-path)
- Controls access (auth, keys, budgets)
- Translates protocols (OpenAI <-> Anthropic)

### OpenLIT (Observability — out-of-path)

```
Application → OpenLIT SDK → OTLP → OpenTelemetry Collector → ClickHouse
                                                    ↓
                                              OpenLIT Dashboard

OR (zero-code):

Application → eBPF Controller → discovers LLM calls → OTLP traces
```

- Telemetry flows async, does NOT sit in request path
- No latency added to LLM calls
- No access control — observes what's already happening
- SDK instruments application code (1 line: `openlit.init()`)

## How They Work Together

OpenLIT has explicit LiteLLM integration support. The recommended setup:

```
Application → OpenLIT SDK (instruments app) → LiteLLM (gateway) → Provider
                    ↓                                    ↓
              OpenLIT Dashboard                    OpenLIT Dashboard
              (app-level traces)                   (proxy-level traces)
```

- OpenLIT SDK instruments the application's LLM client calls (captures agent framework spans, tool calls, chain-of-thought)
- LiteLLM handles auth, routing, spend tracking, gateway-level guardrails
- OpenLIT also instruments LiteLLM itself (captures proxy performance, routing decisions, provider response times)
- Both send data to OpenLIT's ClickHouse via OTLP

**What you get:**
- Application-level: agent flow, tool calls, prompt chains, evaluations (OpenLIT SDK)
- Gateway-level: auth decisions, routing, spend, provider health (LiteLLM + OpenLIT LiteLLM integration)
- Infrastructure-level: GPU utilization, host metrics (OpenLIT GPU Collector)

## Relevance to the Levonk AI Pipeline

Current pipeline:
```
Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Forge → Iron-Proxy → NordVPN
```

**Where OpenLIT fits:**
- **SDK instrumentation**: Install OpenLIT SDK in Omnigent/Pi to trace agent flows, tool calls, and chain-of-thought before requests hit LiteLLM
- **LiteLLM integration**: OpenLIT instruments LiteLLM proxy to capture gateway-level metrics (routing decisions, provider response times, spend)
- **GPU monitoring**: If running local models (Ollama/vLLM), OpenLIT GPU Collector monitors GPU utilization
- **Evaluations**: Run LLM-as-a-judge evaluations on responses passing through the pipeline
- **Prompt management**: Centralize prompt versioning for Omnigent/Pi agents

**Where LiteLLM already covers it:**
- Auth, virtual keys, spend tracking — LiteLLM handles this at the gateway level
- PII guardrail — LiteLLM's Presidio integration handles this in-path
- Provider routing — LiteLLM routes to Headroom → OmniRoute

**OpenLIT vs Langfuse in the pipeline:**
The pipeline already has Langfuse deployed as the observability sink. OpenLIT and Langfuse overlap significantly:

| | Langfuse | OpenLIT |
|---|---|---|
| LLM tracing | Yes | Yes (OTel-native) |
| Prompt management | Yes (prompt management + versioning) | Yes (Prompt Hub) |
| Evaluations | Yes (score-based) | Yes (11 built-in types, LLM-as-a-judge) |
| Cost tracking | Yes | Yes |
| GPU monitoring | No | Yes |
| Agent framework tracing | Via integrations | Native SDK instrumentation |
| Zero-code observability | No | Yes (eBPF Controller) |
| OTel-native | No (custom SDK) | Yes |
| Self-host | Yes (Postgres + ClickHouse) | Yes (ClickHouse) |
| Coding agent hooks | No | Yes (Claude Code, Cursor, Codex) |

OpenLIT is a superset of Langfuse's observability features, plus GPU monitoring, zero-code eBPF, and coding agent hooks. However, Langfuse is already deployed and integrated with LiteLLM. Switching would mean replacing the observability backend.

## Verdict

| Question | Answer |
|---|---|
| Is OpenLIT a replacement for LiteLLM? | **No** — different layer. LiteLLM is a gateway (in-path), OpenLIT is observability (out-of-path). |
| Is LiteLLM a replacement for OpenLIT? | **No** — LiteLLM has no evaluations, prompt management, GPU monitoring, or agent framework tracing. |
| Can they run together? | **Yes** — OpenLIT instruments LiteLLM as an integration target. Recommended for full-stack observability. |
| Should OpenLIT replace Langfuse in the pipeline? | **Maybe** — OpenLIT is a superset of Langfuse (GPU monitoring, zero-code, coding agent hooks, OTel-native). But Langfuse is already deployed and working. Switching is a migration effort, not a drop-in replacement. |
| Should OpenLIT be added alongside Langfuse? | **No** — redundant. Pick one observability backend. If OpenLIT's GPU monitoring or coding agent hooks are valuable, migrate from Langfuse to OpenLIT. Otherwise, keep Langfuse. |

## References

- [OpenLIT GitHub](https://github.com/openlit/openlit)
- [OpenLIT Docs](https://docs.openlit.io/)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)
- [LiteLLM Docs](https://docs.litellm.ai/)
- [OpenLIT LiteLLM Integration](https://docs.openlit.io/latest/integrations/litellm)
- Local OpenLIT repo: `/Users/micro/p/gh/levonk/openlit`
- Pipeline notes: [[PIPELINE-LITELLM-JANUS-NOTES]]
- Pipeline config: [[PIPELINE]]
