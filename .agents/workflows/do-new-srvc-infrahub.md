---
workflow: "Add New Service to Infrahub"
slug: "do-new-srvc-infrahub"
description: "Orchestrate adding a new service end-to-end: research, plan, implement, test, deploy, test again, and document. Delegates the generic PRD → tasks → execute pipeline to the execute-upsert skill, and implementation detail to infrahub-add-new-service.md."
use: "When adding a new service, ansible deployment, etc. for all clients in shared/active/"
date:
  created: "2026-07-08"
  updated: "2026-07-11"
  last-used: "2026-07-11"
see-also:
  - skill: "execute-upsert"
    relationship: "pipeline-controller"
    description: "Generic project execution controller that drives PRD → tasks → execute → document. This workflow delegates the implementation pipeline to it. Install from levonk/skills-releases via `npx skills add levonk/skills-releases --skill execute-upsert` (or `just skills-bootstrap`)."
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

- Read `AGENTS.md`.
- Read `AGENTS.md` for the client you're deploying for
- If the user didn't specify the service, ask which service to add.
- If the user didn't specify which machine(s) to deploy to, ask.

## Phase 2: Research

- Launch subagents to research the requested service(s) first to find out if
  there are better ones that should be considered before moving forward with
  that one. Don't do this if the user asks you not to. Write the research to
  `internal-docs/research/service/{service-name-kebab-case}/` (create the
  directory if it doesn't exist).
- When comparing multiple candidate tools/services, use the `project-comparison`
  skill (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/project-comparison/SKILL.md`)
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
  (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/code-quality-validation/SKILL.md`)
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

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/do-new-srvc-infrahub.md`
- **Implementation detail**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`
- **Git state workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-git.md`
- **Pipeline controller skill**: `execute-upsert` (installed via `just skills-bootstrap` from `levonk/skills-releases`)
- **Project comparison skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/project-comparison/SKILL.md`
- **Container image build skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/container-image-build/SKILL.md`
- **Container service deploy skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/container-service-deploy/SKILL.md`
- **Infrahub container deploy skill**: `~/p/gh/levonk/infrahub/.agents/skills/devops/infrahub-container-deploy/SKILL.md`
- **Code quality validation skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/code-quality-validation/SKILL.md`
- **Research output**: `~/p/gh/levonk/infrahub/internal-docs/research/service/{service-name-kebab-case}/`
- **PRD output**: `internal-docs/feature/YYYY/MM/{slug}/` (created by execute-upsert)
- **Task output**: `internal-docs/feature/YYYY/MM/{slug}/tasks/` (created by execute-upsert)

### Project Info

See `AGENTS.md` (environment, vault, deployment) and `developer.md` (devbox/rtk, key directories, boundaries, known gotchas).
