# Task Index: Imagination Studio kckinai Deployment

**PRD**: `../feat-202611170854-imagination-studio.md`
**Research**: `internal-docs/research/service/imagination-studio/` (overview,
deployment, configuration, security, alternatives)
**Implementation guide**: `.agents/workflows/infrahub-add-new-service.md`

## Stories

| Story ID | Title | Phase | Status | Parallel-safe | Dependencies | Dependants | Branch |
|---|---|---|---:|---|---|---|---|
| 02-001 | Shared + levonk infra vars, services.yml entry | 02 | [x] Done | true | — | 03-001, 04-001, 05-001 | `levonk/20261116-imagination-studio` |
| 03-001 | `ai-imagination-studio` Ansible role (native install on kckinai) | 03 | [x] Done | false | 02-001 | 04-001, 05-001 | `levonk/20261116-imagination-studio` |
| 04-001 | `deploy-imagination-studio-models.yml` async install playbook | 04 | [x] Done | false | 02-001, 03-001 | 05-001 | `levonk/20261116-imagination-studio` |
| 05-001 | deploy + validate playbooks, just/devbox recipes, docs | 05 | [~] In-Progress | false | 03-001, 04-001 | — | `levonk/20261116-imagination-studio` |

## Notes

- **No container/Dockerfile story** — native install per `ai-comfyui`
  precedent; upstream ships no runtime image. Traefik/DNS story omitted —
  tailnet-only by decision (`HOST=<tailscale ip>`).
- **Single-workspace execution** — all stories land on
  `levonk/20261116-imagination-studio` in this Orca worktree (postiz
  precedent): files are mostly disjoint, change set is one feature.
- **No vault handoff** — HF auth already persisted under `lk` on kckinai
  (verified). Access key auto-generates in STUDIO_HOME at first run.
- **Live deployment is NOT in these stories** — code + validation only.
  Actual `ansible-playbook` runs and the ~423 GB model download are
  orchestrator Phase 5 (user-gated host mutation).
- **Template**: `ai-comfyui` role + `deploy-comfyui.yml` +
  `bootstrap-ai-inference-host.yml` are the canonical precedents;
  `postiz-deployment` feature is the workflow precedent.
- **Phase ordering**: 02 → 03 → 04 → 05 (serial).

## Status Legend

- `[ ]` Todo
- `[~]` In-Progress
- `[x]` Done
- `[!]` Blocked
