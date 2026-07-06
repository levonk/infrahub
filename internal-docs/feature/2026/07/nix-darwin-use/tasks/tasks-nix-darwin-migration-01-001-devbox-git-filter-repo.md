---
story_id: "01-001"
story_title: "Add git-filter-repo to devbox.json"
story_name: "devbox-git-filter-repo"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 1
parallel_id: 1
branch: "feature/current/nix-darwin-migration/story-01-001-devbox-git-filter-repo"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrahub/devbox.json"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "infra", "devbox"]
due: "2026-07-13"
created_at: "2026-07-06"
updated_at: "2026-07-06"
---

## Summary

Add `git-filter-repo` to infrahub's `devbox.json` packages so the cross-repo history move (story 02-001) can run via `devbox run git filter-repo`. User preference: when a tool is needed, always update `devbox.json` rather than using external tools or system installs.

## Current State

- **Relevant files and their roles:**
  - `devbox.json` — infrahub's devbox environment definition. Contains a `packages` object mapping nixpkgs package names to version strings (empty string = latest). Currently has ~70 packages (git, gh, ansible, helm, etc.) but no `git-filter-repo`.
  - `devbox.lock` — auto-generated lock file. Regenerated when `devbox.json` changes.
- **Existing code excerpts:**
  ```json
  // devbox.json (lines 1-5)
  {
    "_bug_note": "DEVBOX SCRIPT GENERATION BUG: ...",
    "packages": {
      "git": "",
      "gh": "",
      ...
    }
  }
  ```
- **Repository conventions:**
  - Package entries use empty string `""` for latest version (see existing entries like `"git": ""`, `"gh": ""`).
  - `git-filter-repo` is available in nixpkgs as `git-filter-repo` (Python-based git history rewriting tool).
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Devbox update | `devbox update` | regenerates devbox.lock, exit 0 |
  | Verify package | `devbox run -- command -v git-filter-repo` | found |
  | Justfile still works | `devbox run -- just --list` | lists recipes |

## Scope

**In scope:**
- Add `"git-filter-repo": ""` to the `packages` object in `devbox.json`
- Run `devbox update` (or `devbox install`) to regenerate `devbox.lock`

**Out of scope:**
- Running git-filter-repo (that's story 02-001)
- Any other devbox.json changes
- Any playbook or flake changes

## Sub-Tasks

- [x] Task 1 — Add git-filter-repo to devbox.json packages
  Add `"git-filter-repo": ""` to the `packages` object in `devbox.json`, placed alphabetically near `git-filter-repo`'s neighbors (after `git`, before `github-to-sops` or wherever it sorts).
  **Verify**: `rg "git-filter-repo" devbox.json` → one match in the packages block
  **Likely failure**: `git-filter-repo` not found in nixpkgs under that name — **cause**: wrong package name — **fallback**: search via `nix search nixpkgs git-filter-repo` for the exact attribute name; it may be `git-filter-repo` or `python312Packages.git-filter-repo`
  **Decision fork**: If `nix search nixpkgs git-filter-repo` returns no results → use `python313Packages.git-filter-repo` (infrahub uses python313) instead and document the choice with a `ponytail:` comment

- [x] Task 2 — Regenerate devbox.lock
  Run `devbox update` (or `devbox install`) to pull the new package and update the lock file.
  **Verify**: `devbox run -- command -v git-filter-repo` → path printed (e.g., `/nix/store/.../bin/git-filter-repo`)
  **Likely failure**: `devbox update` fails with a hash mismatch or build error — **cause**: nixpkgs unstable roll — **fallback**: pin to a specific nixpkgs revision or use `devbox install --no-refresh` to use cached nixpkgs

- [x] Task 3 — Verify justfile still works
  Ensure adding the package didn't break the devbox environment for existing `just` commands.
  **Verify**: `devbox run -- just --list` → lists all recipes including `ansible-bootstrap-macos`
  **Likely failure**: `just` not found after devbox update — **cause**: devbox environment corruption — **fallback**: `devbox shell` then `just --list`; if still broken, `rm -rf .devbox && devbox install` (rebuild env from scratch)

## Relevant Files

- `devbox.json` — add the package entry
- `devbox.lock` — auto-regenerated, commit the updated lock

## Acceptance Criteria

- [x] `rg "git-filter-repo" devbox.json` returns one match in the packages block
- [x] `devbox run -- command -v git-filter-repo` succeeds (prints a path)
- [x] `devbox run -- just --list` still lists all existing recipes
- [x] `devbox.lock` is updated and committed alongside `devbox.json`

## Test Plan

- Manual: `devbox run -- git filter-repo --version` prints version info
- Manual: `devbox run -- just --list` lists all recipes (no regression)

## Observability

- N/A (infrastructure tooling, no runtime observability)

## Compliance

- N/A

## Risks & Mitigations

- Risk: `git-filter-repo` package name differs in nixpkgs — Mitigation: `nix search nixpkgs git-filter-repo` to confirm exact attribute name before adding

## Failure Modes & Decision Forks

- **Failure mode**: `devbox update` fails — **cause**: nixpkgs unstable roll or hash mismatch — **fallback**: pin nixpkgs or use `--no-refresh`
- **Decision fork**: If `nix search nixpkgs git-filter-repo` returns no results → use `python313Packages.git-filter-repo` and add a `ponytail:` comment noting the alternative name

## Dependencies & Sequencing

- Depends on: None
- Unblocks:
  - story-02-001-cross-repo-move (needs git-filter-repo available in devbox)

## Definition of Done

- [x] All verification commands from sub-tasks pass
- [x] `devbox.json` and `devbox.lock` committed
- [x] No files outside `devbox.json` and `devbox.lock` are modified (`git status`)

## STOP Conditions

Stop and report if:
- `git-filter-repo` is not available in nixpkgs under any name (`nix search` returns nothing)
- `devbox update` fails and `--no-refresh` also fails
- Adding the package breaks `just` commands (existing recipes no longer list)

### Decision Forks (Contingency Paths)
- If `nix search nixpkgs git-filter-repo` returns no results → use `python313Packages.git-filter-repo` instead
- If `devbox update` fails with hash mismatch → try `devbox install --no-refresh`; if that fails, stop and report

## Maintenance Notes

- `git-filter-repo` is only needed for the one-time cross-repo move (story 02-001). It can be removed from `devbox.json` after that story completes if desired, but keeping it is harmless.
- Reviewers: confirm the package name matches nixpkgs and the lock file is regenerated.

## Commit Conventions

- `feat(devbox): add git-filter-repo for cross-repo history move`

## Changelog

- 2026-07-06: initialized story file
- 2026-07-06: completed all sub-tasks, verified acceptance criteria, marked story done
