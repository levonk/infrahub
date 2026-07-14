---
story_id: "02-001"
story_title: "Cross-repo history move + retire levonk-nix-config darwin"
story_name: "cross-repo-move"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 2
parallel_id: 1
branch: "feature/current/nix-darwin-migration/story-02-001-cross-repo-move"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: false
modules: ["levonk-nix-config/", "infrahub/shared/active/02-config/nix/darwin/"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "git", "cross-repo", "nix"]
due: "2026-07-20"
created_at: "2026-07-06"
updated_at: "2026-07-14"
---

## Summary

Use `git filter-repo` (added to devbox in 01-001) to move the darwin system modules from `levonk-nix-config` into `infrahub` with git history retained. Then retire `levonk-nix-config`'s darwin hosts and darwin-specific modules: delete `darwinConfigurations.mac-aarch64` and `mac-x86_64`, delete host files, remove the `nix-darwin` flake input. The fresh modules authored in 01-002 are replaced by the history-retained versions. Linux home-manager configs (wsl-dev, debian-remote, etc.) are untouched.

## Current State

- **Relevant files and their roles:**
  - `levonk-nix-config/flake.nix` — has `nix-darwin` input (line 7) and `darwinConfigurations.mac-aarch64` (lines 62-67), `darwinConfigurations.mac-x86_64` (lines 69-74). To be edited: remove darwin input + darwinConfigurations.
  - `levonk-nix-config/hosts/mac-aarch64/aarch64.nix` — darwin host config with home-manager. To be deleted.
  - `levonk-nix-config/hosts/mac-x86_64/x86_64.nix` — darwin host config with home-manager. To be deleted.
  - `levonk-nix-config/modules/system/darwin/defaults.nix` — system.defaults. To be moved (history) to infrahub.
  - `levonk-nix-config/modules/system/darwin/homebrew.nix` — homebrew module. To be moved (history) to infrahub.
  - `levonk-nix-config/modules/components/nix/settings.nix` — nix.settings. To be moved (history).
  - `levonk-nix-config/modules/components/nix/cache.nix` — substituters. To be moved (history).
  - `levonk-nix-config/modules/security/privacy-darwin.nix` — privacy defaults. To be moved (history) — BUT `baseline.nix` imports it (UNRESOLVED coupling).
  - `levonk-nix-config/modules/security/baseline.nix` — home-manager security module, imports `privacy-darwin.nix`. NOT moved (home-manager, out of scope). If privacy-darwin.nix is moved out, baseline.nix breaks.
  - `levonk-nix-config/modules/security/default.nix` — security profile option, imports baseline.nix. NOT moved.
  - `infrahub/shared/active/02-config/nix/darwin/` — fresh modules from 01-002. To be replaced by history-retained versions.
- **Existing code excerpts:**

  levonk-nix-config flake.nix darwin section (to remove):
  ```nix
  # lines 5-8
  nix-darwin.url = "github:LnL7/nix-darwin";
  nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

  # lines 62-74
  darwinConfigurations = {
    "mac-aarch64" = nix-darwin.lib.darwinSystem { ... };
    "mac-x86_64" = nix-darwin.lib.darwinSystem { ... };
  };
  ```

  baseline.nix imports privacy-darwin.nix (coupling):
  ```nix
  # levonk-nix-config/modules/security/baseline.nix (line 10)
  imports = [ ./privacy-darwin.nix ];
  ```

- **Repository conventions:**
  - `git filter-repo` runs on a FRESH CLONE of levonk-nix-config (not the working repo) to avoid rewriting the working repo's history
  - Within infrahub, `git mv` is used for file relocations (user instruction)
  - Cross-repo moves use `git filter-repo` to retain history (plain `cp` loses blame)
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | filter-repo available | `devbox run -- command -v git-filter-repo` | found (from 01-001) |
  | levonk-nix-config builds after darwin removal | `nix flake check ~/p/gh/levonk/levonk-nix-config` | exit 0 (Linux configs still build) |
  | infrahub flake builds after history merge | `nix flake check ./shared/active/02-config/nix/darwin` | exit 0 |
  | No darwinConfigurations in levonk-nix-config | `rg "darwinConfigurations" ~/p/gh/levonk/levonk-nix-config/flake.nix` | no matches |
  | Linux configs untouched | `ls ~/p/gh/levonk/levonk-nix-config/hosts/wsl-dev/default.nix` | exists |

## Scope

**In scope:**
- Clone levonk-nix-config to a temp dir, run `git filter-repo` to extract darwin module paths
- Merge the filtered history into infrahub, placing files at their final paths under `shared/active/02-config/nix/darwin/modules/`
- Replace the fresh modules from 01-002 with the history-retained versions (content should be identical — 01-002 already authored the correct content)
- Fix import paths in moved modules (FR-3)
- Delete `levonk-nix-config`'s `darwinConfigurations`, darwin host files, `nix-darwin` flake input
- Handle the `privacy-darwin.nix` coupling with `baseline.nix` (UNRESOLVED — see Decision Forks)

