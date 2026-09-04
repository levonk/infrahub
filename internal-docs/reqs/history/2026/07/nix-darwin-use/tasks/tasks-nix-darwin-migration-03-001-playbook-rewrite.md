---
story_id: "03-001"
story_title: "Playbook rewrite — shrink bootstrap, add configure, os-update, pmset/chflags, delete old flake"
story_name: "playbook-rewrite"
prd_name: "nix-darwin-migration"
prd_file: "internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md"
phase: 3
parallel_id: 1
branch: "feature/current/nix-darwin-migration/story-03-001-playbook-rewrite"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "01-002", "01-003"]
parallel_safe: false
modules: ["infrahub/shared/active/02-config/ansible/", "infrahub/justfile", "infrahub/shared/active/02-config/nix/flake.nix"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "playbook", "macos"]
due: "2026-07-25"
created_at: "2026-07-06"
updated_at: "2026-07-06"
---

## Summary

Rewrite the macOS Ansible playbooks: shrink the bootstrap playbook to 5 tasks (auser, SSH, Nix, Tailscale, Netbird), create a new configure playbook that runs `darwin-rebuild switch` (with clone-if-clean/copy-if-dirty logic), add `just ansible-configure-macos` and `just ansible-macos-os-update` recipes, add pmset/chflags/windowserver Ansible tasks (the 7 settings removed from osx-settings.py in 01-003), delete the old packages-only `flake.nix`, and remove the `macos_nix_flake_dir` inventory variable. The configure playbook asserts auser exists before running darwin-rebuild (enforces bootstrap-before-configure ordering).

## Current State

