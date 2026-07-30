---
workflow: "Add New Service to Infrahub"
slug: "infrahub-add-new-service-orchestrator"
description: "Orchestrate adding a new service end-to-end: research, plan, implement, test, deploy, test again, and document. Delegates the generic PRD → tasks → execute pipeline to the execute-upsert skill, and implementation detail to infrahub-add-new-service.md."
use: "When adding a new service, ansible deployment, etc. for all clients in shared/active/"
date:
  created: "2026-07-08"
  knowledge-basis: "2026-07-20"
  last-used: "2026-07-29"
see-also:
  - skill: "execute-upsert"
    relationship: "pipeline-controller"
    description: "Generic project execution controller that drives PRD → tasks → execute → document. This workflow delegates the implementation pipeline to it. Install from levonk/skills-releases via `devbox run -- pnpm dlx skills add levonk/skills-releases --skill execute-upsert` (or `just skills-bootstrap`)."
  - file: "infrahub-add-new-service.md"
    relationship: "implementation-detail"
    description: "Phase-by-phase implementation guide (Phases 1-8: shared role, client infra, vault, Traefik, build pipeline, playbook). Task stories created by execute-upsert should reference this guide for infrahub-specific implementation steps."
  - skill: "project-comparison"
    relationship: "research"
    description: "Compare multiple candidate services/projects with category discovery, coverage mapping, feature matrix, and maintainability scoring. Used in Phase 2 when evaluating alternatives."
  - skill: "container-image-build"
    relationship: "implementation"
    description: "Build container images for mixed-architecture fleets. Three branches: pre-built upstream, Dockerfile+buildx, Nix flake. Used when the service needs a locally-built image."
  - skill: "container-service-deploy"
    relationship: "implementation"
    description: "Deploy multi-container services via compose (dev) or Ansible docker_container (prod). Used during implementation and deployment phases."
  - skill: "infrahub-container-deploy"
    relationship: "implementation"
    description: "Infrahub-specific overlay for container deployment: userns-remap UID 100000, vault handoff, infra_ variable naming, functional-group role naming, local registry."
  - skill: "code-quality-validation"
    relationship: "testing"
    description: "Comprehensive code quality validation (lint, format, test, security scan). Used in Phase 4 to validate before deploying."
---

# Workflow: Add a New Service to Infrahub

Orchestrate adding a new service end-to-end: research, plan, implement, test,
deploy, test deployment, and document.

This workflow is the **infrahub-specific shell** around the generic
`execute-upsert` skill. It handles the parts that are unique to infrahub
(service research, Ansible testing, deployment, deployment verification) and
delegates the generic pipeline (PRD creation, task breakdown, subagent
execution, commit checkpoints, documentation updates) to `execute-upsert`.

For the detailed implementation phases (shared role, client infrastructure
values, vault secrets, Traefik routing, build pipeline, deployment), see
[`infrahub-add-new-service.md`](infrahub-add-new-service.md). Task stories
created by `execute-upsert` should reference that guide for infrahub-specific
implementation steps.

## Prerequisites

- The `execute-upsert` skill must be installed. Run `just skills-bootstrap` if
  it is not (installs from `levonk/skills-releases`).
- Read `AGENTS.md` — especially "Architectural Invariants", "Per-Client Centralized
  Files", devbox usage rules, and vault handoff policy.
- All shell interaction with tools (ansible, docker, etc.) MUST use:
  `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {COMMAND}`
- Vault edits are agent → user handoff only. See AGENTS.md "Vault Edits (Agent →
  User Handoff)" — never edit the vault directly.

## Phase 1: Initialize

- Run the `infrahub-git` workflow (`.agents/workflows/infrahub-git.md`) to checkpoint
  the starting tree state. It wraps the `git-repository-management` skill for the
  infrahub project and all client submodules.
- Read `AGENTS.md`.
- Read `AGENTS.md` for the client you're deploying for
- If the user didn't specify the service, ask which service to add.
- If the user didn't specify which machine(s) to deploy to, ask.

### Resume Detection (run before anything else)

This workflow is frequently **resumed** after a prior session. Before doing
any research or planning, detect existing state and skip phases that are
already complete. Do NOT re-execute completed work.