**Out of scope:**
- levonk-nix-config's Linux home-manager configs (untouched)
- levonk-nix-config's home-manager role/profile modules (untouched)
- Any Ansible or playbook changes (story 03-001)
- Any osx-settings.py changes (story 01-003)

## Sub-Tasks

- [ ] Task 1 — Clone levonk-nix-config to temp dir for filter-repo
  `git clone ~/p/gh/levonk/levonk-nix-config /tmp/levonk-nix-config-filter`
  **Verify**: `ls /tmp/levonk-nix-config-filter/flake.nix` → exists
  **Likely failure**: clone fails — **cause**: path wrong or repo dirty — **fallback**: use `git clone --mirror` or check the path

- [ ] Task 2 — Run git filter-repo to extract darwin module paths
  In the temp clone, run:
  ```
  devbox run -- git filter-repo --path modules/system/darwin/defaults.nix \
    --path modules/system/darwin/homebrew.nix \
    --path modules/components/nix/settings.nix \
    --path modules/components/nix/cache.nix \
    --path modules/security/privacy-darwin.nix
  ```
  This rewrites the clone's history to contain ONLY these files.
  **Verify**: `find /tmp/levonk-nix-config-filter -name "*.nix" -type f` → lists only the 5 extracted files
  **Likely failure**: filter-repo fails — **cause**: wrong path or filter-repo not installed — **fallback**: `devbox run -- git filter-repo --version` to confirm; check path names match exactly
  **Decision fork**: If `privacy-darwin.nix` coupling with `baseline.nix` means moving it breaks levonk-nix-config → COPY privacy-darwin.nix instead of moving it (keep a copy in levonk-nix-config for baseline.nix, move the canonical version to infrahub). See Task 6.

- [ ] Task 3 — Merge filtered history into infrahub
  Add the filtered clone as a remote in infrahub and merge:
  ```
  cd ~/p/gh/levonk/infrahub
  git remote add levonk-nix-filter /tmp/levonk-nix-config-filter
  git fetch levonk-nix-filter
  git merge --allow-unrelated-histories levonk-nix-filter/main --no-commit
  ```
  The files will appear at their original paths (`modules/system/darwin/defaults.nix`, etc.). Then `git mv` them to their final infrahub paths:
  ```
  git mv modules/system/darwin/defaults.nix shared/active/02-config/nix/darwin/modules/system/defaults.nix
  git mv modules/system/darwin/homebrew.nix shared/active/02-config/nix/darwin/modules/system/homebrew.nix
  git mv modules/components/nix/settings.nix shared/active/02-config/nix/darwin/modules/nix/settings.nix
  git mv modules/components/nix/cache.nix shared/active/02-config/nix/darwin/modules/nix/cache.nix
  git mv modules/security/privacy-darwin.nix shared/active/02-config/nix/darwin/modules/security/privacy-darwin.nix
  ```
  **Verify**: `git log --follow shared/active/02-config/nix/darwin/modules/system/defaults.nix` → shows commits from levonk-nix-config
  **Likely failure**: merge conflicts with the fresh files from 01-002 — **cause**: both 01-002 and the filter-repo created the same files — **fallback**: `git checkout --theirs shared/active/02-config/nix/darwin/modules/` to take the history-retained versions, then re-apply the 01-002 content changes (OS auto-install OFF, empty cask list) on top
  **Decision fork**: If the merge conflicts are too complex → skip the history merge, keep the 01-002 fresh files, and add a `ponytail:` comment noting the origin commits. History retention is nice-to-have, not a blocker.

- [ ] Task 4 — Re-apply 01-002 content changes to history-retained modules
  The filter-repo brings the ORIGINAL levonk-nix-config content. The 01-002 changes (OS auto-install OFF in defaults.nix, empty cask list in homebrew.nix) must be re-applied on top of the history-retained versions.
  - In `defaults.nix`: set `AutomaticallyInstallMacOSUpdates = false`, `ConfigDataInstall = false`, `CriticalUpdateInstall = false` (FR-6)
  - In `homebrew.nix`: set `casks = [ ]` (empty, FR-5), drop the personal cask list
  **Verify**: `rg "AutomaticallyInstallMacOSUpdates" shared/active/02-config/nix/darwin/modules/system/defaults.nix` → `false`
  **Likely failure**: forgot a content change from 01-002 — **cause**: 01-002 had many changes — **fallback**: diff the 01-002 versions against the history-retained versions and apply any missing changes

