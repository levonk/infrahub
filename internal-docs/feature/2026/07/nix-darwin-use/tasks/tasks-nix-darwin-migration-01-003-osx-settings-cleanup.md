---
story_id: "01-003"
story_title: "Edit osx-settings.py — add three-layer comment, remove sudo settings"
story_name: "osx-settings-cleanup"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 1
parallel_id: 3
branch: "feature/current/nix-darwin-migration/story-01-003-osx-settings-cleanup"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["dotfiles/home/current/dot_local/bin/"]
priority: "MUST"
risk_level: "low"
tags: ["feat", "dotfiles", "chezmoi", "macos"]
due: "2026-07-13"
created_at: "2026-07-06"
updated_at: "2026-07-06"
---

## Summary

Edit `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` to: (1) add a three-layer comment block explaining where each kind of macOS setting belongs (nix-darwin / Ansible / chezmoi), (2) remove the 7 sudo-requiring settings (pmset x5, chflags /Volumes, windowserver HiDPI) that move to Ansible, and (3) remove the `sudo -v` call since no sudo is needed anymore. The ~130 user-level `defaults write` settings and conditional `killall` restarts stay unchanged. This eliminates all 11 sudo password prompts from the script.

## Current State

- **Relevant files and their roles:**
  - `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` — 1393-line Python script applying ~170 macOS settings via `defaults write`, `pmset`, `chflags`, `hidutil`, `PlistBuddy`. Run via chezmoi. The `commands` list (line 401) contains ~170 `Setting(...)` entries. The `main()` function (line 1333) calls `sudo -v` if any command needs sudo (line 1343-1350), then applies settings and restarts services via `killall`.