- **Relevant files and their roles:**
  - `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` — 432-line playbook. Lines 150-201: Nix install + nix.conf (DELETE). Lines 203-261: Homebrew + flake copy + app install + symlink (DELETE). Lines 263-330: casks + container runtime checks (DELETE). Lines 84-126: auser creation (KEEP). Lines 128-148: SSH enable (KEEP). Lines 153-168: Nix install (KEEP). Lines 332-432: Tailscale/Netbird/summary (KEEP, trim summary).
  - `shared/active/02-config/nix/flake.nix` — packages-only flake. DELETE entirely (FR-13).
  - `justfile` lines 391-412 — `ansible-bootstrap-macos` recipes. Add new recipes here.
  - `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — defines `macos_nix_flake_dir` (line ~45). REMOVE this variable (FR-13).
  - `levonk/active/02-config/ansible/inventories/group_vars/macos_hosts.yml` — `macos_container_runtime: "auto"`. Keep (may be referenced by configure playbook for runtime selection).
- **Existing code excerpts:**

  Bootstrap playbook tasks to DELETE (nix.conf, flake copy, app install, symlink, casks):
  ```yaml
  # lines 170-190 (nix.conf — replaced by nix-darwin nix.settings)
  - name: "Ensure nix.conf has flakes + nix-command + optimisation enabled"
    ansible.builtin.copy:
      dest: /etc/nix/nix.conf
      content: |
        experimental-features = nix-command flakes
        ...

  # lines 235-261 (flake copy + app install + symlink — replaced by darwin-rebuild)
  - name: "Copy nix flake to target host"
    ansible.builtin.copy:
      src: "{{ playbook_dir }}/../nix/flake.nix"
      dest: "{{ macos_nix_flake_dir }}/flake.nix"
  - name: "Install host apps via nix flake"
    ansible.builtin.command: /nix/var/nix/profiles/default/bin/nix profile install {{ macos_nix_flake_dir }}#host-apps
  - name: "Symlink GUI .app bundles to /Applications"
    ansible.builtin.command: /nix/var/nix/profiles/default/bin/nix run {{ macos_nix_flake_dir }}#symlink-apps

  # lines 276-282 (cask install — replaced by nix-darwin homebrew module)
  - name: "Install Homebrew cask apps"
    community.general.homebrew_cask:
      name: "{{ item }}"
      state: present
    loop: "{{ macos_brew_casks }}"
  ```

  Justfile recipes pattern (to follow for new recipes):
  ```makefile
  # justfile lines 396-401
  ansible-bootstrap-macos:
      devbox run ansible-bootstrap-macos

  ansible-bootstrap-macos-internal:
      @echo "Bootstrapping macOS host (Nix, Homebrew, OrbStack, apps, Tailscale, Netbird)..."
      ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_BOOTSTRAP}} --vault-password-file ~/.ansible/vault_password --ask-become-pass
  ```

  Inventory variable to remove:
  ```yaml
  # levonk/active/02-config/ansible/inventories/macos-hosts.yml (line ~45)
  macos_nix_flake_dir: "/Users/auser/.local/share/infrahub-nix"
  ```

- **Repository conventions:**
  - Just recipes: `*-internal` pattern for the actual command, wrapper calls `devbox run` (justfile:396-401)
  - `MACOS_INVENTORY` and `PB_MACOS_*` path variables defined at top of macos section (justfile:393-394)
  - Ansible vault: `--vault-password-file ~/.ansible/vault_password` (AGENTS.md)
  - `become: false` at playbook level, `become: true` on individual tasks (macos-hosts.yml comment)
  - `community.docker` modules for containers (AGENTS.md) — not relevant here but noted
- **Build/test/lint commands:**
  | Purpose | Command | Expected Result |
  |---------|---------|-----------------|
  | Ansible lint | `just ansible-lint` | exit 0 |
  | Syntax check | `just ansible-syntax` | exit 0 |
  | Bootstrap dry-run | `just ansible-bootstrap-macos-check` | runs --check --diff, only 5 task blocks |
  | Configure recipe exists | `just --list \| grep configure-macos` | found |
  | OS update recipe exists | `just --list \| grep macos-os-update` | found |
  | Old flake deleted | `ls shared/active/02-config/nix/flake.nix` | fails |
  | No old task refs | `rg "Ensure nix.conf\|Symlink GUI\|Install Homebrew cask\|Copy nix flake" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` | no matches |

## Scope

**In scope:**
- Shrink `bootstrap-macos-host.yml` to 5 tasks: auser creation, SSH enable, Nix install, Tailscale join, Netbird join (FR-9)
- Create `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` (FR-10): asserts auser exists, clone-or-copy flake to target, runs `darwin-rebuild switch --flake <path>#<host>`
- Add pmset/chflags/windowserver Ansible tasks to configure playbook (FR-16): 5 pmset settings (laptop-conditional), `chflags nohidden /Volumes`, `windowserver DisplayResolutionEnabled`
- Create `shared/active/02-config/ansible/playbooks/macos-os-update.yml` or a tagged task (FR-11): `softwareupdate --install --all --restart` with async/poll for SSH survival
- Add `just ansible-configure-macos`, `just ansible-configure-macos-internal`, `just ansible-configure-macos-check`, `just ansible-macos-os-update` recipes to justfile (FR-10/11)
- Delete `shared/active/02-config/nix/flake.nix` (FR-13)
- Remove `macos_nix_flake_dir` from `levonk/active/02-config/ansible/inventories/macos-hosts.yml` (FR-13)
- Update bootstrap playbook summary to reflect new workflow

**Out of scope:**
- The nix-darwin flake itself (story 01-002/02-001)
- osx-settings.py changes (story 01-003)
- Runbook/ADR (story 04-001)
- Linux host playbooks
- The `bootstrap-macos-manual.sh` script (unchanged)

## Sub-Tasks

