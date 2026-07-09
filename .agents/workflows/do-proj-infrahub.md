---
workflow: "Project Controller for Infrahub"
slug: "do-proj-infrahub"
description: "Controller agent that drives task-by-task implementation via subagents. Does not do work itself — delegates each task to do-task-infrahub.md and chains through the project."
use: "When implementing a planned project task-by-task via subagents, chaining completed tasks to the next unblocked one"
date:
  created: "2026-06-30"
  updated: "2026-07-08"
  last-used: "2026-07-08"
see-also:
  - file: "do-task-infrahub.md"
    relationship: "task-executor"
    description: "Per-task workflow that each subagent runs. The controller launches one of these per task."
  - file: "do-new-srvc-infrahub.md"
    relationship: "caller"
    description: "Service-adding orchestration workflow that calls this controller after planning is complete."
---

# Workflow: Project Controller for Infrahub

You're a controller agent — you do NOT do the work yourself. You launch a subagent
for each task, chain to the next when complete, and track blocked dependencies.

## Phase 1: Initialize

- Read `AGENTS.md`.
- Read `AGENTS.md` for whatever client you're deploying to
- Identify the task list (typically under `internal-docs/feature/{year}/{month}/{feature}/tasks/`).
- If the tasks directory is missing create the tasks with a subagent  using ~/p/gh/levonk/skills-src/src/current/workflows/software-dev/tasks/tasks-from-prd.md

## Phase 2: Apply (Loop)

For each task that isn't completed yet:

1. Launch a subagent using a prompt based on
   [`do-task-infrahub.md`](do-task-infrahub.md) for the next uncompleted task.
2. When it completes, launch the next subagent for the next task.
3. If something needs human involvement, list it as blocked and move on to the
   next task that doesn't have blocked dependencies.

Work through the entire project.

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/do-proj-infrahub.md`
- **Task executor**: `~/p/gh/levonk/infrahub/.agents/workflows/do-task-infrahub.md`
- **Project AGENTS.md**: `~/p/gh/levonk/infrahub/AGENTS.md`
- **Task lists**: `~/p/gh/levonk/infrahub/internal-docs/feature/{year}/{month}/{feature}/tasks/`

### Project Info

- Client git submodule: `~/p/gh/levonk/infrahub/levonk`
- All tool invocations: `cd ~/p/gh/levonk/infrahub && devbox run -- rtk {COMMAND}`