1. **Check for an existing PRD + task index** under
   `internal-docs/feature/YYYY/MM/*/{slug}/`. If a PRD exists AND a task
   index exists at `tasks/index-{slug}.md`:
   - Read the task index **Status** column for every story. The index uses
     `[ ] Todo`, `[~] In-Progress`, `[x] Done`, `[!] Blocked`.
   - Resume at **Phase 4 (Test)** if all stories are `[x] Done` or `[!] Blocked`.
   - Resume at **Phase 3 (Execute Pipeline)** if any story is still
     `[ ] Todo` or `[~] In-Progress` — `execute-upsert` will skip the
     `[x] Done` stories automatically.
   - **Never** re-dispatch a subagent for a story marked `[x] Done` unless
     the user explicitly asks to redo it.

2. **Check for existing story branches / worktrees** before dispatching any
   subagent. Stories are developed on branches named
   `feature/current/{slug}/story-{NN-NNN}-{story-name}`. Run:
   ```bash
   git worktree list
   git branch --list "feature/current/{slug}/story-*"
   ```
   If a story branch already exists and the index marks it `[x] Done`, the
   work is on that branch — switch to the most advanced story branch
   (the one with the highest story ID that is `[x] Done`) and resume from
   there. Do not re-create the branch or re-run the story.

3. **Check for an existing research directory** at
   `internal-docs/research/service/{service-name-kebab-case}/`. If it exists
   and is non-empty, skip Phase 2 (Research) unless the user asks to redo it.

4. **Check the current git branch**. If it is a story branch or a planning
   branch for this slug, you are mid-execution — read the task index to
   determine where to resume, do not start from Phase 1.

If no PRD, no task index, and no research directory exist, this is a fresh
run — proceed to Phase 2 (Research).

## Phase 2: Research

**Skip this phase entirely if** `internal-docs/research/service/{service-name-kebab-case}/`
already exists and is non-empty (detected in Phase 1 Resume Detection), unless
the user explicitly asks to redo research.

