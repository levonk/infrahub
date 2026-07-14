---
story_id: "01-002"
story_title: "Author nix-darwin flake + system modules + per-host configs"
story_name: "darwin-flake-authoring"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 1
parallel_id: 2
branch: "feature/current/nix-darwin-migration/story-01-002-darwin-flake-authoring"
status: "blocked"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["infrahub/shared/active/02-config/nix/darwin/"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "nix", "darwin", "macos"]
due: "2026-07-20"
created_at: "2026-07-06"
updated_at: "2026-07-12"
---

## Summary

Author the complete nix-darwin flake in infrahub at `shared/active/02-config/nix/darwin/`. This is the core of the migration: a flake with `darwinConfigurations.lzkmbp2016` and `darwinConfigurations.lzkmbp2018`, system modules (defaults with OS auto-install OFF, privacy, nix settings, homebrew with empty cask list), per-host configs with `auser` admin account + container runtime option, and fleet apps via `environment.systemPackages` (orbstack, rustdesk via Nix, not cask). No home-manager. This story does NOT do the cross-repo history move (that's 02-001) — it authors the modules fresh in infrahub, and 02-001 will replace them with history-retained versions from levonk-nix-config.

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/nix/flake.nix` — existing packages-only flake (`host-apps`, `symlink-apps`). Will be deleted in story 03-001, NOT in this story.
  - `shared/active/02-config/ansible/infrastructure/apps.yml` — defines `infra_app_nix_cli_packages` (git, zsh, tailscale, netbird), `infra_app_nix_gui_packages` (cmux, firefox-devedition-bin, raycast), `infra_app_brew_casks` (orbstack, rustdesk). FR-5 requires orbstack/rustdesk to move from casks to Nix packages.
  - `levonk-nix-config/modules/system/darwin/defaults.nix` — `system.defaults` with dock/finder/loginwindow/screencapture/screensaver/SoftwareUpdate/com.apple.commerce. Source for FR-6 (with OS auto-install keys changed to false).
  - `levonk-nix-config/modules/system/darwin/homebrew.nix` — `homebrew` module with personal cask list. Source for FR-5 (cask list replaced with empty/minimal fleet list).
  - `levonk-nix-config/modules/components/nix/settings.nix` — `nix.settings` (experimental-features, accept-flake-config, auto-optimise-store, keep-outputs/derivations, flake-registry). Source for FR-8.
  - `levonk-nix-config/modules/components/nix/cache.nix` — `nix.settings.substituters`/`trusted-public-keys`. Source for FR-8.
  - `levonk-nix-config/modules/security/privacy-darwin.nix` — `system.defaults` privacy keys (SubmitDiagInfo, AdLib, iCloud, Safari, Spotlight, Maps, Health, imessage, Photos). Source for FR-7.
  - `levonk-nix-config/hosts/mac-x86_64/x86_64.nix` — host config pattern: imports modules, sets `system.stateVersion`, `services.nix-daemon.enable`, `users.users.<name>`. Source for FR-4 pattern (adapted: auser instead of useracct, no home-manager).
  - `levonk-nix-config/flake.nix` — flake structure with `nix-darwin` input and `darwinConfigurations`. Source for flake input pattern.
- **Existing code excerpts:**

  levonk-nix-config flake input (to replicate):
  ```nix
  # levonk-nix-config/flake.nix (lines 5-8)
  nix-darwin.url = "github:LnL7/nix-darwin";
  nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  ```

  levonk-nix-config host config pattern (to adapt — drop home-manager, use auser):
  ```nix
  # levonk-nix-config/hosts/mac-x86_64/x86_64.nix
  { pkgs, ... }: {
    imports = [ ../../modules/system/darwin/defaults.nix ... ];
    system.stateVersion = 4;
    services.nix-daemon.enable = true;
    users.users.useracct = { name = "useracct"; home = "/Users/useracct"; };
    home-manager.users.useracct = { ... };  # DROP THIS — no home-manager
  }
  ```

  levonk-nix-config defaults.nix SoftwareUpdate (to change — OS auto-install OFF):
  ```nix
  # levonk-nix-config/modules/system/darwin/defaults.nix (lines 30-36)
  SoftwareUpdate = {
    AutomaticCheckEnabled = true;
    AutomaticDownload = true;
    AutomaticallyInstallMacOSUpdates = true;  # CHANGE TO false
    ConfigDataInstall = true;                  # CHANGE TO false
    CriticalUpdateInstall = true;              # CHANGE TO false
  };
  ```

  Current apps.yml cask list (to move to Nix packages):
  ```yaml
  # shared/active/02-config/ansible/infrastructure/apps.yml
  infra_app_brew_casks:
    - orbstack      # → move to infra_app_nix_gui_packages
    - rustdesk      # → move to infra_app_nix_gui_packages
  ```

- **Repository conventions:**
  - Flake inputs: `nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"` (matches existing infrahub flake.nix)
  - `nix-darwin` input: `github:LnL7/nix-darwin` with `inputs.nixpkgs.follows = "nixpkgs"` (matches levonk-nix-config)
  - Module structure: one concern per file, imports in host config
  - `system.stateVersion = 4` (current nix-darwin state version)
  - No home-manager anywhere (NFR-5)
  - No secrets in flake (NFR-2) — auser password stays vault-owned
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Flake check | `nix flake check ./shared/active/02-config/nix/darwin` (on a Mac) | exit 0 |
  | Flake show | `nix flake show ./shared/active/02-config/nix/darwin` | lists darwinConfigurations.lzkmbp2016, lzkmbp2018 |
  | Local apply | `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` | exit 0, settings applied |
  | Idempotency | re-run above | no changes |
  | No home-manager | `rg "home-manager" shared/active/02-config/nix/darwin/` | no matches |

## Scope

**In scope:**
- Create `shared/active/02-config/nix/darwin/flake.nix` with nix-darwin input + darwinConfigurations for both hosts
- Create `shared/active/02-config/nix/darwin/modules/system/defaults.nix` (FR-6: system.defaults with OS auto-install OFF)
- Create `shared/active/02-config/nix/darwin/modules/system/homebrew.nix` (FR-5: homebrew with empty/minimal cask list)
- Create `shared/active/02-config/nix/darwin/modules/nix/settings.nix` (FR-8: nix.settings)
- Create `shared/active/02-config/nix/darwin/modules/nix/cache.nix` (FR-8: substituters/trusted-public-keys)
- Create `shared/active/02-config/nix/darwin/modules/security/privacy-darwin.nix` (FR-7: privacy defaults)
- Create `shared/active/02-config/nix/darwin/modules/fleet/default.nix` (FR-4: `infra.fleet.containerRuntime` option + auser user + fleet apps via environment.systemPackages)
- Create `shared/active/02-config/nix/darwin/hosts/lzkmbp2016.nix` (x86, orbstack)
- Create `shared/active/02-config/nix/darwin/hosts/lzkmbp2018.nix` (arch TBD — see UNRESOLVED)
- Update `shared/active/02-config/ansible/infrastructure/apps.yml` (move orbstack/rustdesk from casks to nix packages)

**Out of scope:**
- Cross-repo history move (story 02-001) — this story authors fresh; 02-001 replaces with history-retained versions
- Deleting the old `shared/active/02-config/nix/flake.nix` (story 03-001)
- Ansible playbook changes (story 03-001)
- osx-settings.py changes (story 01-003)
- Local validation runbook (story 04-001)
- home-manager (NFR-5 — never)

## Sub-Tasks

- [x] Task 1 — Create flake.nix with nix-darwin input and darwinConfigurations skeleton
  Create `shared/active/02-config/nix/darwin/flake.nix` with:
  - `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"`
  - `inputs.nix-darwin.url = "github:LnL7/nix-darwin"` with `inputs.nixpkgs.follows = "nixpkgs"`
  - `outputs = { self, nixpkgs, nix-darwin, ... }: { darwinConfigurations = { ... }; }`
  - `darwinConfigurations.lzkmbp2016` and `darwinConfigurations.lzkmbp2018` using `nix-darwin.lib.darwinSystem`
  - Each host imports `./hosts/<hostname>.nix`
  **Verify**: `nix flake show ./shared/active/02-config/nix/darwin` → lists `darwinConfigurations:lzkmbp2016` and `darwinConfigurations:lzkmbp2018`
  **Likely failure**: flake eval fails because host files don't exist yet — **cause**: tasks not yet complete — **fallback**: create empty host files first (`{ ... }: {}`), then fill in Task 7-8
  **Decision fork**: If `nix flake show` fails with "no nix-darwin input" → check that `nix-darwin.url` is correct and `nix flake update` has been run in the darwin directory

- [x] Task 2 — Create modules/system/defaults.nix (FR-6)
  Create `shared/active/02-config/nix/darwin/modules/system/defaults.nix` with all `system.defaults` from `levonk-nix-config/modules/system/darwin/defaults.nix`, BUT with these three keys set to `false`:
  - `SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false`
  - `SoftwareUpdate.ConfigDataInstall = false`
  - `SoftwareUpdate.CriticalUpdateInstall = false`
  Keep `true`: `AutomaticCheckEnabled`, `AutomaticDownload`, `com.apple.commerce.AutoUpdate`.
  Update the comment block to reflect: "Install macOS updates: Off", "Install Security Responses: Off", "Install App Store app updates: On".
  **Verify**: `rg "AutomaticallyInstallMacOSUpdates" shared/active/02-config/nix/darwin/modules/system/defaults.nix` → `AutomaticallyInstallMacOSUpdates = false;`
  **Likely failure**: nix-darwin doesn't recognize a `system.defaults` key (e.g., `_FXSortFoldersFirst`) — **cause**: key name mismatch between nix-darwin version and levonk-nix-config — **fallback**: check nix-darwin docs for the correct attribute name; if unsupported, drop the key with a `ponytail:` comment noting the ceiling
  **Decision fork**: If `nix flake check` fails on a specific `system.defaults` key → comment it out with a `ponytail:` comment and continue; the setting can be applied via osx-settings.py (chezmoi) as a user-level fallback

- [x] Task 3 — Create modules/system/homebrew.nix (FR-5)
  Create `shared/active/02-config/nix/darwin/modules/system/homebrew.nix` with:
  - `homebrew.enable = true`
  - `homebrew.onActivation.cleanup = "zap"`
  - `homebrew.onActivation.autoUpdate = true`
  - `homebrew.onActivation.upgrade = true`
  - `homebrew.taps = [ "homebrew/bundle" "homebrew/services" ]`
  - `homebrew.casks = [ ]` — EMPTY (all fleet apps are in nixpkgs, installed via environment.systemPackages in the fleet module)
  - `homebrew.brews = [ ]`
  **Verify**: `rg "casks" shared/active/02-config/nix/darwin/modules/system/homebrew.nix` → `casks = [ ];` (empty)
  **Likely failure**: `homebrew.onActivation.cleanup = "zap"` removes existing casks on first run — **cause**: this is the intended behavior but may surprise — **fallback**: document in the module comment that `zap` removes casks not in the list; since the list is empty, ALL casks will be removed on first `darwin-rebuild switch`. If this is too aggressive for the first deploy, temporarily set `cleanup = "none"` and switch to `"zap"` after verification.
  **Decision fork**: If the user's machine has personal casks they want to keep → set `cleanup = "none"` initially; switch to `"zap"` only after confirming no wanted casks will be removed

- [x] Task 4 — Create modules/nix/settings.nix and modules/nix/cache.nix (FR-8)
  Create `shared/active/02-config/nix/darwin/modules/nix/settings.nix` with `nix.settings` from `levonk-nix-config/modules/components/nix/settings.nix`:
  - `experimental-features = [ "nix-command" "flakes" ]`
  - `accept-flake-config = true`
  - `auto-optimise-store = true`
  - `keep-outputs = true`
  - `keep-derivations = true`
  - `flake-registry = "https://github.com/NixOS/flake-registry/raw/master/flake-registry.json"`
  Create `shared/active/02-config/nix/darwin/modules/nix/cache.nix` with `nix.settings.substituters` and `trusted-public-keys` from `levonk-nix-config/modules/components/nix/cache.nix`.
  **Verify**: `rg "experimental-features" shared/active/02-config/nix/darwin/modules/nix/settings.nix` → `experimental-features = [ "nix-command" "flakes" ];`
  **Likely failure**: nix-darwin doesn't support `flake-registry` in `nix.settings` — **cause**: key may be named differently in nix-darwin — **fallback**: check nix-darwin nix module options; if unsupported, drop it with a `ponytail:` comment

- [x] Task 5 — Create modules/security/privacy-darwin.nix (FR-7)
  Create `shared/active/02-config/nix/darwin/modules/security/privacy-darwin.nix` with all `system.defaults` privacy keys from `levonk-nix-config/modules/security/privacy-darwin.nix`:
  - `com.apple.SubmitDiagInfo` (AutoSubmit=false, AllowApplePersonalizedAds=false)
  - `com.apple.AdLib` (allowApplePersonalizedAdvertising=false)
  - `com.apple.iCloud` (EnableAnalytics=false)
  - `com.apple.Safari` (SendDoNotTrackHTTPHeader=true, UniversalSearchEnabled=false, SuppressSearchSuggestions=true)
  - `com.apple.Spotlight` (SuggestionsEnabled=false)
  - `com.apple.Maps`, `com.apple.Health`, `com.apple.imessage`, `com.apple.Photos` (UserSelectedAnonymousUsageOptIn=false)
  Use `lib.mkIf pkgs.stdenv.isDarwin` guard (matches source).
  **Verify**: `rg "SubmitDiagInfo" shared/active/02-config/nix/darwin/modules/security/privacy-darwin.nix` → finds `AutoSubmit = false;`
  **Likely failure**: some `system.defaults` domain keys not recognized by nix-darwin — **cause**: dot-notation domain names may need quoting — **fallback**: use `system.defaults."com.apple.SubmitDiagInfo".AutoSubmit = false;` (quoted)

- [x] Task 6 — Create modules/fleet/default.nix (FR-4, FR-5)
  Create `shared/active/02-config/nix/darwin/modules/fleet/default.nix` with:
  - A custom option `infra.fleet.containerRuntime` (enum: `"orbstack"` | `"apple-container"`, default `"orbstack"`)
  - `users.users.auser` with `name = "auser"`, `home = "/Users/auser"`, in admin group
  - `environment.systemPackages` with fleet apps: `git`, `zsh`, `tailscale`, `netbird`, `cmux`, `firefox-devedition-bin`, `raycast`, `orbstack`, `rustdesk` (all from nixpkgs — verified available)
  - Conditional: if `containerRuntime == "orbstack"`, include `orbstack` in systemPackages; if `"apple-container"`, exclude it (built into macOS 26+)
  **Verify**: `rg "containerRuntime" shared/active/02-config/nix/darwin/modules/fleet/default.nix` → finds the option definition
  **Likely failure**: `infra.fleet.containerRuntime` option not recognized — **cause**: custom options need `options` + `config` structure — **fallback**: use `mkOption` with `types.enum`; see nix-darwin module system docs
  **Decision fork**: If `orbstack` nix package doesn't include the GUI app on macOS → check `nix-env -qaP orbstack` output; if it's CLI-only, fall back to keeping orbstack as a cask and document with `ponytail:` comment

- [x] Task 7 — Create hosts/lzkmbp2016.nix
  Create `shared/active/02-config/nix/darwin/hosts/lzkmbp2016.nix`:
  - `system = "x86_64-darwin"` (or let nix-darwin auto-detect)
  - Import all system modules + fleet module
  - `system.stateVersion = 4`
  - `services.nix-daemon.enable = true`
  - `infra.fleet.containerRuntime = "orbstack"` (x86 Mac, no Apple Container)
  **Verify**: `nix flake check ./shared/active/02-config/nix/darwin` → exit 0 (after all modules exist)
  **Likely failure**: import path errors — **cause**: wrong relative paths — **fallback**: use absolute paths from flake root or fix relative `../../modules/` paths

- [x] Task 8 — Create hosts/lzkmbp2018.nix
  Create `shared/active/02-config/nix/darwin/hosts/lzkmbp2018.nix`:
  - Same structure as lzkmbp2016
  - `infra.fleet.containerRuntime` = TBD (UNRESOLVED — need to SSH and check `sw_vers; uname -m`)
  - Default to `"orbstack"` until verified; add a `ponytail:` comment: "containerRuntime unverified — check ssh auser@lzkmbp2018 'sw_vers; uname -m' and update if macOS 26+ ARM"
  **Verify**: `nix flake show ./shared/active/02-config/nix/darwin` → lists `darwinConfigurations:lzkmbp2018`
  **Likely failure**: same as Task 7 — **fallback**: same

- [x] Task 9 — Update apps.yml (move casks to Nix packages)
  Edit `shared/active/02-config/ansible/infrastructure/apps.yml`:
  - Move `orbstack` and `rustdesk` from `infra_app_brew_casks` to `infra_app_nix_gui_packages`
  - Set `infra_app_brew_casks` to `[]` (empty list)
  - Add a comment: "# Fleet apps installed via nix-darwin environment.systemPackages, not Homebrew casks (FR-5)"
  **Verify**: `rg "orbstack" shared/active/02-config/ansible/infrastructure/apps.yml` → found under `infra_app_nix_gui_packages`, NOT under `infra_app_brew_casks`
  **Likely failure**: ansible-lint complains about empty list syntax — **cause**: YAML empty list `[]` vs explicit empty — **fallback**: use `infra_app_brew_casks: []` (inline) or `infra_app_brew_casks:` with no items

- [!] Task 10 — Local validation on lzkmbp2016 (de-risk)
  Run `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` directly on lzkmbp2016 (this Mac). Verify FR-6/7/8 observations. If it fails, debug and fix the flake. If it succeeds, verify idempotency (re-run → no changes). Test rollback: `darwin-rebuild rollback`.
  **Verify**: `defaults read com.apple.dock autohide` → `1`; `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` → `0`; `defaults read /Library/Preferences/com.apple.commerce AutoUpdate` → `1`; `defaults read com.apple.SubmitDiagInfo AutoSubmit` → `0`
  **Likely failure**: `darwin-rebuild switch` fails on first run — **cause**: various (missing nix-darwin, flake eval error, unsupported option) — **fallback**: read the error, fix the flake, retry. Use `darwin-rebuild rollback` if the system is in a bad state.
  **Decision fork**: If `users.users.auser` clobbers the existing auser password → STOP, set `users.users.auser.passwordFile` or omit password management, and report (this is a STOP condition in the PRD)

## Relevant Files

- `shared/active/02-config/nix/darwin/flake.nix` — new, the flake entry point
- `shared/active/02-config/nix/darwin/modules/system/defaults.nix` — new, system.defaults (FR-6)
- `shared/active/02-config/nix/darwin/modules/system/homebrew.nix` — new, homebrew module (FR-5)
- `shared/active/02-config/nix/darwin/modules/nix/settings.nix` — new, nix.settings (FR-8)
- `shared/active/02-config/nix/darwin/modules/nix/cache.nix` — new, substituters (FR-8)
- `shared/active/02-config/nix/darwin/modules/security/privacy-darwin.nix` — new, privacy defaults (FR-7)
- `shared/active/02-config/nix/darwin/modules/fleet/default.nix` — new, fleet option + auser + apps (FR-4/5)
- `shared/active/02-config/nix/darwin/hosts/lzkmbp2016.nix` — new, host config
- `shared/active/02-config/nix/darwin/hosts/lzkmbp2018.nix` — new, host config
- `shared/active/02-config/ansible/infrastructure/apps.yml` — modified, casks → nix packages

## Acceptance Criteria

- [x] `nix flake check ./shared/active/02-config/nix/darwin` exits 0 on lzkmbp2016
- [x] `nix flake show ./shared/active/02-config/nix/darwin` lists both darwinConfigurations
- [!] `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` succeeds on lzkmbp2016
- [!] Re-running the above reports no changes (idempotent)
- [!] `darwin-rebuild rollback` restores prior state
- [!] `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` returns `0`
- [!] `defaults read /Library/Preferences/com.apple.commerce AutoUpdate` returns `1`
- [!] `defaults read com.apple.SubmitDiagInfo AutoSubmit` returns `0`
- [x] `rg "home-manager" shared/active/02-config/nix/darwin/` returns no matches
- [x] `rg "orbstack" shared/active/02-config/ansible/infrastructure/apps.yml` shows it under nix packages, not casks
- [!] `brew list --cask` shows no fleet casks after `darwin-rebuild switch`

## Test Plan

- `nix flake check ./shared/active/02-config/nix/darwin` — flake builds
- `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` — local apply
- `defaults read` spot-checks (see Acceptance Criteria)
- `rg "home-manager" shared/active/02-config/nix/darwin/` — no home-manager
- Idempotency: re-run darwin-rebuild switch → no changes

## Observability

- `darwin-rebuild switch` output shows what changed (diff-style)
- `darwin-rebuild generations` lists system generations for rollback

## Compliance

- No secrets in the flake (NFR-2) — auser password stays in vault, not in nix-darwin
- No home-manager (NFR-5)

## Risks & Mitigations

- Risk: nix-darwin doesn't support some `system.defaults` keys from levonk-nix-config — Mitigation: comment out unsupported keys with `ponytail:` comment, fall back to osx-settings.py for those
- Risk: `homebrew.onActivation.cleanup = "zap"` removes personal casks — Mitigation: set `cleanup = "none"` for first deploy, switch to `"zap"` after verification
- Risk: `users.users.auser` clobbers existing auser password — Mitigation: STOP condition (PRD); test on lzkmbp2016 and verify auser can still sudo after darwin-rebuild switch
- Risk: `orbstack` nix package is CLI-only (no GUI app) — Mitigation: check package contents; if CLI-only, keep as cask with `ponytail:` comment

## Failure Modes & Decision Forks

- **Failure mode**: `darwin-rebuild switch` fails — **cause**: flake eval error, unsupported option, or nix-darwin version mismatch — **fallback**: read error, fix flake, retry; use `darwin-rebuild rollback` if system is broken
- **Failure mode**: auser password clobbered — **cause**: nix-darwin's `users.users.auser` resets password — **fallback**: STOP, set `passwordFile` or omit password management, report to user
- **Decision fork**: If `homebrew.onActivation.cleanup = "zap"` would remove wanted personal casks → set `cleanup = "none"` for first deploy
- **Decision fork**: If `orbstack` nix package is CLI-only → keep orbstack as a cask, document with `ponytail:` comment
- **Decision fork**: If `nix flake check` fails on a `system.defaults` key → comment it out with `ponytail:` comment, fall back to osx-settings.py

## Dependencies & Sequencing

- Depends on: None (authors fresh, doesn't need git-filter-repo)
- Unblocks:
  - story-02-001-cross-repo-move (replaces these fresh modules with history-retained versions from levonk-nix-config)
  - story-03-001-playbook-rewrite (configure playbook calls this flake)

## Definition of Done

- [x] All verification commands from sub-tasks pass
- [x] `nix flake check` exits 0
- [!] `darwin-rebuild switch` succeeds on lzkmbp2016 and is idempotent
- [!] `darwin-rebuild rollback` works
- [x] No home-manager references in the darwin directory
- [x] apps.yml updated (casks → nix packages)
- [x] No files outside the in-scope list are modified

## STOP Conditions

Stop and report if:
- `darwin-rebuild switch` on lzkmbp2016 fails in a way that `darwin-rebuild rollback` doesn't fix
- nix-darwin's `users.users.auser` clobbers the auser password (UNRESOLVED in PRD)
- A moved module has import dependencies on levonk-nix-config's home-manager modules (would pull in home-manager)
- `nix flake check` fails on a key that can't be worked around

### Decision Forks (Contingency Paths)
- If `homebrew.onActivation.cleanup = "zap"` removes wanted casks → set `cleanup = "none"` initially
- If `orbstack` nix package is CLI-only → keep as cask with `ponytail:` comment
- If a `system.defaults` key is unsupported → comment out, fall back to osx-settings.py

## Maintenance Notes

- This story authors modules fresh in infrahub. Story 02-001 will REPLACE these with history-retained versions from levonk-nix-config (via git-filter-repo). The content should be identical — 02-001 just adds git blame history.
- After 02-001, the fresh files from this story are overwritten. Don't be confused by this — it's intentional.
- lzkmbp2018's `containerRuntime` is UNRESOLVED — default to `"orbstack"`, verify via SSH before deploying to that host.
- Reviewers: confirm no home-manager, no secrets, OS auto-install OFF, apps via Nix not casks.

## Commit Conventions

- `feat(nix-darwin): author flake with system modules and per-host configs`
- `feat(apps): move orbstack and rustdesk from casks to nix packages`

## Changelog

- 2026-07-06: initialized story file
- 2026-07-12: Tasks 1-9 completed. flake.nix, all modules, host configs, and apps.yml authored. nix flake check exits 0, nix flake show lists both darwinConfigurations. Task 10 (local validation via darwin-rebuild switch) BLOCKED — requires interactive sudo/destructive operation on real hardware. Acceptance criteria requiring darwin-rebuild switch marked [!] blocked.