- [ ] Task 1 — Shrink bootstrap playbook (FR-9)
  Edit `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml`. Delete these task blocks:
  - `Ensure nix.conf has flakes...` (lines ~170-183)
  - `Restart nix-daemon to pick up config` (lines ~185-190)
  - `Copy nix flake to target host` (lines ~235-240)
  - `Install host apps via nix flake` (lines ~242-248)
  - `Symlink GUI .app bundles to /Applications` (lines ~250-261)
  - `Install Homebrew` (lines ~213-218)
  - `Install Homebrew cask apps` (lines ~276-282)
  - OrbStack/Apple-Container check/report tasks (lines ~289-330)
  - Homebrew version report (lines ~220-229)
  Keep: auser creation (84-126), SSH enable (128-148), Nix install (153-168), Tailscale (332-365), Netbird (367-411), summary (412-432, trimmed).
  Update the summary block to reflect: "Nix: installed. System config: run `just ansible-configure-macos` to apply. Tailscale: connected. Netbird: ..."
  **Verify**: `rg "Ensure nix.conf|Symlink GUI|Install Homebrew cask|Copy nix flake|Install Homebrew$" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` → no matches
  **Likely failure**: ansible-lint fails on the trimmed playbook — **cause**: undefined variables (e.g., `macos_brew_casks` still referenced) — **fallback**: `rg "macos_brew_casks\|macos_nix_flake_dir\|infra_app_brew_casks" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` → remove all references

