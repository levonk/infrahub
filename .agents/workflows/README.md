Three workflows — two for the service pipeline, one for sandboxed CLI tools:

## When to use which

| You want to… | Start with |
|---|---|
| Add a new service end-to-end (research, plan, implement, deploy, verify) and you want the agent to drive the whole lifecycle | `infrahub-add-new-service-orchestrator.md` |
| Just implement the deployment artifacts (shared role, client infra values, vault handoff, Traefik routing, build pipeline, playbook) for a service you've already researched and planned — a one-shot add with no PRD/task breakdown | `infrahub-add-new-service.md` directly |
| Resume a prior service-add session that was interrupted | `infrahub-add-new-service-orchestrator.md` — its Phase 1 "Resume Detection" skips completed work |
| Add a sandboxed CLI tool (sherlock, subfinder, recon tools, scrapers) that needs egress-controlled network access via iron-proxy | `infrahub-add-sandboxed-cli-tool.md` |

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

## `infrahub-add-sandboxed-cli-tool.md` — sandboxed CLI tools

A separate workflow for a separate class of container usage: **ephemeral CLI
tools** (sherlock, subfinder, recon tools, scrapers) that need egress-controlled
network access via iron-proxy. These are not server services — they run, produce
output to stdout, and exit.

- **Phase 1-3**: Egress profile + iron-proxy allowlist (only if new profile needed)
- **Phase 4**: `just` recipe creation (the primary interface — `docker run --rm -it`)
- **Phase 5**: Tool catalog registration (`tools.yml` → `TOOLS.md`)
- **Phase 6**: Documentation

No orchestrator variant — CLI tools are simpler than server services and do not
require the full research/PRD/deploy/verify pipeline. The architecture is
defined by
[ADR-202608051501](../../shared/active/08-docs/adr/adr-202608051501-sandboxed-cli-egress.md).
<ref_file file="/Users/micro/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-sandboxed-cli-tool.md" />

### How it relates to the service workflow

```
infrahub-add-new-service-orchestrator.md  (service lifecycle: research/plan/test/deploy/verify)
        │
        │  delegates implementation
        ▼
infrahub-add-new-service.md  (service Phases 1-8: schemas, vault, role, Traefik, playbook)

infrahub-add-sandboxed-cli-tool.md  (CLI tool Phases 1-6: egress profile, allowlist, just recipe, tools.yml)
```

The two pipelines are independent — services go to `SERVICES.md`, CLI tools go
to `TOOLS.md`. The sandboxed CLI workflow deploys an iron-proxy instance (via
the `sandbox-cli-proxy` Ansible role) but the CLI tools themselves are not
Ansible-managed containers; they are `just` recipe invocations of `docker run`.
