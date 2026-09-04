# Task Index: nix-darwin-migration

**PRD:** [feat-202607060157-nix-darwin-migration.md](../feat-202607060157-nix-darwin-migration.md)

## Stories

| Story ID | Story Title | Status | Branch | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 01-001 | Add git-filter-repo to devbox.json | [x] Done | `feature/current/nix-darwin-migration/story-01-001-devbox-git-filter-repo` | None | true | `infrahub/devbox.json` |
| 01-002 | Author nix-darwin flake + system modules + per-host configs | [x] Done | `feature/current/nix-darwin-migration/story-01-002-darwin-flake-authoring` | None | true | `infrahub/shared/active/02-config/nix/darwin/` |
| 01-003 | Edit osx-settings.py — add three-layer comment, remove sudo settings | [x] Done | `feature/current/nix-darwin-migration/story-01-003-osx-settings-cleanup` | None | true | `dotfiles/home/current/dot_local/bin/` |
| 02-001 | Cross-repo history move + retire levonk-nix-config darwin | [x] Done | `feature/current/nix-darwin-migration/story-02-001-cross-repo-move` | 01-001, 01-002 | false | `levonk-nix-config/`, `infrahub/shared/active/02-config/nix/darwin/` |
| 03-001 | Playbook rewrite — shrink bootstrap, add configure, os-update, pmset/chflags, delete old flake | [x] Done | `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite` | 02-001, 01-002, 01-003 | false | `infrahub/shared/active/02-config/ansible/`, `infrahub/justfile`, `infrahub/shared/active/02-config/nix/flake.nix` |
| 04-001 | Local validation runbook + ADR | [x] Done | `feature/current/nix-darwin-migration/story-04-001-runbook-adr` | 03-001 | false | `infrahub/shared/active/08-docs/`, `infrahub/internal-docs/adr/` |

## Phase Summary

### Phase 01 — Foundation (3 parallel stories, no dependencies)
- **01-001** (low risk): Add `git-filter-repo` to devbox.json. Prerequisite for 02-001.
- **01-002** (high risk): Author the complete nix-darwin flake — system modules, per-host configs, fleet apps via Nix.
- **01-003** (low risk): Edit osx-settings.py in dotfiles — add three-layer comment, remove sudo settings.

### Phase 02 — Cross-repo history move (1 sequential story)
- **02-001** (high risk): `git filter-repo` darwin modules from levonk-nix-config into infrahub with history.

### Phase 03 — Playbook rewrite (1 sequential story)
- **03-001** (medium risk): Shrink bootstrap, create configure playbook, add os-update playbook, justfile recipes.

### Phase 04 — Documentation (1 sequential story)
- **04-001** (low risk): Local validation runbook + ADR recording the three-layer split decision.

## Dependency Graph

```
Phase 01:  01-001 ──┐
           01-002 ──┼──→ Phase 02: 02-001 ──→ Phase 03: 03-001 ──→ Phase 04: 04-001
           01-003 ──┘
```

## Completion Notes

All 6 stories are `[x] Done`:

- **01-001 through 03-001**: Completed on story branches (see handoff
  `202607201948-nix-darwin-migration-resume.md`). Work also present on master.
- **04-001**: Completed this session. Runbook created at
  `shared/active/08-docs/runbooks/nix-darwin-local-validation.md`, ADR verified
  at `shared/active/08-docs/adr/adr-202607070001-macos-system-config-nix-darwin.md`
  (three-layer split section added), configure playbook references the runbook.
  Commit: `6fe58de`.

## Deferred Items

- **Deployment validation against lzkmbp2018 (192.168.12.210)**: The handoff
  notes that `--check` dry-run and live deploy were not yet run against the
  target host. This requires user confirmation that the bootstrap playbook's
  sudoers fix was applied (`/etc/sudoers.d/auser` exists on 192.168.12.210).
  This is a deployment validation step, not a story — all story deliverables
  are complete.
- **Story branch merge**: The story branches (01-001 through 03-001) have not
  been merged to master. The work exists on master via separate commits, but
  the branch merge history is not clean. Consider merging or archiving these
  branches.
