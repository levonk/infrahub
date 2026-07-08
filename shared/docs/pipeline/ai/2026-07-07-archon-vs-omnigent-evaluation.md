---
title: "Archon vs Omnigent vs LiteLLM — Pipeline Origin Evaluation"
aliases:
  - "Archon Omnigent Evaluation"
  - "Pipeline Origin Comparison"
tags:
  - note
  - pipeline/ai
  - evaluation
  - archon
  - omnigent
  - litellm
date-created: 2026-07-07
date-updated: 2026-07-07
scope_focus: "session sharing, Archon-to-Omnigent integration, LiteLLM gateway layer, pipeline origin refinement"
---

# Archon vs Omnigent vs LiteLLM — Pipeline Origin Evaluation

## Overview

Evaluation of [coleam00/Archon](https://github.com/coleam00/Archon), [omnigent-ai/omnigent](https://github.com/omnigent-ai/omnigent), and [BerriAI/litellm](https://github.com/BerriAI/litellm) for the AI pipeline's request-origin layer. The current pipeline (`PIPELINE-AI.md`) uses Omnigent + Pi as the sole request origin. This evaluation assesses whether Archon should join as a co-origin or replace Omnigent, and clarifies LiteLLM's role (it is already the pipeline entry gateway, not an orchestrator peer).

## Key Points

- **Archon, Omnigent, Herdr, and LiteLLM are four different layers, not peers.** Archon is the workflow layer (DAG, loops, `fresh_context`, `interactive` gates). Omnigent is the session layer (multi-device sync, policies, sandboxing, co-driving). Herdr is the multiplexer layer (agent-aware PTY persistence, remote SSH attach, socket API). LiteLLM is the gateway layer (auth, PII, spend, Langfuse). They stack cleanly: Archon dispatches work via `IAgentProvider` → Omnigent manages the session → Herdr manages the terminal PTY → Pi/Claude/Codex executes → LLM calls route through LiteLLM.
- **Archon lacks multi-user session sharing at the session layer.** No "share live session," "co-drive," or "fork" feature. Slack/Telegram adapters allow multiple users to interact with the same bot, but each interaction is its own conversation — no shared real-time view with full context. Omnigent has invite-only accounts, OIDC SSO, share links, co-driving, and conversation forking.
- **Archon-to-Omnigent integration is a clean layering, not redundant.** Archon's `IAgentProvider` interface (`sendQuery`, `getType`, `getCapabilities`) and community provider registry (`registerCommunityProviders()`) provide the integration point. An "Omnigent provider" would implement `IAgentProvider.sendQuery()` by creating/resuming an Omnigent session, sending the prompt to the AI assistant inside that session, and streaming back `MessageChunk`s. The session persists in Omnigent's tmux after the node completes, enabling mid-node intervention.
- **The tmux session sharing is the key gap neither closes alone.** Archon runs workflow nodes as ephemeral processes — when a node finishes, the process dies, and there's nothing to attach to mid-node. If those sessions run inside Omnigent-managed tmux, a teammate can `omnigent attach <session_id>` to co-drive mid-workflow-node, you can pick up the terminal from your phone, and policies/sandboxing apply throughout.
- **Archon solves the context-pollution and interactive-gate problems that Omnigent doesn't.** `fresh_context: true` starts a fresh agent session per loop iteration (the "clear context between phases" primitive). `interactive: true` pauses the workflow for human input and resumes. These map cleanly to the Omnigent provider: `fresh_context` → create new Omnigent session; `interactive` → pause workflow, Omnigent session stays alive in tmux, human attaches, workflow resumes when approval gate clears.
- **Omnigent solves the multi-device, policy, and sandboxing problems that Archon doesn't.** Server/agent/session-level policies (spend caps, tool allowlists), bwrap/seatbelt OS sandboxing, L7 egress proxy, cloud sandboxes (Modal, Daytona, E2B, K8s), native desktop app, mobile web UI.
- **LiteLLM already centralizes logging and spend for both.** Langfuse traces, per-key spend tracking, PII guardrail, and auth all happen at the gateway layer regardless of which orchestrator originated the request. The "log centralization" gap is already closed by LiteLLM, not by stacking orchestrators.

## Details

### Feature Matrix (Webhook / Gateway / Interaction Capabilities)

| Capability | [Archon](https://github.com/coleam00/Archon) | [Omnigent](https://github.com/omnigent-ai/omnigent) | [LiteLLM](https://github.com/BerriAI/litellm) |
|---|---|---|---|
| **License** | ☑️ OSS — MIT | ☑️ OSS — Apache 2.0 | ☑️ OSS — MIT |
| **Status** | ✅ Stable | ⚠️ Alpha | ✅ Stable |
| **Stars** | 🏆 22.8k | 6.6k | 18k+ |
| **Tech Stack** | Bun + TypeScript + SQLite/PostgreSQL | Python 3.12+, uv, tmux, bwrap/seatbelt | Python, self-hosted proxy |
| **Layer** | Agent orchestrator | Agent orchestrator (meta-harness) | LLM gateway |
| **Slack adapter** | ✅ Socket Mode, threads, approval buttons | ❌ | ❌ (not an interaction layer) |
| **Telegram adapter** | ✅ | ❌ | ❌ |
| **Discord adapter** | ✅ (community) | ❌ | ❌ |
| **GitHub webhooks** | ✅ | ❌ | ❌ |
| **Multi-user session sharing** | ❌ | 🏆 Share links, co-drive, fork | ❌ |
| **OIDC SSO** | ❌ | ✅ Google/GitHub/Okta/Microsoft | ✅ Enterprise (SAML) |
| **Workflow engine (DAG + loops)** | 🏆 YAML DAG, `until:` conditions, `fresh_context`, `interactive` | ❌ Agent YAML only | ❌ |
| **Deterministic + AI nodes** | ✅ `bash:` + `prompt:` nodes | ❌ AI-only | ❌ |
| **`fresh_context` per iteration** | 🏆 Yes | ❌ | ❌ |
| **`interactive: true` (human gate)** | 🏆 Yes | ❌ | ❌ |
| **Policies / governance** | ❌ | 🏆 Server/agent/session-level, spend caps, tool allowlists | ✅ Per-key budgets, guardrails |
| **OS sandboxing** | ❌ | 🏆 bwrap/seatbelt, L7 egress proxy | ❌ |
| **Cloud sandboxes** | ❌ | 🏆 Modal, Daytona, E2B, K8s, CoreWeave, Databricks | ❌ |
| **Model gateway (OpenRouter/Ollama)** | ➖ Via provider keys | ✅ First-class "Gateway" credential | 🏆 IS the gateway |
| **Auth / virtual keys** | ❌ | ✅ Invite-only, OIDC | 🏆 Per-key/team/user |
| **Spend tracking** | ❌ | ✅ Policies | 🏆 Per-key/team/user |
| **PII guardrail** | ❌ | ❌ | 🏆 Presidio masking |
| **Langfuse integration** | ❌ | ❌ | 🏆 Native |
| **Routing / load balancing** | ❌ | ❌ | 🏆 Router with retry/fallback |
| **Git worktree isolation** | ✅ Every workflow run | ✅ Polly example | ❌ |
| **Native desktop app** | ❌ | ✅ macOS | ❌ |
| **Mobile web UI** | ✅ Via platform adapters | ✅ Built for mobile | ✅ Admin UI (web) |

### Archon Session Sharing — What It Does and Doesn't Have

Archon's Web UI is single-user-oriented:
- **Conversations sidebar** — grouped by project, searchable, but one user's view
- **Slack/Telegram user whitelist** — `SLACK_ALLOWED_USER_IDS` controls who can @mention the bot, but each mention is its own conversation thread, not a shared live session
- **Unified monitoring hub** — sidebar aggregates CLI + Slack + Telegram + GitHub conversations, but it's an admin view, not multi-user collaboration
- **No share link, no co-drive, no fork** — these are Omnigent-exclusive

Omnigent's multi-user is a different category:
- **Invite-only accounts** with admin → members → invite flow
- **OIDC SSO** (Google, GitHub, Okta, Microsoft)
- **Share a live session** — hit Share, send link, teammates watch and chat in real time
- **Co-drive** — `omnigent attach <session_id>`, teammate's messages execute on your machine
- **Fork** — `omnigent run --fork <session_id>`, clone conversation to your machine, continue independently

### Archon → Omnigent Integration Analysis

Archon and Omnigent operate at different layers of the stack and stack cleanly via Archon's `IAgentProvider` interface. The integration point is a community provider:

```
Archon (workflow layer)     — DAG, loops, fresh_context, interactive gates
  ↓ dispatches via IAgentProvider.sendQuery()
Omnigent (session layer)    — multi-device sync, policies, sandboxing, co-driving
  ↓ manages terminal via
Herdr (multiplexer layer)   — agent-aware PTY persistence, remote SSH attach, socket API
  ↓ runs terminal for
Pi/Claude/Codex (execution) — reads/writes files, runs commands
  ↓ LLM calls route through
LiteLLM (gateway layer)     — auth, PII, spend, Langfuse
```

**Integration point:** Archon's provider registry (`packages/providers/src/registry.ts`) already supports community providers (Pi, OpenCode, Copilot). An "Omnigent provider" would be a new community provider under `packages/providers/src/community/omnigent/` that implements `IAgentProvider.sendQuery()` by:
1. Creating/resuming an Omnigent session (via Omnigent's SDK/API)
2. Omnigent creates a Herdr workspace/pane for the agent
3. Sending the prompt to the AI assistant running inside that Herdr pane
4. Streaming back `MessageChunk`s from the session
5. The Herdr pane persists after the Archon node completes, enabling mid-node attach

**Why Herdr instead of raw tmux:** Herdr ([herdr.dev](https://herdr.dev/), [ogulcancelik/herdr](https://github.com/ogulcancelik/herdr)) is an agent-aware terminal multiplexer written in Rust. Unlike tmux, it understands agent state (blocked/working/done), exposes a socket API (`api.herdr.dev`) for programmatic control, supports remote SSH attach from any device (including phone), and keeps PTYs alive across server restarts. This makes it a better fit than tmux for the multiplexer layer because:
- Agent state awareness — Omnigent/Archon can query pane state without scraping terminal output
- Socket API — programmatic create/attach/detach for the Omnigent provider implementation
- PTY persistence across restarts — survives Herdr server replacement, long-lived workloads keep responding
- Remote attach — `herdr --remote workbox` bridges local clipboard + keybindings to remote session

**Primitive mapping:**
- `fresh_context: true` → Omnigent provider creates a new Herdr pane (or workspace) instead of resuming
- `interactive: true` → Archon pauses the workflow, Herdr pane stays alive, human `herdr` attaches (locally or over SSH), workflow resumes when approval gate clears
- `resumeSessionId` (already in `IAgentProvider` contract) → maps to Herdr pane/workspace resumption

**Why the multiplexer layer matters:** Archon runs workflow nodes as ephemeral processes — when a node finishes, the process dies, and there's nothing to attach to mid-node. If those sessions run inside Herdr-managed PTYs, then mid-workflow-node:
- A teammate can `herdr` attach to the pane to co-drive
- You can pick up the workflow's terminal from your phone over SSH
- The PTY persists across device switches and Herdr server restarts
- Omnigent's policies apply (spend caps, tool allowlists, OS sandboxing)
- Agent state (blocked/working/done) is visible at a glance without scraping output

This is the gap neither closes alone: Archon has workflow structure but ephemeral sessions; Omnigent has session management but no workflow structure; Herdr has persistent agent-aware PTYs but no workflow engine or session policies. Stacked, you get all three.

**Alternative relationships considered:**

1. **Stacked via Omnigent provider (recommended)** — Archon handles workflow structure, Omnigent handles session infrastructure, Pi/Claude/Codex executes. Clean layering via `IAgentProvider`. No overlap — each layer does what the other can't.

2. **Archon replaces Omnigent+Pi** — Archon drives Claude Code/Codex/Pi directly. You lose: multi-device sync, policies, cloud sandboxes, co-driving, desktop app, mid-node tmux attach. You gain: DAG workflows, `fresh_context`, `interactive`, platform adapters. Net loss since Omnigent's session infrastructure is already deployed and Archon can use it via the provider abstraction.

3. **Side-by-side (fallback)** — Archon for structured workflows, Omnigent for ad-hoc multi-device sessions, no integration between them. Both route through LiteLLM. Simpler but loses the mid-node intervention capability that the stacked approach provides.

### LiteLLM's Role (Already Deployed)

LiteLLM is already the pipeline entry (`aigate.levonk.com`, Ansible role `roles/ai-litellm/`). It is **not** a peer to Omnigent/Archon — it's the layer underneath both:

| What LiteLLM solves | What it doesn't solve |
|---|---|
| Auth / virtual keys | Workflow structure (DAG, loops) |
| Spend tracking per key/team/user | Session sharing / multi-user collaboration |
| PII guardrail (Presidio) | Agent action policies (shell, file writes) |
| Langfuse logging (centralized observability) | OS-level sandboxing |
| Routing / load balancing | Interactive human gates |
| Unified OpenAI-compatible interface | Fresh context between phases |

The "log centralization" and "spend tracking" gaps are already closed by LiteLLM. Any orchestrator (Archon, Omnigent, or both) that routes through `aigate` gets these for free.

### Pipeline Origin Refinement Recommendation

Current pipeline origin: `Omnigent + Pi` (single origin, no workflow structure).

Recommended refinement: **stacked architecture** — Archon as the workflow layer on top of Omnigent as the session layer, both routing LLM calls through LiteLLM.

```
┌─────────────────────────────────────────────────────────────┐
│  Archon (Workflow Layer)                                    │
│  DAG, loops, fresh_context, interactive gates               │
│  Platform adapters: Slack, Telegram, Discord, GitHub        │
└──────────┬──────────────────────────────────────────────────┘
           │ dispatches via IAgentProvider (Omnigent provider)
           ▼
┌─────────────────────────────────────────────────────────────┐
│  Omnigent (Session Layer)                                   │
│  multi-device sync, policies, sandboxing, co-driving        │
└──────────┬──────────────────────────────────────────────────┘
           │ manages terminal via
           ▼
┌─────────────────────────────────────────────────────────────┐
│  Herdr (Multiplexer Layer)                                  │
│  agent-aware PTY persistence, remote SSH attach,            │
│  socket API (api.herdr.dev), state awareness                │
└──────────┬──────────────────────────────────────────────────┘
           │ runs terminal for
           ▼
┌─────────────────────────────────────────────────────────────┐
│  Pi / Claude / Codex (Execution Layer)                      │
│  reads/writes files, runs commands                          │
└──────────┬──────────────────────────────────────────────────┘
           │ LLM calls route through
           ▼
┌─────────────────────────────────────────────────────────────┐
│  LiteLLM (aigate) — Gateway Layer                           │
│  auth, keys, PII masking, spend, Langfuse traces            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
     Headroom → OmniRoute → Forge → Iron-Proxy → NordVPN → Internet
```

**What this closes:**
- ✅ Workflow structure with context-clearing between phases (Archon `fresh_context`)
- ✅ Interactive human approval gates (Archon `interactive: true`)
- ✅ Mid-node intervention via Herdr attach (PTY persistence, local or SSH from phone)
- ✅ Agent state visibility without scraping output (Herdr state awareness: blocked/working/done)
- ✅ Multi-device access to running workflow nodes (Omnigent + Herdr remote attach)
- ✅ Out-of-band user interaction via chat platforms (Archon Slack/Telegram/Discord adapters)
- ✅ Log centralization (already via LiteLLM + Langfuse)
- ✅ Spend tracking (already via LiteLLM, plus Omnigent policies)
- ✅ OS-level sandboxing (Omnigent bwrap/seatbelt)
- ✅ Agent action policies (Omnigent server/agent/session-level)

**What you'd need to build:**
- Omnigent community provider for Archon (`packages/providers/src/community/omnigent/`) — implements `IAgentProvider.sendQuery()` by routing through Omnigent's session API, which creates Herdr panes
- Omnigent Herdr support (open issue in Omnigent repo — replace tmux with Herdr as the multiplexer backend)
- Archon deployment (Bun + TypeScript, Docker available)
- Archon Slack/Telegram adapter configuration (5-15 min each per docs)
- Workflow YAMLs for your structured processes (idea→PR, fix-issue, etc.)

## Questions

- Does Omnigent expose a programmatic API (not just CLI) that an Archon `IAgentProvider` implementation could call for session create/resume/attach? The `sdks/` directory suggests yes, but needs verification.
- How does `fresh_context: true` interact with Omnigent's session continuity? If Archon says "fresh session for this node," does the Omnigent provider create a new Omnigent session, or does it reuse the existing tmux and just reset the agent's context?
- Does Archon's `interactive: true` approval gate work end-to-end through Slack/Telegram (button clicks in-thread), or does it require the Web UI? If it works through Slack, this combined with Omnigent tmux attach gives two complementary intervention paths.
- Should Archon's `fresh_context` and `interactive` primitives be documented as the canonical solution to the context-pollution problem in skills-src workflows, replacing the `[fork]` marker convention?
- Does the stacked architecture (Archon → Omnigent → Pi) work with Archon's git worktree isolation, or does Omnigent's session model conflict with worktree-based branch isolation?
- Can Archon's Slack adapter support multi-stakeholder async ideation (multiple users in a Slack thread over days) for the out-of-band interaction pattern?

## Action Items

- [ ] Update `PIPELINE-AI.md` Architecture diagram to show stacked layers (Archon → Omnigent → Herdr → Pi → LiteLLM)
- [ ] Track Omnigent Herdr support issue (replace tmux with Herdr as multiplexer backend)
- [ ] Verify Omnigent SDK exposes programmatic session create/resume/attach API for provider implementation
- [ ] Implement Omnigent community provider for Archon (`packages/providers/src/community/omnigent/`)
- [ ] Add Archon + Herdr deployment stacks to `services/ai-codeassist/` alongside Omnigent + Pi
- [ ] Configure Archon Slack adapter for out-of-band interaction testing
- [ ] Author Archon workflow YAMLs for: idea→PR, fix-issue, interactive-PRD
- [ ] Evaluate whether `fresh_context` + `interactive` + Herdr attach replaces the `[fork]` subagent delegation pattern in skills-src
- [ ] Test mid-node intervention: run Archon workflow with Omnigent provider, `herdr` attach from second device mid-node

## References

- [[PIPELINE-AI]]
- [coleam00/Archon](https://github.com/coleam00/Archon) — workflow engine for AI coding agents
- [Archon Web UI docs](https://archon.diy/adapters/web/) — single-user session model
- [Archon Slack adapter docs](https://archon.diy/adapters/slack/) — Socket Mode, user whitelist, in-thread approval buttons
- [omnigent-ai/omnigent](https://github.com/omnigent-ai/omnigent) — meta-harness for AI agents
- [Herdr](https://herdr.dev/) — agent-aware terminal multiplexer ([ogulcancelik/herdr](https://github.com/ogulcancelik/herdr))
- [BerriAI/litellm](https://github.com/BerriAI/litellm) — LLM gateway (already deployed as `aigate`)
- [LiteLLM docs](https://docs.litellm.ai/docs/) — virtual keys, spend tracking, guardrails, Langfuse
- [Archon Authoring Workflows](https://archon.diy/guides/authoring-workflows/) — `fresh_context`, `interactive`, DAG, loops
- [Archon Approval Nodes](https://archon.diy/guides/approval-nodes/) — `interactive: true` gate behavior
- [Archon Loop Nodes](https://archon.diy/guides/loop-nodes/) — `fresh_context: true` per iteration
