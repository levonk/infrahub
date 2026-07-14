# Task Index: nix-darwin-migration

**PRD:** [feat-202607060157-nix-darwin-migration.md](../feat-202607060157-nix-darwin-migration.md)

## Stories

| Story ID | Story Title | Status | Branch | Dependencies | Parallel-safe | Modules |
| -------- | ----------- | ------ | ------ | ------------ | ------------- | ------- |
| 01-001 | Add git-filter-repo to devbox.json | [x] Done | `feature/current/nix-darwin-migration/story-01-001-devbox-git-filter-repo` | None | true | `infrahub/devbox.json` |
| 01-002 | Author nix-darwin flake + system modules + per-host configs | [x] Done | `feature/current/nix-darwin-migration/story-01-002-darwin-flake-authoring` | None | true | `infrahub/shared/active/02-config/nix/darwin/` |
| 01-003 | Edit osx-settings.py — add three-layer comment, remove sudo settings | [x] Done | `feature/current/nix-darwin-migration/story-01-003-osx-settings-cleanup` | None | true | `dotfiles/home/current/dot_local/bin/` |
| 02-001 | Cross-repo history move + retire levonk-nix-config darwin | [x] Done | `feature/current/nix-darwin-migration/story-02-001-cross-repo-move` | 01-001, 01-002 | false | `levonk-nix-config/`, `infrahub/shared/active/02-config/nix/darwin/` |
| 03-001 | Playbook rewrite — shrink bootstrap, add configure, os-update, pmset/chflags, delete old flake | [ ] Todo | `feature/current/nix-darwin-migration/story-03-001-playbook-rewrite` | 02-001, 01-002, 01-003 | false | `infrahub/shared/active/02-config/ansible/`, `infrahub/justfile`, `infrahub/shared/active/02-config/nix/flake.nix` |
| 04-001 | Local validation runbook + ADR | [ ] Todo | `feature/current/nix-darwin-migration/story-04-001-runbook-adr` | 03-001 | false | `infrahub/shared/active/08-docs/`, `infrahub/internal-docs/adr/` |
## Phase Summary

### Phase 01 — Foundation (3 parallel stories, no dependencies)
- **01-001** (low risk, ~1 hour): Add `git-filter-repo` to devbox.json. Prerequisite for 02-001.
- **01-002** (high risk, ~1 day): Author the complete nix-darwin flake — system modules (defaults with OS auto-install OFF, privacy, nix settings, homebrew with empty casks), per-host configs (auser + container runtime option), fleet apps via Nix not cask. Local validation on lzkmbp2016 included.
- **01-003** (low risk, ~1 hour): Edit osx-settings.py in dotfiles — add three-layer comment, remove 7 sudo-requiring settings, remove `sudo -v` call. Zero sudo prompts remain.

### Phase 02 — Cross-repo history move (1 sequential story)
- **02-001** (high risk, ~half day): `git filter-repo` darwin modules from levonk-nix-config into infrahub with history. Retire levonk-nix-config darwin hosts. Handle privacy-darwin.nix coupling with baseline.nix.

### Phase 03 — Playbook rewrite (1 sequential story)
- **03-001** (medium risk, ~half day): Shrink bootstrap to 5 tasks, create configure playbook (darwin-rebuild switch + pmset/chflags), add os-update playbook, add justfile recipes, delete old flake, remove inventory variable.

### Phase 04 — Documentation (1 sequential story)
- **04-001** (low risk, ~1 hour): Local validation runbook + ADR recording the three-layer split decision.

## Dependency Graph

```
Phase 01:  01-001 ──┐
           01-002 ──┼──→ Phase 02: 02-001 ──→ Phase 03: 03-001 ──→ Phase 04: 04-001
           01-003 ──┘
```

- 01-001, 01-002, 01-003 are fully parallel (different repos/files, no conflicts)
- 02-001 depends on 01-001 (git-filter-repo) and 01-002 (fresh files to replace with history)
- 03-001 depends on 02-001 (flake final), 01-002 (flake exists), 01-003 (sudo settings removed from script)
- 04-001 depends on 03-001 (configure playbook exists to reference)

## Key Decisions Embedded in Stories

1. **No home-manager** (NFR-5): nix-darwin manages system-level only; chezmoi owns home directory
2. **User-level defaults stay in chezmoi** (FR-15 reversed): nix-darwin's system.defaults writes to system domain, overridden by user-level prefs — migrating user settings would not reliably apply
3. **Fleet apps via Nix, not casks** (FR-5): orbstack, rustdesk, firefox-devedition-bin, raycast all in nixpkgs — empty cask list
4. **OS auto-updates OFF** (FR-6): lzkmbp2016 runs OpenCore; AutomaticallyInstallMacOSUpdates/ConfigDataInstall/CriticalUpdateInstall = false; AutoUpdate (apps) = true
5. **Zero sudo in osx-settings.py** (FR-16/17): 7 sudo-requiring settings move to Ansible; user-level defaults and killall of user processes need no sudo
6. **Three-layer comment** (FR-18): osx-settings.py documents where each setting type belongs (nix-darwin / Ansible / chezmoi)
