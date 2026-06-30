---
title: Pipeline LiteLLM Overlap and Janus-Hub Strategy
tags:
  - ai-dashboard
  - pipeline
  - litellm
  - janus-hub
  - architecture
  - strategy
  - redundancy-analysis
aliases:
  - LiteLLM Overlap Notes
  - Janus-Hub Absorption Plan
date: 2026-06-29
---

# Pipeline LiteLLM Overlap and Janus-Hub Strategy

Companion notes to [[PIPELINE]]. Documents the overlap between the current analytics pipeline stages and [LiteLLM](https://github.com/BerriAI/litellm), and the strategic direction for [[Janus-Hub]] to absorb the redundant stages via plugins.

## Context

Analysis run on 2026-06-29 comparing the pipeline defined in [[PIPELINE]] against LiteLLM's OSS feature set, with the goal of identifying which stages are made redundant by adopting LiteLLM and which remain unique. The strategic conclusion is that Janus-Hub is intended to eventually become the LiteLLM-equivalent plus the gaps LiteLLM does not cover, absorbing the redundant stages as plugins.

## Current Pipeline

```
Omnigent -> Pi -> Proxy 1 -> Privacy Orchestrator -> Headroom -> OmniRoute -> Forge -> Proxy 2 -> Iron-Proxy -> NordVPN -> Internet
(server)   (harness)  (Entry)    (PII Detection)      (Compression)  (Routing)    (Tool Calling)  (Pre-Egress)   (Security)   (Privacy)
                       |
                       v (forwards traces)
                 Langfuse (LLM Observability - parallel analytics sink)
```

## LiteLLM Feature Overlap

[LiteLLM](https://docs.litellm.ai/) is an OSS AI Gateway for 100+ LLMs with built-in: virtual keys, spend tracking, guardrails (including Presidio PII masking), load balancing, auto-router, admin dashboard, request/response logging, and native Langfuse/Langsmith/Arize logging integrations.

### Stage-by-Stage Overlap

| Pipeline Stage | LiteLLM Equivalent | Verdict |
|---|---|---|
| OmniRoute (routing across 177+ providers, tier-based fallback, 14 strategies) | LiteLLM core: 100+ providers, auto-router, fallbacks, 7 routing strategies, provider/model/tag budgets | Partially redundant - see OmniRoute vs LiteLLM Routing section |
| Privacy Orchestrator (PII detection) | LiteLLM Presidio PII guardrail (MASK/BLOCK, multi-language, pre/during/post_call modes) | Largely redundant |
| AI Dashboard Proxy 1/2 (analytics) | LiteLLM spend tracking + logging + Langfuse integration | Largely redundant |
| Langfuse (observability) | Native LiteLLM logging integration (already connected) | Already integrated |
| Forge (tool-calling repair) | LiteLLM guardrails (content filtering, NOT tool-call format repair) | NOT redundant |
| Headroom (context compression) | No LiteLLM equivalent | NOT redundant |
| Iron-Proxy (egress firewall) | No LiteLLM equivalent | NOT redundant |
| NordVPN (privacy/geo) | No LiteLLM equivalent | NOT redundant |
| Omnigent + Pi (agent origin) | No LiteLLM equivalent | NOT redundant |

### OmniRoute vs LiteLLM Routing - Partially Redundant, Not 100%

Both do multi-provider routing and fallback, but with different strengths. Neither fully replaces the other.

**OmniRoute unique features LiteLLM lacks:**
- **4-tier auto-fallback** (Subscription -> API -> Cheap -> Free) - drains paid subscriptions before touching free tiers. LiteLLM has $ budget limits but no tier-aware draining logic.
- **14 routing strategies** vs LiteLLM's 7. OmniRoute has `context-relay`, `context-optimized`, `reset-aware`, `lkgp` (last-known-good-provider), `strict-random`, `fill-first` which LiteLLM does not.
- **Auto-Combo 9-factor scoring** (health, quota, cost, latency, success rate, freshness, etc.) - holistic multi-dimensional scoring. LiteLLM strategies are single-dimension (cost-based OR latency-based, not both simultaneously).
- **Free-tier awareness** - 50+ free providers, 11 free forever, with quota tracking to maximize free usage. LiteLLM has no concept of free-tier draining.
- **RTK + Caveman compression** (15-95% token savings) - though in the current pipeline this is disabled in OmniRoute (Headroom handles compression).
- **TLS fingerprint stealth / 3-level proxy** for geo-blocked AI access.

**LiteLLM unique features OmniRoute lacks:**
- **Provider/model/tag $ budget limits** with Redis-backed spend tracking across multiple proxy instances. OmniRoute tracks quota but not hard $ budgets per provider/model/tag.
- **Health-check driven routing** - proactively removes unhealthy deployments from the pool before user requests fail. OmniRoute uses reactive circuit breakers.
- **Virtual keys with spend limits** - per-key/per-team/per-org budgets and rate limits. OmniRoute has no virtual key system.
- **Admin dashboard UI** for spend, keys, teams, models. OmniRoute has a dashboard but it's a savings tracker, not a key/budget management UI.
- **Guardrails framework** (Presidio PII, LlamaGuard, prompt injection, secret hiding). OmniRoute lists "guardrails" in its feature banner but they are not comparable to LiteLLM's pluggable guardrail system.
- **Native Langfuse/Langsmith/Arize logging callbacks**. OmniRoute has telemetry but not these native integrations.

**Verdict:** OmniRoute is the stronger *router* (tier-based fallback, 9-factor scoring, free-tier maximization). LiteLLM is the stronger *gateway* (keys, budgets, dashboard, guardrails, observability). They are complementary, not redundant.

### Can You Chain LiteLLM -> OmniRoute?

**Yes.** LiteLLM supports `openai_compatible` / `custom_openai` provider types that point at any OpenAI-compatible endpoint. OmniRoute exposes `http://localhost:20128/v1` (OpenAI-compatible API). Configure LiteLLM with a model entry pointing at OmniRoute as upstream:

```yaml
model_list:
  - model_name: auto
    litellm_params:
      model: openai/auto
      api_base: http://omniroute:20128
      api_key: os.environ/OMNIROUTE_KEY
```

This gives you LiteLLM's budget tracking, virtual keys, guardrails, dashboard, and Langfuse logging in front, with OmniRoute's tier-based fallback, 14 routing strategies, free-tier draining, and compression behind. LiteLLM treats OmniRoute as a single provider entry; OmniRoute does the multi-provider fanout.

**Redundancy note:** Both do routing/fallback. In this chain, LiteLLM's routing is effectively pass-through to a single "OmniRoute" provider. OmniRoute's routing is where the real multi-provider fanout happens. The sensible split is: LiteLLM = gateway layer (auth, keys, spend, guardrails, observability), OmniRoute = routing layer (tier fallback, free-tier draining, 9-factor scoring).

**Alternative:** Drop OmniRoute entirely and use LiteLLM's native 100+ provider routing. You lose tier-based fallback, 9-factor auto-combo scoring, free-tier draining, and compression. You gain simplicity (one service instead of two) and LiteLLM's health-check-driven routing + per-provider $ budgets.

### Critical Correction: Forge is NOT Redundant

Forge and LiteLLM guardrails solve different problems and are not interchangeable:

- **LiteLLM guardrails** = content/policy filtering (Presidio PII, LlamaGuard moderation, Lakera/Aporia prompt injection, `hide_secrets`). They run pre-call/during-call/post-call and filter or block input/output based on content.
- **Forge** = tool-call format reliability for non-conforming backends. Response validation against tools array schema, rescue parsing of malformed tool-call outputs (JSON in code fences, Mistral `[TOOL_CALLS]`, Qwen XML), retry loop with corrective messages, synthetic `respond` tool injection.

| | Forge | LiteLLM Guardrails |
|---|---|---|
| Purpose | Tool-call format repair | Content filtering (PII/moderation/secrets) |
| Acts on | Malformed tool-call JSON/XML | Text content of prompts/responses |
| Retry reason | Schema validation failure | Policy violation (block) |
| Target backends | Non-OpenAI-conforming (Mistral, Qwen, vLLM, Ollama) | Any |
| Unique feature | Synthetic `respond` tool, rescue parsing for 3 dialects | Presidio, LlamaGuard, prompt-injection detection |

Forge stays in the chain. It addresses a gap LiteLLM does not cover: tool-call repair for self-hosted/non-conforming models. If routing only to OpenAI/Anthropic, Forge adds little. If routing to Ollama/vLLM/Mistral/Qwen via OmniRoute, Forge does work LiteLLM will not.

## Per-Repo Verdicts

### ai-privacy-proxy - Largely Redundant

The Privacy Orchestrator pipeline stage: Rust + Candle ML running OpenAI's privacy-filter, 22+ PII categories, redaction/masking/tokenization.

LiteLLM ships Presidio PII masking as a first-class OSS guardrail:
- MASK + BLOCK actions, multi-language (`presidio_language`)
- Modes: `pre_call`, `during_call`, `post_call`, `logging_only`, `pre_mcp_call`
- Confidence-score thresholds, filter scope (input/output/both)
- Tracing via Langfuse (already in pipeline)

Gaps vs the Rust impl: tokenization mode (Presidio only does mask/block) and the Candle ML detection engine (Presidio is rule+ML, different but production-proven). For the core PII use case, LiteLLM covers it inline as a guardrail.

### ai-dashboard - Largely Redundant

The dual-proxy analytics collector + Next.js web UI tracking: company clients, AI clients, teams, pipeline stages, model suppliers, models, input types.

LiteLLM covers natively:
- Spend/cost tracking per key/user/team/org
- Admin dashboard UI
- Request/response logging
- Multi-tenant hierarchy (orgs -> teams -> projects -> keys)
- Native Langfuse integration (already in pipeline)

What LiteLLM does not natively track: pipeline-stage comparison (entry vs pre-egress compression/routing effectiveness) and AI-client identification (Claude Code vs Codex vs Pi vs Devin). But those dimensions only exist because of the multi-stage pipeline. If LiteLLM replaces OmniRoute + Forge + the privacy stage, the "pipeline stage analytics" concept largely dissolves.

Unique residual: input-type classification (text/image/audio/video/code) and dual-proxy delta measurement. Minor.

### OmniRoute - Partially Redundant (Complementary, Not Replaceable)

OmniRoute is the stronger *router*; LiteLLM is the stronger *gateway*. See the "OmniRoute vs LiteLLM Routing" section above for the full feature comparison.

**OmniRoute keeps if:** you need tier-based subscription draining (use paid quota before free), 9-factor auto-combo scoring, free-tier maximization across 50+ free providers, or the 14 routing strategies (especially `context-relay`, `reset-aware`, `lkgp`).

**LiteLLM replaces OmniRoute if:** you only need basic multi-provider routing with fallback, and you value virtual keys, per-provider $ budgets, health-check-driven routing, and the admin dashboard more than tier-based draining.

**Chaining option:** LiteLLM -> OmniRoute is supported (LiteLLM treats OmniRoute as an `openai_compatible` upstream). This gives LiteLLM's gateway features (keys, spend, guardrails, Langfuse) in front of OmniRoute's routing features (tier fallback, free-tier draining, 9-factor scoring). See "Can You Chain LiteLLM -> OmniRoute?" section above.

### janus-hub - NOT Redundant (Different Layer)

Janus-Hub is an AI agent operations platform (Rust): multi-directional proxy, pluggable agent architecture, task management, composable harness processing, GraphQL API, notifications, human-in-the-loop approvals, event processing, resource registry, TUI.

LiteLLM overlaps only on protocol translation (OpenAI <-> Anthropic <-> Custom) and basic inference proxying. Everything else Janus-Hub does is agent orchestration, not LLM gateway work:
- Task management, harness composition, human-in-the-loop, event processing, notifications, resource registry, GraphQL subscriptions, TUI - none of these are LiteLLM features.

Janus-Hub is not referenced in [[PIPELINE]] - it is not part of the analytics pipeline. It is a separate project serving a different layer (agent ops, not LLM routing).

The one genuinely redundant piece: Janus-Hub's inference-proxy/protocol-translation feature overlaps with both LiteLLM and OmniRoute.

## Strategic Direction: Janus-Hub Absorbs the Redundant Stages

The idea behind Janus-Hub is to eventually become LiteLLM plus the gaps LiteLLM does not cover. The redundant stages (Privacy Orchestrator, Dashboard Collector) are intended to be absorbed into Janus-Hub via its plugin system rather than replaced by LiteLLM directly.

### Absorption Plan

**Janus-Hub becomes the unified gateway + agent ops platform:**

1. **Privacy Orchestrator -> Janus-Hub plugin**: The PII detection/transformation logic from ai-privacy-proxy becomes a Janus-Hub plugin. This preserves the tokenization mode and Candle ML detection engine that Presidio lacks, while consolidating the proxy layer. The plugin hooks into Janus-Hub's request/response transformation pipeline.

2. **Dashboard Collector -> Janus-Hub plugin**: The analytics collection from ai-dashboard (proxy 1/2 collectors) becomes a Janus-Hub plugin. The multi-dimensional analytics (company clients, AI clients, teams, pipeline stages, model suppliers, models, input types) are emitted as events through Janus-Hub's existing event processing layer, with Langfuse as the observability sink.

3. **OmniRoute-equivalent routing -> Janus-Hub inference proxy**: Janus-Hub's existing inference-proxy/protocol-translation feature expands to cover the multi-provider routing that OmniRoute currently does. The pluggable architecture already supports this. This must include OmniRoute's unique strengths: 4-tier subscription-draining fallback, 9-factor auto-combo scoring, free-tier awareness, and the 14 routing strategies - not just basic provider fanout.

### What Stays Independent

- **Forge**: Stays as a separate stage. Tool-call format repair for non-conforming backends is not a plugin concern - it is a structural transformation that must sit between routing and egress. Janus-Hub's plugin system could host it, but the retry-loop-with-upstream semantics make it better as a dedicated stage.
- **Headroom**: Stays independent. Context compression is a distinct concern with its own ML models (RTK + Caveman).
- **Iron-Proxy**: Stays independent. Egress firewall and secret injection are security boundaries, not gateway features.
- **NordVPN**: Stays independent. Privacy/geo layer.
- **Omnigent + Pi**: Stay independent. Agent origin, not gateway work.

### Target Architecture

```
Omnigent -> Pi -> Janus-Hub (routing + PII plugin + analytics plugin + Langfuse) -> Forge -> Headroom -> Iron-Proxy -> NordVPN -> Internet
(server)   (harness)  (unified gateway + agent ops)                                   (Tool Calling) (Compression) (Security)   (Privacy)
```

Janus-Hub replaces: OmniRoute (routing), Privacy Orchestrator (PII plugin), AI Dashboard Proxy 1/2 (analytics plugin). Forge, Headroom, Iron-Proxy, NordVPN, Omnigent, Pi remain.

## Open Questions

- Does Janus-Hub's plugin system support the pre-call/during-call/post-call guardrail modes that LiteLLM Presidio offers, or only request/response transformation?
- How does Janus-Hub's analytics plugin emit data to Langfuse - direct ingestion API, or via the event processing layer?
- Will Janus-Hub's expanded inference proxy support the 177+ providers OmniRoute currently routes to, or a subset?
- Will Janus-Hub's expanded inference proxy replicate OmniRoute's 4-tier subscription-draining fallback and 9-factor auto-combo scoring, or only basic provider fanout? This is the key question for whether Janus-Hub can fully absorb OmniRoute.
- Is the dual-proxy delta measurement (entry vs pre-egress) preserved when both collectors become Janus-Hub plugins, or does it collapse into single-point instrumentation?
- If chaining LiteLLM -> OmniRoute, where does Forge sit? Options: LiteLLM -> OmniRoute -> Forge (Forge repairs OmniRoute's upstream responses) or LiteLLM -> Forge -> OmniRoute (Forge repairs before routing). The current pipeline has Forge after OmniRoute, which is correct since Forge fixes responses from the routed provider.

## References

- [[PIPELINE]] - Current pipeline configuration
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)
- [LiteLLM Docs](https://docs.litellm.ai/)
- [LiteLLM Presidio PII Guardrail](https://docs.litellm.ai/docs/proxy/guardrails/pii_masking_v2)
- [LiteLLM Spend Tracking](https://docs.litellm.ai/docs/proxy/cost_tracking)
- [LiteLLM Multi-Tenant Architecture](https://docs.litellm.ai/docs/proxy/multi_tenant_architecture)
- [LiteLLM Budget Routing](https://docs.litellm.ai/docs/proxy/provider_budget_routing)
- [LiteLLM Routing & Load Balancing](https://docs.litellm.ai/docs/routing-load-balancing)
- [LiteLLM Router Strategies](https://docs.litellm.ai/docs/routing)
- [LiteLLM OpenAI-Compatible Endpoints](https://docs.litellm.ai/docs/providers/openai_compatible)
- [OmniRoute Auto-Combo Routing](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/routing/AUTO-COMBO.md)
- ai-privacy-proxy repo: `/Users/micro/p/gh/levonk/ai-privacy-proxy`
- ai-dashboard repo: `/Users/micro/p/gh/levonk/ai-dashboard`
- janus-hub repo: `/Users/micro/p/gh/levonk/janus-hub`
- OmniRoute repo: `/Users/micro/p/gh/levonk/OmniRoute`