- **Existing code excerpts:**

  sudo-requiring settings to REMOVE (7 entries):
  ```python
  # line 407-412: chflags nohidden /Volumes (sudo=True)
  Setting(command="chflags nohidden /Volumes", description="Show /Volumes", type=CommandType.CHFLAGS, sudo=True),

  # lines 413-442: pmset x5 (all sudo=True)
  Setting(command="pmset -a lidwake 1", ..., sudo=True),
  Setting(command="pmset -a autorestart 1", ..., sudo=True),
  Setting(command="pmset -a displaysleep 4", ..., sudo=True),
  Setting(command="pmset -c sleep 0", ..., sudo=True),
  Setting(command="pmset -b sleep 5", ..., sudo=True),

  # lines 671-676: windowserver HiDPI (sudo=True)
  Setting(command="defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true", ..., sudo=True, section="Display"),
  ```

  sudo -v call to REMOVE:
  ```python
  # lines 1341-1350
  needs_sudo = any(c.sudo for c in commands)
  if needs_sudo:
      console.print("Authenticating sudo (enter your password once)...", style="info")
      try:
          sh.sudo("-v")
      except sh.ErrorReturnCode as e:
          ...
  ```

  killall restarts to KEEP (no sudo needed — user's own processes):
  ```python
  # lines 1367-1380
  if services_to_restart:
      for service in sorted(services_to_restart):
          run_command(cmd="killall", args=[service], sudo=True, quiet=True)
  ```
  NOTE: the `killall` calls pass `sudo=True` but killall of user processes (Finder, Dock, SystemUIServer) does NOT require sudo. Change `sudo=True` to `sudo=False` here, OR remove the `sudo` parameter since the user owns these processes.

- **Repository conventions:**
  - The script uses `uv run --script` (line 1) with inline dependencies (rich, sh)
  - `Setting` dataclass with `command`, `description`, `section`, `type`, `sudo` fields
  - `run_command()` handles sudo via `sh.Command("sudo")` (line 116)
  - `ponytail:` comments mark intentional simplifications (line 112)
  - The script is in the `dotfiles` repo (chezmoi), NOT infrahub. Changes are committed to `dotfiles`.
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Script runs | `uv run --script dotfiles/home/current/dot_local/bin/executable_osx-settings.py --help` (or just run it) | no sudo prompt, settings applied |
  | No sudo refs | `rg "pmset\|chflags.*Volumes\|windowserver\|sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` | no matches (except the comment block which mentions sudo contextually) |
  | Comment present | `rg "three layers" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` | found |
  | killall kept | `rg "killall" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` | found (service restarts remain) |

## Scope

**In scope:**
- Add the three-layer comment block (FR-18) after the module docstring
- Remove 7 `Setting(...)` entries: `chflags nohidden /Volumes`, `pmset -a lidwake 1`, `pmset -a autorestart 1`, `pmset -a displaysleep 4`, `pmset -c sleep 0`, `pmset -b sleep 5`, `defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled`
- Remove the `sudo -v` call block in `main()` (lines 1341-1350)
- Change `killall` calls from `sudo=True` to `sudo=False` (or remove the sudo param) — killall of user processes doesn't need root
- Remove the `needs_sudo` variable and `if needs_sudo:` block entirely

**Out of scope:**
- The ~130 user-level `defaults write` settings (stay unchanged)
- `hidutil` key remapping (stays — FR-17)
- `CUSTOM_DOCK_APPS` (stays — FR-17)
- `PlistBuddy` deep plist edits (stay — FR-17)
- `chflags nohidden ~/Library` (stays — FR-17, user-level, no sudo)
- The Ansible tasks that receive the 7 removed settings (story 03-001)
- Any infrahub changes

## Sub-Tasks

- [ ] Task 1 — Add three-layer comment block (FR-18)
  Insert the comment block after the module docstring (after line 11, the `# ///` block) and before the imports. The exact comment text is specified in FR-18 of the PRD. It explains:
  1. nix-darwin (system-level, /Library/Preferences/) — infrahub repo
  2. Ansible (sudo-requiring non-defaults) — infrahub repo
  3. THIS SCRIPT (user-level, ~/Library/Preferences/) — dotfiles/chezmoi repo
  **Verify**: `rg "three layers" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → found
  **Likely failure**: comment placement interferes with `uv run --script` metadata block — **cause**: the `# ///` block must be contiguous — **fallback**: place the comment AFTER the imports, before the `commands = [` list (line 401)

- [ ] Task 2 — Remove 7 sudo-requiring Setting entries
  Delete these 7 entries from the `commands` list:
  1. `chflags nohidden /Volumes` (line ~407-412)
  2. `pmset -a lidwake 1` (line ~413-418)
  3. `pmset -a autorestart 1` (line ~419-424)
  4. `pmset -a displaysleep 4` (line ~425-430)
  5. `pmset -c sleep 0` (line ~431-436)
  6. `pmset -b sleep 5` (line ~437-442)
  7. `defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true` (line ~671-676)
  **Verify**: `rg "pmset|chflags.*Volumes|windowserver" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → no matches (excluding the comment block which mentions them contextually)
  **Likely failure**: accidentally removing a non-sudo setting adjacent to a sudo one — **cause**: imprecise deletion — **fallback**: diff the file before/after; verify the ~130 user-level defaults are all still present

- [ ] Task 3 — Remove sudo -v call and needs_sudo logic
  In `main()` (line 1333+), remove:
  - `needs_sudo = any(c.sudo for c in commands)` (line 1343)
  - The entire `if needs_sudo:` block (lines 1344-1350) including the `sh.sudo("-v")` call
  **Verify**: `rg "sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → only matches in the comment block (contextual mentions) and possibly the `run_command` function's `sudo` parameter (which is now never called with `sudo=True` from the commands list)
  **Likely failure**: `run_command` still has `sudo` parameter and `sh.Command("sudo")` code — **cause**: the function supports sudo but no caller uses it — **fallback**: leave the `sudo` parameter in `run_command` (it's harmless dead code); OR remove it for cleanliness. Prefer leaving it — less diff, and `killall` calls still pass `sudo=False`.

- [ ] Task 4 — Fix killall calls (sudo=True → sudo=False)
  In the service restart block (lines 1372-1378), change `sudo=True` to `sudo=False` in the `killall` call. `killall Finder`/`Dock`/`SystemUIServer` kills the user's own processes — no root needed.
  **Verify**: `rg "killall" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → found, and the surrounding `run_command` call has `sudo=False` (or no sudo param)
  **Likely failure**: `killall` fails without sudo for some process — **cause**: the process is owned by root or another user — **fallback**: `killall` of Finder/Dock/SystemUIServer on macOS never needs sudo (they're user-session processes). If it fails, check which process and report.

- [ ] Task 5 — Verify script runs with zero sudo prompts
  Run the script on lzkmbp2016 and confirm it does not prompt for sudo at all.
  **Verify**: Run `uv run --script dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → no "Authenticating sudo" message, no password prompt, settings applied, service restarts work
  **Likely failure**: script errors because `needs_sudo` variable is referenced elsewhere — **cause**: incomplete removal — **fallback**: `rg "needs_sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → should return no matches

## Relevant Files

- `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` — the only file modified

## Acceptance Criteria

- [ ] `rg "three layers" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` finds the comment block
- [ ] `rg "pmset|chflags.*Volumes|windowserver" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` returns no matches (excluding comment block)
- [ ] `rg "needs_sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` returns no matches
- [ ] Running the script produces zero sudo password prompts
- [ ] The ~130 user-level `defaults write` settings are all still present (spot-check: `rg "com.apple.dock tilesize" dotfiles/.../osx-settings.py` → found)
- [ ] `killall` service restarts still work (Finder/Dock restart when their settings change)
- [ ] `rg "killall" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` → found with `sudo=False`

## Test Plan

- Manual: run the script on lzkmbp2016, confirm zero sudo prompts
- Manual: change a finder setting, re-run, confirm `killall Finder` fires and Finder restarts
- `rg` checks per Acceptance Criteria

## Observability

- The script uses `rich` console output — watch for "Authenticating sudo" (should be gone) and "Restarting Services" (should remain)

## Compliance

- N/A

## Risks & Mitigations

- Risk: removing a sudo setting that's actually needed by a user-level setting — Mitigation: the 7 removed settings are all system-level (pmset, /Volumes chflags, /Library/Preferences windowserver); none are prerequisites for user-level defaults
- Risk: `killall` without sudo fails — Mitigation: Finder/Dock/SystemUIServer are user-session processes; `killall` of them never needs sudo on macOS

## Failure Modes & Decision Forks

- **Failure mode**: script errors after removing `needs_sudo` — **cause**: `needs_sudo` referenced elsewhere — **fallback**: `rg "needs_sudo"` to find all references, remove them all
- **Failure mode**: `killall` fails without sudo — **cause**: process owned by root — **fallback**: report which process; Finder/Dock/SystemUIServer should never need sudo, so this indicates an unexpected process name
- **Decision fork**: If the `# ///` uv metadata block breaks when comment is inserted before imports → place comment after imports, before `commands = [` list

## Dependencies & Sequencing

- Depends on: None
- Unblocks:
  - story-03-001-playbook-rewrite (Ansible tasks receive the 7 removed settings — the script side must be done so the settings aren't applied twice)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] Script runs with zero sudo prompts on lzkmbp2016
- [ ] No `pmset`, `chflags /Volumes`, `windowserver`, `needs_sudo`, or `sudo -v` references remain
- [ ] Three-layer comment block present
- [ ] ~130 user-level defaults and killall restarts unchanged
- [ ] Only `osx-settings.py` is modified (`git status` in dotfiles repo)

## STOP Conditions

Stop and report if:
- Removing the sudo settings causes the script to error in a way that can't be fixed by removing dead `needs_sudo` references
- `killall` of Finder/Dock/SystemUIServer fails without sudo (unexpected — these are user processes)
- The `uv run --script` metadata block breaks and can't be fixed by repositioning the comment

### Decision Forks (Contingency Paths)
- If comment before imports breaks uv metadata → place after imports, before `commands = [`
- If `killall` fails without sudo → report the process name; do NOT re-add sudo

## Maintenance Notes

- The 7 removed settings (pmset, chflags /Volumes, windowserver) are now applied by Ansible (story 03-001, `just ansible-configure-macos`). They're system-level and require root — Ansible handles that with one `become: true` session.
- The three-layer comment is the source of truth for where new settings belong. Future additions to osx-settings.py should be user-level only.
- Reviewers: confirm zero sudo prompts, comment block present, ~130 user-level defaults intact.

## Commit Conventions

- `refactor(osx-settings): remove sudo-requiring settings, add three-layer comment`
- Commit to the `dotfiles` repo, not infrahub.

## Changelog

- 2026-07-06: initialized story file