- [ ] Task 5 — Fix import paths in moved modules (FR-3)
  The moved modules may reference levonk-nix-config-internal paths that don't exist in infrahub. Check and fix:
  - `rg "levonk-nix-config|../../modules/components|../../modules/system/darwin" shared/active/02-config/nix/darwin/` → should return no matches after fixing
  - The host configs (from 01-002) already use the correct infrahub paths — verify they still import correctly
  **Verify**: `nix flake check ./shared/active/02-config/nix/darwin` → exit 0
  **Likely failure**: import path errors — **cause**: moved modules reference siblings at old paths — **fallback**: fix relative paths to match new directory structure

- [ ] Task 6 — Handle privacy-darwin.nix coupling (UNRESOLVED)
  `levonk-nix-config/modules/security/baseline.nix` imports `./privacy-darwin.nix`. If privacy-darwin.nix is moved out (not copied), baseline.nix breaks and levonk-nix-config's Linux security build fails.
  **Check**: `cd ~/p/gh/levonk/levonk-nix-config && nix flake check` — if it fails because `privacy-darwin.nix` is missing:
  - **Option A (preferred)**: Copy privacy-darwin.nix back to levonk-nix-config (keep a copy for baseline.nix, canonical version in infrahub). The copy in levonk-nix-config is a legacy dependency for the home-manager security module.
  - **Option B**: Edit baseline.nix to inline the privacy defaults or remove the import (if baseline.nix's privacy settings are only relevant on Darwin, and the Darwin hosts are retired, the import may be dead code).
  **Verify**: `cd ~/p/gh/levonk/levonk-nix-config && nix flake check` → exit 0 (Linux configs build)
  **Likely failure**: baseline.nix has other Darwin-specific logic that breaks — **cause**: baseline.nix was designed for both Darwin and Linux — **fallback**: use `lib.mkIf pkgs.stdenv.isDarwin` guards in baseline.nix to skip Darwin-specific parts on Linux
  **Decision fork**: If `nix flake check` on levonk-nix-config fails after removing privacy-darwin.nix → Option A (copy it back). If it still fails → Option B (edit baseline.nix). If both fail → STOP and report.

- [ ] Task 7 — Retire levonk-nix-config darwin hosts (FR-12)
  In `~/p/gh/levonk/levonk-nix-config`:
  - Edit `flake.nix`: remove the `nix-darwin` input (lines 7-8) and the entire `darwinConfigurations` block (lines 62-74)
  - `git rm -r hosts/mac-aarch64/ hosts/mac-x86_64/`
  - `git rm modules/system/darwin/defaults.nix modules/system/darwin/homebrew.nix` (if not already removed by filter-repo — filter-repo ran on a clone, the working repo still has them)
  - `git rm modules/components/nix/settings.nix modules/components/nix/cache.nix` (same)
  - `git rm modules/security/privacy-darwin.nix` (UNLESS Task 6 chose Option A — then keep the copy)
  - Remove the `nix-darwin` input from `flake.nix` and run `nix flake update` to update flake.lock
  **Verify**: `rg "darwinConfigurations|nix-darwin" ~/p/gh/levonk/levonk-nix-config/flake.nix` → no matches; `ls ~/p/gh/levonk/levonk-nix-config/hosts/mac-aarch64` → fails (deleted); `ls ~/p/gh/levonk/levonk-nix-config/hosts/wsl-dev/default.nix` → exists (untouched)
  **Likely failure**: `nix flake check` on levonk-nix-config fails after removing nix-darwin input — **cause**: something still references nix-darwin — **fallback**: `rg "nix-darwin" ~/p/gh/levonk/levonk-nix-config/` to find remaining references

- [ ] Task 8 — Verify both repos build
  - `cd ~/p/gh/levonk/infrahub && nix flake check ./shared/active/02-config/nix/darwin` → exit 0
  - `cd ~/p/gh/levonk/levonk-nix-config && nix flake check` → exit 0 (Linux configs only)
  **Verify**: both exit 0
  **Likely failure**: either repo has lingering references — **cause**: incomplete cleanup — **fallback**: `rg` for the failing reference and fix

## Relevant Files

- `levonk-nix-config/flake.nix` — remove nix-darwin input + darwinConfigurations
- `levonk-nix-config/hosts/mac-aarch64/aarch64.nix` — delete
- `levonk-nix-config/hosts/mac-x86_64/x86_64.nix` — delete
- `levonk-nix-config/modules/system/darwin/defaults.nix` — move to infrahub (or delete from working repo after filter-repo)
- `levonk-nix-config/modules/system/darwin/homebrew.nix` — same
- `levonk-nix-config/modules/components/nix/settings.nix` — same
- `levonk-nix-config/modules/components/nix/cache.nix` — same
- `levonk-nix-config/modules/security/privacy-darwin.nix` — move OR copy (see Task 6)
- `infrahub/shared/active/02-config/nix/darwin/modules/` — replaced with history-retained versions

## Acceptance Criteria

- [ ] `git log --follow shared/active/02-config/nix/darwin/modules/system/defaults.nix` shows commits from levonk-nix-config
- [ ] `nix flake check ./shared/active/02-config/nix/darwin` exits 0
- [ ] `nix flake check ~/p/gh/levonk/levonk-nix-config` exits 0 (Linux configs)
- [ ] `rg "darwinConfigurations|nix-darwin" ~/p/gh/levonk/levonk-nix-config/flake.nix` returns no matches
- [ ] `ls ~/p/gh/levonk/levonk-nix-config/hosts/mac-aarch64` fails (deleted)
- [ ] `ls ~/p/gh/levonk/levonk-nix-config/hosts/wsl-dev/default.nix` exists (untouched)
- [ ] `rg "levonk-nix-config|../../modules/components" shared/active/02-config/nix/darwin/` returns no matches (paths fixed)
- [ ] History-retained modules have the 01-002 content changes (OS auto-install OFF, empty casks)

## Test Plan

- `nix flake check` on both repos
- `git log --follow` on moved files to verify history
- `rg` checks per Acceptance Criteria

## Observability

- N/A (git operations)

## Compliance

- N/A

## Risks & Mitigations

- Risk: filter-repo rewrites history incorrectly, losing commits — Mitigation: run on a clone, not the working repo; verify with `git log` before merging
- Risk: privacy-darwin.nix coupling breaks levonk-nix-config Linux build — Mitigation: Task 6 handles this with copy-back fallback
- Risk: merge conflicts between 01-002 fresh files and history-retained files — Mitigation: `git checkout --theirs` + re-apply content changes; or skip history merge if too complex (ponytail comment)

## Failure Modes & Decision Forks

- **Failure mode**: filter-repo fails — **cause**: wrong paths or not installed — **fallback**: verify paths, confirm `devbox run -- git filter-repo --version`
- **Failure mode**: merge conflicts in infrahub — **cause**: 01-002 created same files — **fallback**: `git checkout --theirs`, re-apply 01-002 content changes; or skip history, use 01-002 files with `ponytail:` comment
- **Failure mode**: levonk-nix-config Linux build breaks after privacy-darwin.nix removal — **cause**: baseline.nix imports it — **fallback**: copy privacy-darwin.nix back (Option A) or edit baseline.nix (Option B)
- **Decision fork**: If history merge is too complex → skip it, keep 01-002 fresh files, add `ponytail:` comment noting origin. History is nice-to-have, not a blocker.
- **Decision fork**: If `nix flake check` on levonk-nix-config fails after removing privacy-darwin.nix → copy it back (Option A)

## Dependencies & Sequencing

- Depends on:
  - story-01-001-devbox-git-filter-repo (needs git-filter-repo in devbox)
  - story-01-002-darwin-flake-authoring (fresh files exist to be replaced by history-retained versions)
- Unblocks:
  - story-03-001-playbook-rewrite (configure playbook calls the flake — flake must be final)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] Both repos' `nix flake check` exits 0
