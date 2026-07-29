Two files, two different roles in the same pipeline:

## When to use which

| You want to… | Start with |
|---|---|
| Add a new service end-to-end (research, plan, implement, deploy, verify) and you want the agent to drive the whole lifecycle | `infrahub-add-new-service-orchestrator.md` |
| Just implement the deployment artifacts (shared role, client infra values, vault handoff, Traefik routing, build pipeline, playbook) for a service you've already researched and planned — a one-shot add with no PRD/task breakdown | `infrahub-add-new-service.md` directly |
| Resume a prior service-add session that was interrupted | `infrahub-add-new-service-orchestrator.md` — its Phase 1 "Resume Detection" skips completed work |

**Rule of thumb**: if you're typing a fresh "add service X" prompt into a new session, start with the orchestrator. If you're doing a quick one-shot implementation without the full research/PRD pipeline, jump to `infrahub-add-new-service.md`.

## `infrahub-add-new-service-orchestrator.md` — orchestrator

Owns the **full lifecycle** for a new service: research → plan → implement → test → deploy → verify → deliver. It's the "infrahub-specific shell" around the generic `execute-upsert` skill, with `git-repository-management` checkpoints at the start (Phase 1) and end (Phase 7).

- **Phase 1**: Initialize (read AGENTS.md, ask service + machines) + `git-repository-management` checkpoint + resume detection (skips already-done work)
- **Phase 2**: Research (subagents, `project-comparison` skill)
- **Phase 3**: Delegates PRD → tasks → subagent execution → commit checkpoints to the `execute-upsert` skill
- **Phases 4–7**: Infrahub-specific tail — Ansible syntax/check-mode testing, deploy to `levonk/`, verify via Traefik, update `AGENTS.md` with learnings, final `git-repository-management` checkpoint

It does **not** contain the actual implementation steps — it delegates those to the implementation guide. <ref_file file="/Users/micro/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service-orchestrator.md" />

## `infrahub-add-new-service.md` — implementation guide

The hands-on, phase-by-phase technical recipe (Phases 1–8 only):
1. Shared infrastructure schemas (`ports.yml`, `networks.yml`, `domains.yml`, `storage.yml`)
2. Client infrastructure values (`levonk/active/...`)
3. Build pipeline (Dockerfile, `build-and-push-images.sh`, registry) — skipped for upstream images
4. Vault secrets (agent → user handoff, never edit directly)
5. Ansible role creation (defaults/tasks/handlers, `infra_` variable naming, userns-remap)
6. Traefik routing
7. Playbook + inventory wiring
8. Documentation

It explicitly says: "Phases 1-8 only — orchestrator owns test/deploy/verify/commit." <ref_file file="/Users/micro/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md" />

## How they relate

```
infrahub-add-new-service-orchestrator.md  (lifecycle: research/plan/test/deploy/verify + git checkpoints)
        │
        │  delegates implementation
        ▼
infrahub-add-new-service.md  (Phases 1-8: schemas, vault, role, Traefik, playbook)
```

The split exists so the orchestrator can be reused for any service while the implementation guide holds the concrete infrahub file paths and conventions.
