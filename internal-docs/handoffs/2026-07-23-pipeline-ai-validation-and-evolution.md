# Pipeline AI Validation and Evolution to MVP

**Date**: 2026-07-23
**Session**: Validate PIPELINE-AI.md plan feasibility, then evolve to MVP pipeline
**Status**: In progress — subagents dispatched for parallel fixes

## Current State

### Completed

- Validated PIPELINE-AI.md (992 lines) against actual codebase and deployment state
- Confirmed Omnigent at `https://aiif.levonk.com` is NOT an OpenAI-compatible endpoint (it's an agent orchestrator; Forge/OmniRoute are the OpenAI-compatible surfaces)
- Identified 7 discrepancies between documented plan and actual code
- User made evolution decisions (defer Forge/NordVPN/AI Dashboard/Privacy Orchestrator; LiteLLM=privacy; LiteLLM→Langfuse=observability)
- Dispatched 3 parallel subagents to fix codebase

### In Progress (subagents)

1. **Subagent A** (`4720e44b`): Rewriting PIPELINE-AI.md for evolved pipeline
2. **Subagent B** (`d1a99a88`): Wiring Headroom → OmniRoute upstream proxy
3. **Subagent C** (`eb63a99c`): Reconciling deploy-ai-dashboard-pipeline.yml

### Blocking Issues

- SSH to OCI server (`oci.tale-grouper.ts.net`) failed with "Permission denied (publickey)" — no matching key loaded in this shell's ssh-agent. Cannot verify live container state. Only the RSA key `micro@LZKMBP2016.home.lkn` is loaded; the OCI server expects a different key. User must run `ssh-add` with the correct key, or the deployment must be verified from a shell with proper SSH setup.

## Project Overview

### Objective

Evolve the AI analytics pipeline from an over-ambitious documented plan to a working MVP, deferring non-essential stages to future releases.

### Current Status

The documented pipeline in `shared/docs/PIPELINE-AI.md` was ahead of the code. The user decided to simplify to an MVP and defer Forge, NordVPN, AI Dashboard, and standalone Privacy Orchestrator.

## Key Decisions Made

- **MVP pipeline**: `Omnigent → Pi → LiteLLM (aigate) → Headroom → OmniRoute (airoute) → Iron-Proxy → Internet`
- **Privacy**: LiteLLM's Presidio PII guardrail is the privacy layer (standalone Privacy Orchestrator deferred)
- **Observability**: LiteLLM → Langfuse (parallel trace sink). AI Dashboard Proxy 1/2 + DB deferred.
- **Forge deferred** (Phase 2): No Ansible role exists; tool-call repair is not needed for MVP
- **NordVPN deferred** (Phase 3): Iron-Proxy egresses directly to Internet for now
- **AI Dashboard deferred** (Phase 4): LiteLLM + Langfuse cover observability for MVP
- **Privacy Orchestrator deferred** (Phase 5): LiteLLM Presidio replaces it for now

## Technical Context

### Stack/Tools

- **Omnigent**: Agent orchestrator (FastAPI/WebSocket + Postgres) — deployed at `aiif.levonk.com`
- **Pi**: Coding harness (RPC mode, JSONL over stdin/stdout) — deployed with Omnigent
- **LiteLLM**: AI gateway (auth, virtual keys, spend tracking, Presidio PII masking, Langfuse logging) — `aigate.levonk.com`
- **Headroom**: Context compression (RTK+Caveman, 60-95% token savings) — port 8787
- **OmniRoute**: Provider fanout (4-tier fallback, 9-factor scoring, 177+ providers) — `airoute.levonk.com`, port 20128
- **Iron-Proxy**: Egress firewall (MITM TLS inspection, allowlist, audit) — ports 8080/8870
- **Langfuse**: LLM observability (traces, analytics) — `langfuse.levonk.com`
- **Ansible**: All deployment via `community.docker` modules — NEVER docker compose

### Important Files

- `shared/docs/PIPELINE-AI.md` — pipeline architecture doc (being rewritten by Subagent A)
- `shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml` — primary deployment playbook (LiteLLM + Headroom + OmniRoute + Langfuse pre-stage)
- `shared/active/02-config/ansible/playbooks/deploy-ai-dashboard-pipeline.yml` — old playbook being reconciled (Subagent C)
- `shared/active/02-config/ansible/playbooks/deploy-omnigent.yml` — Omnigent + Pi deployment (already working)
- `shared/active/02-config/ansible/playbooks/deploy-langfuse.yml` — Langfuse deployment (already working)
- `shared/active/02-config/ansible/roles/ai-litellm/` — LiteLLM role (routes upstream to `http://headroom:8787`)
- `shared/active/02-config/ansible/roles/proxy-headroom/` — Headroom role (upstream was empty, being fixed by Subagent B)
- `shared/active/02-config/ansible/roles/omniroute/` — OmniRoute role (egress points to iron-proxy, skipping Forge — correct for MVP)
- `shared/active/02-config/ansible/roles/proxy-iron-proxy/` — Iron-Proxy role
- `shared/active/02-config/ansible/roles/vpn-nordvpn/` — NordVPN role (deferred, not in pipeline playbooks)

### Validation Findings (research results)

| Stage | Role exists? | Playbook deploys it? | Wired correctly? |
|---|---|---|---|
| Omnigent | N/A (playbook) | deploy-omnigent.yml | Yes — deployed & healthy |
| Pi | N/A (in omnigent playbook) | deploy-omnigent.yml | Yes |
| LiteLLM | roles/ai-litellm/ | deploy-ai-gateway-pipeline.yml | Yes — routes to headroom:8787 |
| Headroom | roles/proxy-headroom/ | deploy-ai-gateway-pipeline.yml | **No — upstream_proxy was empty** (Subagent B fixing) |
| OmniRoute | roles/omniroute/ | deploy-ai-gateway-pipeline.yml | Yes — egress to iron-proxy (Forge skipped, correct for MVP) |
| Iron-Proxy | roles/proxy-iron-proxy/ | deploy-ai-dashboard-pipeline.yml only | **Not in gateway playbook** — may need adding |
| NordVPN | roles/vpn-nordvpn/ | cloud-server-vpn.yml only | Deferred — not in pipeline |
| Forge | **No role** | Commented out as TODO | Deferred (Phase 2) |
| Langfuse | N/A (playbook) | deploy-langfuse.yml (pre-staged by gateway playbook) | Yes |
| Privacy Orchestrator | N/A (playbook) | deploy-privacy-orchestrator.yml (standalone) | Deferred — LiteLLM Presidio replaces |
| AI Dashboard Proxy 1/2 | **No role** | Commented out as TODO | Deferred (Phase 4) |

### Key gap to address after subagents

**Iron-Proxy is not deployed by `deploy-ai-gateway-pipeline.yml`.** It's only deployed by `deploy-ai-dashboard-pipeline.yml` (the old playbook). For the MVP to work end-to-end, Iron-Proxy needs to be added to the gateway pipeline playbook, OR the dashboard playbook needs to remain as the Iron-Proxy deployer. Subagent C is checking this.

## Next Steps for Continuation Session

1. **Check subagent results**: Verify the 3 subagents completed successfully:
   - PIPELINE-AI.md rewritten with MVP pipeline + future evolution roadmap
   - Headroom upstream proxy wired to OmniRoute
   - deploy-ai-dashboard-pipeline.yml reconciled

2. **Verify Iron-Proxy deployment**: Ensure Iron-Proxy is deployed by either the gateway playbook or the reconciled dashboard playbook. If not, add `proxy-iron-proxy` role to `deploy-ai-gateway-pipeline.yml`.

3. **Run ansible-lint** on changed playbooks/roles:
   ```bash
   cd ~/p/gh/levonk/infrahub
   devbox run -- just ansible-lint
   ```

4. **Dry-run the gateway pipeline playbook**:
   ```bash
   cd ~/p/gh/levonk/infrahub
   devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
     shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
     --check --diff --vault-password-file ~/.ansible/vault_password
   ```

5. **Deploy and verify end-to-end** (requires SSH access to OCI server — fix ssh-agent first):
   ```bash
   ssh-add ~/.ssh/<correct-key>
   devbox run -- rtk ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
     shared/active/02-config/ansible/playbooks/deploy-ai-gateway-pipeline.yml \
     --vault-password-file ~/.ansible/vault_password
   ```

6. **Commit changes** using the git-repository-management skill or git-commit-batch.sh.

## Pipeline Evolution Roadmap

| Phase | Scope | Status |
|---|---|---|
| **Phase 1 (MVP)** | LiteLLM → Headroom → OmniRoute → Iron-Proxy → Internet, LiteLLM=privacy, LiteLLM→Langfuse | In progress |
| **Phase 2** | Add Forge (tool-call repair) between OmniRoute and Iron-Proxy | Future |
| **Phase 3** | Add NordVPN after Iron-Proxy for privacy egress | Future |
| **Phase 4** | Revisit AI Dashboard Proxy 1/2 + DB for deeper analytics | Future |
| **Phase 5** | Revisit standalone Privacy Orchestrator if LiteLLM Presidio is insufficient | Future |