- [ ] Moved files have git history from levonk-nix-config
- [ ] levonk-nix-config has no darwinConfigurations or nix-darwin input
- [ ] Linux configs in levonk-nix-config are untouched
- [ ] No files outside the in-scope list are modified

## STOP Conditions

Stop and report if:
- `git filter-repo` fails and can't be fixed by path correction
- levonk-nix-config's Linux build breaks after darwin removal and neither Option A nor B fixes it
- The merge conflicts between 01-002 and history-retained files are unresolvable
- A moved module has import dependencies on levonk-nix-config's home-manager modules

### Decision Forks (Contingency Paths)
- If history merge is too complex → skip it, use 01-002 fresh files with `ponytail:` comment
- If privacy-darwin.nix move breaks levonk-nix-config → copy it back (Option A)
- If baseline.nix still fails after Option A → edit baseline.nix with `mkIf isDarwin` guards (Option B)

## Maintenance Notes

- After this story, levonk-nix-config is Linux-only (home-manager configs for wsl-dev, debian, qubes, nixos). The darwin modules live in infrahub.
- The `privacy-darwin.nix` copy in levonk-nix-config (if Option A was taken) is a legacy dependency for baseline.nix. It can be cleaned up when baseline.nix is refactored to not need it.
- Reviewers: confirm history is retained, Linux configs untouched, no home-manager pulled into infrahub.

## Commit Conventions

- In infrahub: `feat(nix-darwin): merge darwin modules from levonk-nix-config with history`
- In levonk-nix-config: `refactor: retire darwin hosts and modules (moved to infrahub)`

## Changelog

- 2026-07-06: initialized story file
