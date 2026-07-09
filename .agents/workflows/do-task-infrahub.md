---
workflow: "Task Executor for Infrahub"
slug: "do-task-infrahub"
description: "Per-task execution workflow run by a subagent. Reads AGENTS.md, sets up the devbox environment, and runs the tasks-processor workflow on a specific task directory."
use: "When a subagent needs to execute a single task from a task breakdown — launched by do-proj-infrahub.md"
date:
  created: "2026-06-30"
  updated: "2026-07-08"
  last-used: "2026-07-08"
see-also:
  - file: "do-proj-infrahub.md"
    relationship: "controller"
    description: "Controller workflow that launches this task executor as subagents, one per task."
  - file: "infrahub-add-new-service.md"
    relationship: "implementation-detail"
    description: "Detailed phase-by-phase service implementation guide. Referenced when the task involves adding a new service."
---

# Workflow: Task Executor for Infrahub

Per-task execution workflow. Run this on a single task directory.

## Prerequisites

- Read `~/p/gh/levonk/infrahub/AGENTS.md`
- The client git submodule is `~/p/gh/levonk/infrahub/levonk`
- Shared playbooks are deployed at `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/` on Tailscale
- Tailscale is working
- All shell interaction with tools (ansible, ls, docker, etc.) MUST use:
  `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {YOUR COMMAND HERE}`

## Phase 1: Apply

RUN, DON'T JUST READ the tasks-processor workflow on the task directory:
`~/p/gh/levonk/skills-src/src/current/workflows/software-dev/tasks/tasks-processor.md`

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/do-task-infrahub.md`
- **Tasks processor**: `~/p/gh/levonk/skills-src/src/current/workflows/software-dev/tasks/tasks-processor.md`
- **Project AGENTS.md**: `~/p/gh/levonk/infrahub/AGENTS.md`
- **Task directory**: `~/p/gh/levonk/infrahub/internal-docs/feature/{year}/{month}/{feature}/tasks/` (passed by the controller)

### Project Info

- Client git submodule: `~/p/gh/levonk/infrahub/levonk`
- Shared playbooks: `~/p/gh/levonk/infrahub/shared/active/02-config/ansible/playbooks/`
- All tool invocations: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {COMMAND}`
- Vault password file: `~/.ansible/vault_password`
