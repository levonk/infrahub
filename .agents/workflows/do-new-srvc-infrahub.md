---
workflow: "Add New Service to Infrahub"
slug: "do-new-srvc-infrahub"
description: "Orchestrate adding a new service end-to-end: research, plan, implement, test, deploy, test again, and document. Delegates implementation detail to infrahub-add-new-service.md and task execution to do-proj-infrahub.md."
use: "When adding a new service, ansible deployment, etc. for all clients in shared/active/"
date:
  created: "2026-07-08"
  updated: "2026-07-08"
  last-used: "2026-07-08"
see-also:
  - file: "infrahub-add-new-service.md"
    relationship: "implementation-detail"
    description: "Detailed phase-by-phase implementation guide (shared role, client infra, vault, Traefik, build pipeline, deployment). This workflow orchestrates; that file executes."
  - file: "do-proj-infrahub.md"
    relationship: "next-step"
    description: "Controller workflow that drives task-by-task implementation via subagents. Called after planning is complete."
---

# Workflow: Add a New Service to Infrahub

Orchestrate adding a new service end-to-end: research, plan, implement, test, deploy, test deployment, and document.
For the detailed implementation phases (shared role, client infrastructure values,
vault secrets, Traefik routing, build pipeline, deployment), see
[`infrahub-add-new-service.md`](infrahub-add-new-service.md).

## Prerequisites

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

## Phase 2: Plan

- Launch subagents to research the requested service(s) first to find out if there
  are better ones that should be considered before moving forward with that one.
  Don't do this if the user asks you not to. Write the research to
  `internal-docs/research/service/{service-name-kebab-case}/` (create the directory
  if it doesn't exist).
- When comparing multiple candidate tools/services, use the feature-matrix template
  at `~/p/gh/levonk/skills-src/src/current/rules/general-ai/feature-matrix.md.tmpl`
  to visualize differences. Launch a subagent to fill in the template with the
  research findings and present the matrix to the user for a decision.
- Launch a subagent to read the documentation about the service off the web or a
  recent checkout in source control. Add the doc to the research directory.
- Read all the information, come up with an initial plan, ask ANY questions
  necessary to understand the requirements, and revise the plan.
- If this is a large project (instead of a one-shot) that warrants a full feature
  doc, task breakdown, and incremental development, generate a PRD using
  `~/p/gh/levonk/skills-src/src/current/workflows/software-dev/greenfield/greenfield-prd.md`.
- Use a subagent to break the PRD into tasks using the workflow in
  `~/p/gh/levonk/skills-src/src/current/workflows/software-dev/tasks/tasks-from-prd.md`.
- If any path in these instructions is wrong, fix this file.

## Phase 3: Implement

- Before implementation, run the `git-repository-management` skill
  (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/git-repository-management/SKILL.md`)
  to save documentation and pre-update state.
- Run `.agents/workflows/do-proj-infrahub.md` with this feature to implement it.

## Phase 4: Test

- Test the implementation before deploying. Verify the service builds, the
  Ansible playbook runs cleanly against a test target, and the configuration
  is valid (e.g. `devbox run -- rtk ansible-playbook --syntax-check`,
  `--check`).
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
- Run the `git-repository-management` skill
  (`~/p/gh/levonk/skills-src/src/current/skills/software-dev/git-repository-management/SKILL.md`)
  to save implementation and post-update state.

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/do-new-srvc-infrahub.md`
- **Implementation detail**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-add-new-service.md`
- **Task controller**: `~/p/gh/levonk/infrahub/.agents/workflows/do-proj-infrahub.md`
- **PRD generation**: `~/p/gh/levonk/skills-src/src/current/workflows/software-dev/greenfield/greenfield-prd.md`
- **Task breakdown**: `~/p/gh/levonk/skills-src/src/current/workflows/software-dev/tasks/tasks-from-prd.md`
- **Git management skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/git-repository-management/SKILL.md`
- **Feature comparison template**: `~/p/gh/levonk/skills-src/src/current/rules/general-ai/feature-matrix.md.tmpl`
- **Research output**: `~/p/gh/levonk/infrahub/internal-docs/research/service/{service-name-kebab-case}/`
- **Project AGENTS.md**: `~/p/gh/levonk/infrahub/AGENTS.md`

### Project Info

- Client git submodule: `~/p/gh/levonk/infrahub/levonk`
- Shared playbooks: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/`
- All tool invocations: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {COMMAND}`
- Vault password file: `~/.ansible/vault_password`