- [ ] Task 2 — Create configure playbook (FR-10)
  Create `shared/active/02-config/ansible/playbooks/configure-macos-host.yml`:
  - `hosts: macos_hosts`, `become: false`
  - Pre-task: assert auser exists (`dscl . -read /Users/auser UniqueID`) — fail with clear message if not ("Bootstrap must run before configure — run `just ansible-bootstrap-macos` first")
  - Task: check if infrahub repo is clean on control machine (`git status --porcelain` locally)
  - Task (clean): git clone infrahub to target `/Users/auser/.local/share/infrahub`
  - Task (dirty): copy `shared/active/02-config/nix/darwin/` tree to target `/Users/auser/.local/share/infrahub-darwin/`
  - Task: run `darwin-rebuild switch --flake <target-path>#{{ inventory_hostname }}` on target
  - Task: pmset settings (FR-16, laptop-conditional via `ansible_facts['product_name']` containing "Book")
  - Task: `chflags nohidden /Volumes` (FR-16)
  - Task: `defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true` (FR-16, become: true)
  **Verify**: `just ansible-configure-macos-check` runs `--check --diff` without error (or at least without "file not found" errors)
  **Likely failure**: `darwin-rebuild` not found on target — **cause**: Nix not installed (bootstrap hasn't run) — **fallback**: the auser assertion should catch this first; if not, add a `darwin-rebuild` existence check
  **Decision fork**: If `git status --porcelain` on control machine is complex to evaluate in Ansible → use `ansible.builtin.command: git status --porcelain` with `register` and `changed_when: false`, then `when: result.stdout | length == 0` for clone, `when: result.stdout | length > 0` for copy

- [ ] Task 3 — Create os-update playbook/task (FR-11)
  Create `shared/active/02-config/ansible/playbooks/macos-os-update.yml` (or add a tagged task to configure playbook):
  - `softwareupdate --install --all --restart`
  - Use `async: 300` and `poll: 0` so the SSH connection drop doesn't fail the task
  - Add a `ponytail:` comment: "softwareupdate --restart drops SSH mid-task; async/poll:0 lets Ansible survive the reboot. Re-check the host after it comes back up."
  - Tag: `os-update`
  **Verify**: `rg "softwareupdate" shared/active/02-config/ansible/playbooks/` → found in macos-os-update.yml (or configure playbook)
  **Likely failure**: async task doesn't survive reboot — **cause**: async with poll:0 fires and forgets, but the reboot happens immediately — **fallback**: this is the expected pattern; the task completes from Ansible's perspective, the host reboots, and you re-check manually after

- [ ] Task 4 — Add justfile recipes (FR-10/11)
  Add to justfile after the `ansible-bootstrap-macos-check` recipe (line ~405):
  ```makefile
  PB_MACOS_CONFIGURE := ANSIBLE_ROOT + "/playbooks/configure-macos-host.yml"
  PB_MACOS_OS_UPDATE := ANSIBLE_ROOT + "/playbooks/macos-os-update.yml"

  ansible-configure-macos:
      devbox run ansible-configure-macos

  ansible-configure-macos-internal:
      @echo "Configuring macOS host (darwin-rebuild switch + pmset + chflags)..."
      ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_CONFIGURE}} --vault-password-file ~/.ansible/vault_password --ask-become-pass

  ansible-configure-macos-check:
      @echo "Dry-run macOS configure (check mode)..."
      ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_CONFIGURE}} --check --diff --vault-password-file ~/.ansible/vault_password --ask-become-pass

  ansible-macos-os-update:
      devbox run ansible-macos-os-update

  ansible-macos-os-update-internal:
      @echo "Installing macOS software updates (host will reboot)..."
      ansible-playbook -i {{MACOS_INVENTORY}} {{PB_MACOS_OS_UPDATE}} --vault-password-file ~/.ansible/vault_password --ask-become-pass --tags os-update
  ```
  **Verify**: `just --list | grep -E "configure-macos|macos-os-update"` → lists all new recipes
  **Likely failure**: justfile syntax error — **cause**: indentation or variable definition — **fallback**: `just --evaluate` to check variables parse

- [ ] Task 5 — Delete old flake and remove inventory variable (FR-13)
  - `git rm shared/active/02-config/nix/flake.nix`
  - Edit `levonk/active/02-config/ansible/inventories/macos-hosts.yml`: remove the `macos_nix_flake_dir` line and its comment
  **Verify**: `ls shared/active/02-config/nix/flake.nix` → fails; `rg "macos_nix_flake_dir" levonk/active/02-config/ansible/` → no matches
  **Likely failure**: other files reference `macos_nix_flake_dir` — **cause**: missed a reference — **fallback**: `rg "macos_nix_flake_dir" shared/ levonk/` to find all references and remove them

- [ ] Task 6 — Run ansible-lint and syntax check
  `just ansible-lint` and `just ansible-syntax`
  **Verify**: both exit 0
  **Likely failure**: lint errors on new playbooks — **cause**: missing task names, fqcn, etc. — **fallback**: fix lint errors per ansible-lint output; use `just ansible-lint` iteratively

## Relevant Files

- `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` — shrunk
- `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` — new
- `shared/active/02-config/ansible/playbooks/macos-os-update.yml` — new
- `justfile` — new recipes added
- `shared/active/02-config/nix/flake.nix` — deleted
- `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — `macos_nix_flake_dir` removed

## Acceptance Criteria

- [ ] `rg "Ensure nix.conf|Symlink GUI|Install Homebrew cask|Copy nix flake" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` returns no matches
- [ ] `ls shared/active/02-config/nix/flake.nix` fails (deleted)
- [ ] `rg "macos_nix_flake_dir" shared/ levonk/` returns no matches
- [ ] `just --list | grep configure-macos` finds the new recipes
- [ ] `just --list | grep macos-os-update` finds the os-update recipe
- [ ] `rg "softwareupdate" shared/active/02-config/ansible/playbooks/` finds the os-update task
- [ ] `rg "pmset" shared/active/02-config/ansible/playbooks/configure-macos-host.yml` finds pmset tasks
- [ ] `just ansible-lint` exits 0
- [ ] `just ansible-syntax` exits 0
- [ ] Configure playbook has auser assertion (`rg "dscl.*auser" configure-macos-host.yml` → found)

## Test Plan

- `just ansible-lint` — lint passes
- `just ansible-syntax` — syntax check passes
- `just ansible-bootstrap-macos-check` — dry-run shows only 5 task blocks
- `just ansible-configure-macos-check` — dry-run shows configure + pmset + chflags tasks
- `rg` checks per Acceptance Criteria

## Observability

- Configure playbook output shows `darwin-rebuild switch` diff (what changed)
- os-update task logs `softwareupdate` output before reboot

## Compliance

- Vault password file at `~/.ansible/vault_password` (AGENTS.md)
- No secrets in playbooks (vault variables only)
- `become: true` only on tasks that need root (pmset, chflags, windowserver)

## Risks & Mitigations

- Risk: configure playbook runs before bootstrap → nix-darwin creates passwordless auser — Mitigation: auser assertion at top of configure playbook (fail with clear message)
- Risk: `softwareupdate --restart` drops SSH, Ansible marks task as failed — Mitigation: `async: 300, poll: 0` pattern (fire-and-forget); document with `ponytail:` comment
- Risk: clone-if-clean/copy-if-dirty logic fails — Mitigation: test both paths; default to copy if the git status check fails

## Failure Modes & Decision Forks

- **Failure mode**: ansible-lint fails on new playbooks — **cause**: naming, fqcn, or variable issues — **fallback**: fix iteratively per lint output
- **Failure mode**: `darwin-rebuild switch` not found on target — **cause**: Nix not installed — **fallback**: auser assertion catches this; if not, add a `command -v darwin-rebuild` check
- **Failure mode**: pmset task fails on non-laptop — **cause**: `pmset -b sleep 5` on a desktop — **fallback**: `when: "'Book' in ansible_facts['product_name']"` guard on battery-specific pmset settings
- **Decision fork**: If `git status --porcelain` is hard to evaluate in Ansible → use `register` + `when: result.stdout | length == 0` for clone, `> 0` for copy
- **Decision fork**: If the configure playbook is too complex with both darwin-rebuild and pmset → split pmset/chflags into a separate `macos-power-management.yml` playbook

## Dependencies & Sequencing

- Depends on:
  - story-02-001-cross-repo-move (flake is final with history)
  - story-01-002-darwin-flake-authoring (flake exists to be called)
  - story-01-003-osx-settings-cleanup (sudo settings removed from script, now in Ansible)
- Unblocks:
  - story-04-001-runbook-adr (runbook references configure playbook)

## Definition of Done

- [ ] All verification commands from sub-tasks pass
- [ ] `just ansible-lint` and `just ansible-syntax` exit 0
- [ ] Bootstrap playbook shrunk to 5 tasks
- [ ] Configure playbook created with auser assertion + darwin-rebuild + pmset/chflags
- [ ] os-update playbook/task created
- [ ] Justfile recipes added
- [ ] Old flake deleted, inventory variable removed
- [ ] No files outside the in-scope list are modified

## STOP Conditions

Stop and report if:
- ansible-lint fails and can't be fixed without changing an out-of-scope role
- The configure playbook can't assert auser existence reliably (dscl check fails)
- `darwin-rebuild switch` can't be invoked via Ansible (path issues, SSH limitations)
- The clone-if-clean/copy-if-dirty logic can't be implemented in Ansible

### Decision Forks (Contingency Paths)
- If pmset in configure playbook is too complex → split into separate playbook
- If `git status --porcelain` check is flaky → default to copy (safer for local dev)
- If `darwin-rebuild` not in PATH on target → use full path `/nix/var/nix/profiles/default/bin/nix run nix-darwin -- switch ...`

## Maintenance Notes

- The configure playbook is idempotent — `darwin-rebuild switch` reports no changes on re-run.
- The os-update task is on-demand only (not in bootstrap or configure default tags). Run `just ansible-macos-os-update` when you want to install pending macOS updates.
- pmset settings are laptop-conditional — desktop Macs skip battery-specific settings.
- Reviewers: confirm auser assertion exists, pmset is laptop-conditional, os-update uses async/poll, no old flake references remain.

## Commit Conventions

- `feat(ansible): shrink bootstrap, add configure + os-update playbooks`
- `feat(justfile): add ansible-configure-macos and ansible-macos-os-update recipes`
- `refactor(nix): delete packages-only flake (replaced by nix-darwin)`

## Changelog

- 2026-07-06: initialized story file
