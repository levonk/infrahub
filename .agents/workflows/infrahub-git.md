---
workflow: "Git Repository Management for Infrahub"
slug: "infrahub-git"
description: "Run the git-repository-management skill on the infrahub project and all client submodules to save documentation and state snapshots."
use: "When needing to save pre-update or post-update git state across the infrahub project and its client submodules"
date:
  created: "2026-06-24"
  updated: "2026-07-08"
  last-used: "2026-07-14"
see-also:
  - skill: "git-repository-management"
    relationship: "implementation"
    description: "The skill that this workflow runs on the infrahub project and submodules."
---

# Workflow: Git Repository Management for Infrahub

Run the `git-repository-management` skill on the infrahub project and all client
submodules.

Skill path: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/git-repository-management/SKILL.md`

## CRITICAL: Read AGENTS.md Before Proceeding

**Before running this workflow, you MUST read the AGENTS.md file in the repository root.**

AGENTS.md contains critical rules about:
- Submodule handling (NEVER convert submodules to regular directories)
- Secret storage locations (per ADR-20260624001)
- Security requirements and ADR compliance
- Client-specific isolation requirements

**Each client submodule (e.g., `levonk/`) also has its own AGENTS.md with client-specific rules.**

Failure to follow these rules can result in:
- Exposed sensitive information
- Broken architecture
- Security violations
- Loss of client isolation

## Context Declaration

### File Paths

- **This workflow**: `~/p/gh/levonk/infrahub/.agents/workflows/infrahub-git.md`
- **Git management skill**: `~/p/gh/levonk/skills-src/src/current/skills/software-dev/git-repository-management/SKILL.md`

### Project Info

See `AGENTS.md` (environment, vault, submodule rules) and `developer.md` (devbox/rtk, key directories, boundaries).