- Launch subagents to research the requested service(s) first to find out if
  there are better ones that should be considered before moving forward with
  that one. Don't do this if the user asks you not to. Write the research to
  `internal-docs/research/service/{service-name-kebab-case}/` (create the
  directory if it doesn't exist).
- When comparing multiple candidate tools/services, use the `project-comparison`
  skill (`~/p/gh/levonk/skills-src/build/current/skills/software-dev/project-comparison/SKILL.md`,
  or install via `devbox run -- pnpm dlx skills add levonk/skills-releases --skill project-comparison`;
  published at https://github.com/levonk/skills-releases)
  for category discovery, coverage mapping, feature matrix, and maintainability
  scoring. Launch a subagent to run the comparison and present the matrix to the
  user for a decision. (The skill includes the feature-matrix template.)
- Launch a subagent to read the documentation about the service off the web or a
  recent checkout in source control. Add the doc to the research directory.
- Read all the information, come up with an initial plan, ask ANY questions
  necessary to understand the requirements, and revise the plan.
- If any path in these instructions is wrong, fix this file.

The research output in `internal-docs/research/service/` is the input to
`execute-upsert`'s PRD creation in Phase 3. Make sure it is committed before
proceeding.

## Phase 3: Execute Pipeline (delegated to execute-upsert)

Delegate the implementation pipeline to the `execute-upsert` skill. It handles:

- **PRD creation** — if no PRD exists, creates one using the `greenfield-prd`
  workflow (feeds off the research from Phase 2)
- **Task breakdown** — breaks the PRD into parallelizable task stories using the
  `tasks-from-prd` workflow
- **Subagent execution** — dispatches one subagent per story via the
  `tasks-processor` workflow, chaining through the project
- **Commit checkpoints** — creates a git commit checkpoint before each subagent
  dispatch (replaces the old `git-repository-management` pre/post calls)
- **PRD updates during execution** — if scope changes, updates the PRD and
  regenerates affected task files
- **Documentation updates** — updates PRD, task files, and project-level
  documentation (README, API docs, architecture docs, AGENTS.md, CHANGELOG) as
  the final phase, with a final commit to leave the tree clean

### How to invoke

Run the `execute-upsert` skill with:
- **Goal**: Implement the new service feature end-to-end.
- **Context**: The research output from Phase 2
  (`internal-docs/research/service/{service-name-kebab-case}/`), the project's
  `AGENTS.md` path, and this workflow's implementation guide
  (`infrahub-add-new-service.md`).
- **Key instruction**: Task stories should reference
  `infrahub-add-new-service.md` for infrahub-specific implementation steps
  (shared role, client infrastructure values, vault secrets, Traefik routing,
  build pipeline, deployment). The `execute-upsert` subagents will read the
  project's `AGENTS.md` for devbox/rtk/vault conventions.

### What execute-upsert does NOT handle (stays in this workflow)

The following phases are infrahub-specific and run **after** `execute-upsert`
completes:
- Ansible syntax/check-mode testing (Phase 4)
- Deployment to the levonk client environment (Phase 5)
- Post-deployment verification via Traefik (Phase 6)
- Updating AGENTS.md with service-specific learnings (Phase 7)

## Phase 4: Test

- Test the implementation before deploying. Verify the service builds, the
  Ansible playbook runs cleanly against a test target, and the configuration
  is valid (e.g. `devbox run -- rtk ansible-playbook --syntax-check`,
  `--check`).
- Use the `code-quality-validation` skill
  (`~/p/gh/levonk/skills-src/build/current/skills/software-dev/code-quality-validation/SKILL.md`,
  or install via `devbox run -- pnpm dlx skills add levonk/skills-releases --skill code-quality-validation`;
  published at https://github.com/levonk/skills-releases)
  for comprehensive validation: linting, formatting, testing, and security
  scanning.
- Fix any failures before moving to deploy.

## Phase 5: Deploy

- Deploy to the levonk/ client environment.
- Update the documentation for both `shared/` and the client so it exposes a
  central inventory.

## Phase 6: Verify

- Test again after deployment: confirm the service is running and reachable
  through Traefik on the target machine(s), nothing concerning in logs, no restart loops, service responds.

## Phase 7: Deliver

- If there are any learnings that would save time implementing new services that
  are worth adding to any of the `AGENTS.md` files, make the updates concisely.
- Commit any remaining work. The `execute-upsert` skill handles commit
  checkpoints during execution and a final documentation commit, but
  post-execution work (deployment, verification, AGENTS.md learnings from
  Phases 4–7) may have left the tree dirty. Commit it:
  ```bash
  git add <files>
  git commit -m "docs: update AGENTS.md with service learnings" -m "<body>"
  ```
  If the `git-repository-management` skill is installed, use its
  `git-commit-batch.sh` for structured commits.
- Run the `infrahub-git` workflow a final time to checkpoint the
  completed tree state.

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service-orchestrator.md`
- **Implementation detail**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`
- **Git state workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-git.md` (wraps `git-repository-management` skill for infrahub + submodules)
- **Pipeline controller skill**: `execute-upsert` (install via `devbox run -- pnpm dlx skills add levonk/skills-releases --skill execute-upsert`, or `just skills-bootstrap`; published at https://github.com/levonk/skills-releases)
- **Project comparison skill**: `~/p/gh/levonk/skills-src/build/current/skills/software-dev/project-comparison/SKILL.md` (fallback: https://github.com/levonk/skills-releases)
- **Container image build skill**: `~/p/gh/levonk/skills-src/build/current/skills/software-dev/container-image-build/SKILL.md` (fallback: https://github.com/levonk/skills-releases)
- **Container service deploy skill**: `~/p/gh/levonk/skills-src/build/current/skills/software-dev/container-service-deploy/SKILL.md` (fallback: https://github.com/levonk/skills-releases)
- **Infrahub container deploy skill**: `~/p/gh/levonk/infrahub/.agents/skills/devops/infrahub-container-deploy/SKILL.md`
- **Code quality validation skill**: `~/p/gh/levonk/skills-src/build/current/skills/software-dev/code-quality-validation/SKILL.md` (fallback: https://github.com/levonk/skills-releases)
- **Research output**: `~/p/gh/levonk/infrahub/internal-docs/research/service/{service-name-kebab-case}/`
- **PRD output**: `internal-docs/feature/YYYY/MM/{slug}/` (created by execute-upsert)
- **Task output**: `internal-docs/feature/YYYY/MM/{slug}/tasks/` (created by execute-upsert)

### Project Info

See `AGENTS.md` (environment, vault, deployment) and `.agents/knowledge/developer.md` (devbox/rtk, key directories, boundaries, known gotchas).
