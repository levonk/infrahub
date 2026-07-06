---
# Product Requirements Document (PRD)

## Introduction / Overview
- **Feature name:** nix-darwin migration for macOS fleet management
- **Summary:** Replace the imperative macOS system configuration in infrahub's Ansible playbook with a declarative nix-darwin flake. Move the darwin system-level modules from `levonk-nix-config` (never deployed) into infrahub as the single source of truth for macOS system config. Drop home-manager entirely — the daily user's home directory is already managed by the `levonk/dotfiles` chezmoi repo. Keep the Ansible bootstrap fast and minimal (install Nix, create admin user, SSH, VPN); apply nix-darwin system config as a separate, idempotent "configure" phase.
- **Context:**
  - infrahub currently manages 2 macOS hosts (`lzkmbp2016`, `lzkmbp2018`) via an Ansible playbook that does imperative system surgery: `dscl`/`sysadminctl` for the admin user, hand-written `nix.conf`, manual `.app` symlinks to `/Applications`, `community.general.homebrew_cask` loops, `systemsetup -setremotelogin`.
  - `levonk-nix-config` has a nix-darwin scaffold (`darwinConfigurations.mac-aarch64`, `mac-x86_64` + darwin modules). Its home-manager-based user profiles overlap with what the `levonk/dotfiles` chezmoi repo already manages.
  - First real `darwin-rebuild switch` must be validated locally on a Mac before being wired into Ansible.
  - A new machine will be bootstrapped soon using the **current** (pre-migration) playbook — bootstrap must stay fast and offload to Ansible; the nix-darwin migration is a follow-up, not a blocker for that bootstrap.

## Goals
- **G1.** Single source of truth for macOS system configuration lives in infrahub (declarative nix-darwin flake).
- **G2.** The system-level functionality from `levonk-nix-config`'s darwin modules is preserved: `system.defaults` (dock/finder/loginwindow/screencapture/screensaver/SoftwareUpdate/com.apple.commerce), the privacy defaults (`privacy-darwin.nix`), homebrew integration (`homebrew.nix`), and nix settings/cache (`nix/settings.nix`, `nix/cache.nix`).
- **G3.** No home-manager. The daily user's home directory (zsh, vim, ssh config, gpg-agent, dev tool dotfiles) is owned by `levonk/dotfiles` (chezmoi), not nix-darwin.
- **G4.** The Ansible macOS bootstrap playbook shrinks to: install Nix (multi-user daemon) → create `auser` admin → enable SSH → join Tailscale/Netbird (vault secrets). System config application (`darwin-rebuild switch`) becomes a separate idempotent "configure" phase invoked after bootstrap.
- **G5.** `levonk-nix-config`'s darwin hosts and darwin system modules are retired (moved out). Its Linux home-manager configs remain untouched.
- **G6.** On-demand macOS software updates (`softwareupdate --install --all`) are triggerable via an Ansible task, separate from the automatic-update defaults already in `system.defaults.SoftwareUpdate`.
- **G7.** The sudo-requiring non-defaults settings from `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` (`pmset`, `chflags /Volumes`, `windowserver`) move to Ansible tasks sharing one `become` session. User-level `defaults write` settings (~130) stay in chezmoi — they're per-user preferences that nix-darwin's system-level `system.defaults` can't reliably manage (system defaults are overridden by user-level prefs). After the move, the chezmoi script requires **zero sudo calls** (user-level `defaults write` and `killall` of user processes don't need root), eliminating all 11 sudo prompts. A comment block in the script documents the three-layer split (nix-darwin / Ansible / chezmoi) so future edits go to the right layer.

## User Stories
- **US1.** As the fleet owner, I want to add a new Mac to the fleet by bootstrapping it fast (Nix + admin user + SSH + VPN) and then applying a declarative system config, so that every Mac converges to the same system state without per-host imperative commands.
- **US2.** As the fleet owner, I want macOS system settings (dock, finder, software-update policy, privacy defaults, homebrew casks) defined in one flake in infrahub, so that I don't maintain two repos with darwin config.
- **US3.** As the fleet owner, I want my daily user's home directory managed by chezmoi (dotfiles repo) and the system managed by nix-darwin (infrahub), so that the two concerns never overlap.
- **US4.** As someone using Nix, I want to validate the nix-darwin flake by running `darwin-rebuild switch` directly on a Mac before it's wired into Ansible, so that I debug flake errors without Ansible in the loop.

## Functional Requirements

### FR-1 — nix-darwin flake in infrahub
infrahub contains a nix-darwin flake at `shared/active/02-config/nix/darwin/flake.nix` with `darwinConfigurations` for `lzkmbp2016` and `lzkmbp2018`, plus shared darwin modules under `shared/active/02-config/nix/darwin/modules/`.
- **Expected observation:** `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` succeeds on `lzkmbp2016` and applies system settings without error. `nix flake show ./shared/active/02-config/nix/darwin` lists `darwinConfigurations.lzkmbp2016` and `darwinConfigurations.lzkmbp2018`.

### FR-2 — Move darwin system modules from levonk-nix-config (retain history)
The following files are moved from `levonk-nix-config` into infrahub under `shared/active/02-config/nix/darwin/modules/`, preserving git history via `git filter-repo` (cross-repo `git mv` is not possible):
- `modules/system/darwin/defaults.nix` → `modules/system/defaults.nix`
- `modules/system/darwin/homebrew.nix` → `modules/system/homebrew.nix`
- `modules/components/nix/settings.nix` → `modules/nix/settings.nix`
- `modules/components/nix/cache.nix` → `modules/nix/cache.nix`
- `modules/security/privacy-darwin.nix` → `modules/security/privacy-darwin.nix`
- **Expected observation:** `git log --follow shared/active/02-config/nix/darwin/modules/system/defaults.nix` in infrahub shows commit history originating from `levonk-nix-config`. The moved files are byte-identical in content to their origin (modulo import-path fixes noted in FR-3).

### FR-3 — Fix import paths in moved modules
Moved modules that referenced `levonk-nix-config`-internal paths are updated to their new infrahub locations. Specifically: `privacy-darwin.nix` is imported by a security entry point; the host configs import the relocated module paths.
- **Expected observation:** `nix flake check ./shared/active/02-config/nix/darwin` reports no "path does not exist" / import errors. `rg "levonk-nix-config|../../modules/components|../../modules/system/darwin" shared/active/02-config/nix/darwin/` returns no matches (all paths rewritten).

### FR-4 — Per-host darwinConfiguration with auser + container runtime
Each `darwinConfigurations.<host>` imports the shared system modules and sets:
- `services.nix-daemon.enable = true`
- `system.stateVersion = 4`
- `users.users.auser` (admin group, home `/Users/auser`) — replacing the imperative `sysadminctl`/`dscl` creation in the current playbook
- `infra.fleet.containerRuntime` = `"orbstack"` (lzkmbp2016, x86) or `"apple-container"` (lzkmbp2018 if macOS 26+ ARM; else `"orbstack"`) — drives which homebrew casks are installed
- **Expected observation:** After `darwin-rebuild switch --flake .#lzkmbp2016`, `dscl . -read /Users/auser UniqueID` succeeds and `id auser` shows `admin` group membership. `infra.fleet.containerRuntime` is selectable per host and the homebrew cask list reflects it (OrbStack present only when runtime is `orbstack`).

### FR-5 — Prefer Nix packages over Homebrew casks; fleet cask list re-evaluated
The nix-darwin flake uses `environment.systemPackages` for all apps available in nixpkgs. Homebrew casks are only for apps NOT in nixpkgs. Verified availability in nixpkgs (x86_64-darwin, nixpkgs-unstable):
- `orbstack` — **in nixpkgs** (2.2.1-20628) → install via Nix, not cask
- `rustdesk` — **in nixpkgs** (1.4.8) → install via Nix, not cask
- `firefox-devedition-bin` — **in nixpkgs** (152.0b8) → already in Nix (current infrahub flake)
- `raycast` — **in nixpkgs** (1.104.17) → already in Nix (current infrahub flake)
- `cmux` — already in Nix (current infrahub flake)
- `git`, `zsh`, `tailscale`, `netbird` — already in Nix (current infrahub flake)

The moved `homebrew.nix` from levonk-nix-config is edited: its personal cask list (firefox, firefox-developer-edition, google-chrome, visual-studio-code, iterm2, docker, raycast, alt-tab, hiddenbar, stats, itsycal, figma, spotify, slack, discord, signal, telegram, zoom, vlc, keka, kap, keycastr) is **dropped** — many of those are in nixpkgs and the rest are personal apps out of scope for fleet. The fleet cask list (`infra_app_brew_casks` in `apps.yml`) is re-evaluated: since both `orbstack` and `rustdesk` are in nixpkgs, the fleet cask list becomes **empty** (or near-empty — only apps confirmed NOT in nixpkgs remain as casks). The `homebrew.enable = true` is kept (Homebrew may still be useful for ad-hoc installs), but `homebrew.casks` is empty or minimal for fleet.

**Behavior difference noted**: nix-installed macOS GUI apps update via `darwin-rebuild switch` with an updated flake lock (declarative, reproducible), not via `brew upgrade` auto-update. This is a feature for fleet management — no surprise updates — but differs from cask behavior. The `homebrew.onActivation.autoUpdate` and `upgrade` settings are kept for any residual casks, but the goal is to minimize cask dependency.

`apps.yml` is updated: `infra_app_brew_casks` becomes `[]` (empty) or contains only apps verified absent from nixpkgs. A new `infra_app_nix_gui_packages` entry (or the existing one) includes `orbstack` and `rustdesk` alongside the existing `firefox-devedition-bin`, `raycast`, `cmux`.
- **Expected observation:** After `darwin-rebuild switch`, `nix profile list` (or `darwin-rebuild`'s system profile) includes `orbstack` and `rustdesk`. `brew list --cask` shows no fleet casks (or only apps not in nixpkgs). `rg "orbstack\|rustdesk" shared/active/02-config/ansible/infrastructure/apps.yml` shows them under `infra_app_nix_gui_packages` (or equivalent nix package list), not under `infra_app_brew_casks`. The moved `homebrew.nix` has an empty or minimal `casks = [ ]` list.

### FR-6 — System defaults preserved (keep functionality, with OS auto-install OFF)
All `system.defaults` keys from `levonk-nix-config/modules/system/darwin/defaults.nix` are present in the moved `defaults.nix`: dock.autohide, dock.mru-spaces, finder.* (AppleShowAllExtensions, FXPreferredViewStyle, NewWindowTarget, NewWindowTargetPath, FinderSpawnTab, ShowPathbar, ShowStatusBar, FXDefaultSearchScope, FXEnableExtensionChangeWarning, _FXSortFoldersFirst), loginwindow.LoginwindowText, screencapture.location, screensaver.askForPassword, SoftwareUpdate.*, com.apple.commerce.AutoUpdate.

**Deliberate deviation from levonk-nix-config's values — OS updates do NOT auto-install (user requirement):**
- `SoftwareUpdate.AutomaticCheckEnabled = true` — keep checking for updates
- `SoftwareUpdate.AutomaticDownload = true` — keep downloading so they're ready
- `SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false` — **changed from `true`**: macOS OS updates are NOT auto-installed; they're installed on demand via FR-11 (`softwareupdate --install --all`)
- `SoftwareUpdate.ConfigDataInstall = false` — **changed from `true`**: config-data/security responses are OS-level, not apps; manual via FR-11
- `SoftwareUpdate.CriticalUpdateInstall = false` — **changed from `true`**: critical security responses are OS-level, not apps; manual via FR-11
- `com.apple.commerce.AutoUpdate = true` — **unchanged**: App Store app updates DO auto-update (apps are fine)

The moved `defaults.nix` is edited to set the three OS-auto-install keys to `false` (this is a content change to a moved file, like `homebrew.nix` per FR-5). The comment block in `defaults.nix` documenting what each setting corresponds to in System Preferences is updated to reflect: "Install macOS updates: Off", "Install Security Responses and system files: Off", "Install application updates from the App Store: On".
- **Expected observation:** After `darwin-rebuild switch`, `defaults read com.apple.dock autohide` returns `1`; `defaults read com.apple.finder AppleShowAllExtensions` returns `1`; `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled` returns `1`; `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` returns `0`; `defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall` returns `0`; `defaults read /Library/Preferences/com.apple.commerce AutoUpdate` returns `1`. `loginwindow` shows "Managed by Nix".

### FR-7 — Privacy defaults preserved (keep functionality)
All `system.defaults` keys from `levonk-nix-config/modules/security/privacy-darwin.nix` are present in the moved `privacy-darwin.nix` and imported by each host config: `com.apple.SubmitDiagInfo`, `com.apple.AdLib`, `com.apple.iCloud`, `com.apple.Safari`, `com.apple.Spotlight`, `com.apple.Maps`, `com.apple.Health`, `com.apple.imessage`, `com.apple.Photos`.
- **Expected observation:** After `darwin-rebuild switch`, `defaults read com.apple.SubmitDiagInfo AutoSubmit` returns `0`; `defaults read com.apple.AdLib allowApplePersonalizedAdvertising` returns `0`; `defaults read com.apple.Safari SendDoNotTrackHTTPHeader` returns `1`.

### FR-8 — Nix settings preserved (keep functionality)
`nix.settings` from `levonk-nix-config/modules/components/nix/settings.nix` and `cache.nix` are present: `experimental-features = [ "nix-command" "flakes" ]`, `accept-flake-config = true`, `auto-optimise-store = true`, `keep-outputs = true`, `keep-derivations = true`, `flake-registry` URL, `substituters` (cache.nixos.org), `trusted-public-keys`. This replaces the imperative `/etc/nix/nix.conf` copy task in the current playbook.
- **Expected observation:** After `darwin-rebuild switch`, `/etc/nix/nix.conf` contains `experimental-features = nix-command flakes` and `auto-optimise-store = true`. `nix config show experimental-features` includes `flakes`. The current playbook's `Ensure nix.conf has flakes...` task is deleted (see FR-10).

### FR-9 — Bootstrap playbook shrinks to minimal fast phase
`shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` is reduced to:
1. Create `auser` admin user (kept — needed before nix-darwin can manage it; nix-darwin's `users.users.auser` will subsequently own it)
2. Enable Remote Login (SSH)
3. Install Nix multi-user daemon (kept — prerequisite for `darwin-rebuild`)
4. Join Tailscale (vault auth key)
5. Join Netbird (optional, vault setup key)
The following tasks are **deleted** from the playbook (now owned by nix-darwin via FR-6/7/8 and the configure phase FR-11): `Ensure nix.conf has flakes...`, `Restart nix-daemon to pick up config`, `Copy nix flake to target host`, `Install host apps via nix flake`, `Symlink GUI .app bundles to /Applications`, `Install Homebrew` (nix-darwin `homebrew.enable` installs/owns Homebrew), `Install Homebrew cask apps`, the OrbStack/Apple-Container check/report tasks, Homebrew version report.
- **Expected observation:** `just ansible-bootstrap-macos-check` (`--check --diff`) shows only the 5 retained task blocks. The deleted task names do not appear in `rg "Ensure nix.conf|Symlink GUI|Install Homebrew cask|Copy nix flake" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml`. Bootstrap runtime on a fresh machine is dominated by the Nix installer download, not by per-cask brew loops.

### FR-10 — New "configure" phase: darwin-rebuild via Ansible
A new playbook `shared/active/02-config/ansible/playbooks/configure-macos-host.yml` (or a tagged block in the existing playbook) runs `darwin-rebuild switch --flake <flake-path>#<host>` on the target, where the flake is copied/cloned to the target first. This is the idempotent system-config application, run **after** bootstrap. A `just ansible-configure-macos` command is added to the justfile.
- **Expected observation:** `just ansible-configure-macos` runs `darwin-rebuild switch` on each host in `macos_hosts` and exits 0. Re-running it produces no changes (idempotent). The justfile contains `ansible-configure-macos` and `ansible-configure-macos-internal` recipes mirroring the `ansible-bootstrap-macos` pattern.

### FR-11 — On-demand softwareupdate task
A separate Ansible task (tagged `os-update`) runs `softwareupdate --install --all --restart` on demand. This is **not** run automatically during bootstrap or configure — it's an explicit on-demand invocation. The automatic-update *settings* are owned by nix-darwin (FR-6, `system.defaults.SoftwareUpdate`).
- **Expected observation:** `just ansible-macos-os-update` (new recipe) triggers `softwareupdate --install --all --restart` on the target. `rg "softwareupdate" shared/active/02-config/ansible/playbooks/` finds the task. The task is tagged `os-update` and is not in the default bootstrap/configure tag set.

### FR-12 — Retire levonk-nix-config darwin hosts
`levonk-nix-config`'s `darwinConfigurations.mac-aarch64` and `mac-x86_64` and their host files (`hosts/mac-aarch64/`, `hosts/mac-x86_64/`) are deleted. The `nix-darwin` flake input is removed from `levonk-nix-config/flake.nix`. The darwin modules listed in FR-2 are deleted from `levonk-nix-config` (they now live in infrahub). `levonk-nix-config`'s Linux `homeConfigurations` (wsl-dev, debian-remote, debian-gui, qubes-dev, nixos) and their modules are **untouched**.
- **Expected observation:** `rg "darwinConfigurations|nix-darwin" levonk-nix-config/flake.nix` returns no matches. `ls levonk-nix-config/hosts/mac-aarch64 levonk-nix-config/hosts/mac-x86_64` fails (deleted). `rg "mac-aarch64|mac-x86_64" levonk-nix-config/flake.nix` returns no matches. `levonk-nix-config/hosts/wsl-dev/`, `debian-remote/`, etc. still exist and are unchanged.

### FR-13 — Delete infrahub's redundant packages-only flake
`shared/active/02-config/nix/flake.nix` (the packages-only `host-apps`/`symlink-apps` flake) is deleted. Its responsibilities (CLI/GUI app install + `/Applications` symlinks) are subsumed by nix-darwin's `environment.systemPackages` + homebrew casks. The `macos_nix_flake_dir` inventory variable and the playbook tasks referencing it are removed.
- **Expected observation:** `ls shared/active/02-config/nix/flake.nix` fails. `rg "macos_nix_flake_dir|host-apps|symlink-apps" shared/active/02-config/ansible/ levonk/active/02-config/ansible/` returns no matches.

### FR-14 — Local-first validation path documented
The PRD/implementation includes a documented runbook step: before wiring `darwin-rebuild` into Ansible, validate the flake locally on `lzkmbp2016` by running `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` directly on the Mac. This is the de-risking step for a user new to Nix.
- **Expected observation:** A runbook markdown at `shared/active/08-docs/runbooks/nix-darwin-local-validation.md` documents the local `darwin-rebuild switch` command, expected output, and rollback (`darwin-rebuild rollback`). The runbook is referenced from the configure playbook header comment.

### FR-15 — Do NOT migrate user-level osx-settings.py defaults to nix-darwin
The ~140 `defaults write` settings in `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` are **user-level preferences** — they write to the current user's `~/Library/Preferences/` domain. nix-darwin's `system.defaults` writes to the **system-level** `/Library/Preferences/` domain, which acts as a fallback that is **overridden** by any user-level preference. Migrating user-level defaults to nix-darwin would:
- Not reliably apply to the daily-use user (micro) — existing user-level prefs shadow system-level ones
- Apply to auser (the admin account, which doesn't need them)
- Put per-user preferences in the wrong configuration layer

Only the genuinely **system-level** settings from osx-settings.py belong in nix-darwin, and those are already covered by FR-6/7/8 (the levonk-nix-config modules: SoftwareUpdate, loginwindow, privacy defaults). No separate `osx-defaults.nix` module is created.
- **Expected observation:** `rg "osx-defaults" shared/active/02-config/nix/darwin/` returns no matches (no new module created). The ~130 user-level settings remain in `osx-settings.py` (chezmoi). Only the ~7 sudo-requiring settings move out (FR-16).

### FR-16 — Move sudo-requiring non-defaults settings to Ansible
The following settings from `osx-settings.py` require `sudo` and are NOT `defaults write` (so nix-darwin's `system.defaults` can't manage them). They become Ansible tasks in the configure playbook (FR-10), sharing one `become: true` session:
- `pmset -a lidwake 1` — enable lid wakeup
- `pmset -a autorestart 1` — restart on power loss
- `pmset -a displaysleep 4` — display sleep after 4 min
- `pmset -c sleep 0` — no machine sleep while charging
- `pmset -b sleep 5` — machine sleep after 5 min on battery
- `chflags nohidden /Volumes` — show /Volumes in Finder
- `defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true` — HiDPI modes (system-level plist, nix-darwin may not cover `/Library/Preferences/com.apple.windowserver`; if it does via `system.defaults`, move it to FR-15)
- **Expected observation:** `just ansible-configure-macos` applies these via `become: true` in a single SSH session with one sudo prompt (Ansible's become password). `pmset -g | grep lidwake` returns `lidwake 1`; `pmset -g | grep autorestart` returns `autorestart 1`; `ls -lO /Volumes | grep hidden` shows no `hidden` flag. These tasks are tagged `pmset` and `chflags` and are idempotent (check before apply).

### FR-17 — User-level settings stay in chezmoi (not nix-darwin or Ansible)
The following settings from `osx-settings.py` stay in the dotfiles/chezmoi repo because they are **user-level preferences** (write to `~/Library/Preferences/`), not system defaults. nix-darwin's `system.defaults` writes to the system domain which is overridden by user-level prefs, so migrating these would not reliably apply to the daily-use user. This is the majority of the script (~130 settings): dock (tilesize, animations, autohide, hot corners, mineffect, minimize-to-application, etc.), finder (ShowAllFiles, QuitMenuItem, DisableAllAnimations, NewWindowTarget, desktop icons, ShowStatusBar, ShowPathbar, QLEnableTextSelection, _FXShowPosixPathInTitle, FXDefaultSearchScope, FXEnableExtensionChangeWarning, FXPreferredViewStyle, WarnOnEmptyTrash, FXInfoPanesExpanded, springing, DS_Store suppression), NSGlobalDomain (locale, save/print panel expansion, smart quotes/dashes/caps/period, window resize time, highlight color, sidebar size, scrollbars, transparency, window animations, persistence, keyboard repeat, AppleKeyboardUIMode, font smoothing, scroll direction, trackpad/mouse scaling, WebKitDeveloperExtras), universalaccess (reduceTransparency, zoom hotkeys/gestures/scroll/modifier/follows-focus), LaunchServices (LSQuarantine), systempreferences (NSQuitAlwaysKeepsWindows), helpviewer (DevMode), SoftwareUpdate ScheduleFrequency, AppleMultitouchTrackpad, BezelServices, screencapture (location, type, disable-shadow), screensaver (askForPassword, askForPasswordDelay), desktopservices (DS_Store suppression), dashboard (mcx-disabled), appstore (WebKitDeveloperExtras, ShowDebugMenu), TimeMachine, TextEdit, DiskUtility, ImageCapture, Safari (IncludeDevelopMenu, WebKitDeveloperExtras, AutoFill*, etc.), mail/mail-shared, terminal/Terminal, ActivityMonitor, messageshelper, BluetoothAudioAgent, iterm2 (PrefsCustomFolder, LoadPrefsFromCustomFolder), print.PrintingPrefs, and also:
- `chflags nohidden ~/Library` — user-level file flag, no sudo, chezmoi-owned
- `hidutil property --set '{"UserKeyMapping":...}'` — Caps Lock → Control remapping; runtime kernel property that resets on reboot; stays as a chezmoi login script (or a launchd agent added later)
- `CUSTOM_DOCK_APPS` — custom dock app layout; complex logic with fallback; stays in chezmoi (nix-darwin's dock module doesn't manage app pinning easily)
- `PlistBuddy` deep plist edits (Finder `IconViewSettings`: labelOnBottom, arrangeBy grid, gridSpacing 100, iconSize 40) — nested dict edits in `~/Library/Preferences/com.apple.finder.plist` that nix-darwin's `system.defaults.finder` doesn't cover; stay in chezmoi

**The sudo prompt problem is fully solved by FR-16** (moving the 7 sudo-requiring settings to Ansible). After that move, the remaining script has **zero sudo calls**: the ~130 user-level `defaults write` settings require no sudo (they write to the user's own preference domain), and `killall Finder`/`killall Dock`/`killall SystemUIServer` require no sudo (they kill the user's own processes). The `sudo -v` call at the top of `main()` is removed entirely. The 11 sudo prompts are eliminated completely, not just reduced.

**Service restarts are conditional**: the script already only calls `killall` when a setting actually changed (the `if changed: services_to_restart.add(svc)` logic at line 1360). If no user settings changed (idempotent re-run), no `killall` is called. This behavior is preserved — no change needed, just don't break it during the cleanup edit.

### FR-18 — Add layer-split comment to osx-settings.py
A comment block is added to the top of `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` (after the module docstring) explaining where each kind of macOS setting belongs, so future edits go to the right layer:

```python
# ──────────────────────────────────────────────────────────────────────────────
# macOS settings are split across three layers. Add new settings to the RIGHT one.
#
# 1. nix-darwin (system-level, /Library/Preferences/) — infrahub repo
#    Settings that apply to all users or require root: SoftwareUpdate policy,
#    loginwindow, privacy defaults (SubmitDiagInfo, AdLib, iCloud), nix settings,
#    homebrew integration. Managed by `darwin-rebuild switch` in
#    infrahub/shared/active/02-config/nix/darwin/. One root-level pass, no prompts.
#
# 2. Ansible (sudo-requiring non-defaults) — infrahub repo
#    Settings that need root but aren't `defaults write`: pmset (power management),
#    chflags /Volumes, windowserver HiDPI. Managed by `just ansible-configure-macos`
#    in infrahub. One `become: true` session via SSH.
#
# 3. THIS SCRIPT (user-level, ~/Library/Preferences/) — dotfiles/chezmoi repo
#    Per-user `defaults write` settings: dock, finder, Safari, mail, terminal,
#    keyboard, trackpad, hot corners, screenshots, iTerm2, etc. These write to
#    the current user's preference domain — no sudo needed. nix-darwin's
#    system.defaults CANNOT manage these reliably (system defaults are overridden
#    by user-level prefs). Run via `chezmoi apply` as the daily user.
#
#    Also here: hidutil (runtime key remap, resets on reboot), CUSTOM_DOCK_APPS
#    (complex dock pinning logic), PlistBuddy (nested plist edits nix-darwin
#    can't express), chflags ~/Library (user file flag).
#
#    Service restarts (killall Finder/Dock/SystemUIServer) only fire when a
#    setting actually changed — no restart on idempotent re-runs. No sudo needed
#    (these are the user's own processes).
# ──────────────────────────────────────────────────────────────────────────────
```

- **Expected observation:** The comment block exists at the top of `osx-settings.py` (after the docstring, before imports or after imports before the `commands` list). `rg "three layers" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` finds it. The comment names all three layers with their repos, domains, and examples.
- **Expected observation:** `osx-settings.py` in dotfiles retains ~130 user-level `defaults write` settings (unchanged). The 7 sudo-requiring settings (pmset, chflags /Volumes, windowserver) are removed from the script (moved to FR-16). The `sudo -v` call in `main()` is removed (no sudo needed at all). `rg "pmset\|chflags.*Volumes\|windowserver\|sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` returns no matches. The script's `killall` restarts remain but only fire on actual changes (existing conditional logic, preserved). Running the script prompts for zero passwords. The FR-18 comment block is present at the top.

## Non-Functional Requirements
- **NFR-1.** Idempotency: `darwin-rebuild switch` and the configure playbook produce no changes on a second consecutive run.
- **NFR-2.** No secrets in the flake: the flake contains no vault passwords or Tailscale auth keys (those remain Ansible/vault-owned). `auser` password is not set in nix-darwin (created by bootstrap playbook with vault password; nix-darwin manages the account attributes, not the password).
- **NFR-3.** Rollback path: `darwin-rebuild rollback` restores the previous system generation. Documented in the runbook (FR-14).
- **NFR-4.** Cross-architecture: flake supports both `x86_64-darwin` and `aarch64-darwin` (lzkmbp2016 is x86).
- **NFR-5.** No home-manager: `rg "home-manager" shared/active/02-config/nix/darwin/` returns no matches. The `home-manager` flake input is not added to infrahub's darwin flake.
- **NFR-6.** git mv for within-infrahub moves; git filter-repo for cross-repo (levonk-nix-config → infrahub) to retain history. No plain `cp` for files that have a git history.

## Current State

### Relevant files and their roles

**infrahub (target repo):**
- `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` — current imperative macOS bootstrap playbook (432 lines). Lines 150-201: Nix install + nix.conf (deleted by FR-9). Lines 203-261: Homebrew + flake copy + app install + symlink (deleted by FR-9). Lines 263-330: casks + container runtime checks (deleted by FR-9). Lines 332-432: Tailscale/Netbird/summary (retained, FR-9).
- `shared/active/02-config/nix/flake.nix` — packages-only flake (`host-apps`, `symlink-apps`). Deleted by FR-13.
- `shared/active/02-config/ansible/infrastructure/apps.yml` — defines `infra_app_nix_cli_packages`, `infra_app_nix_gui_packages`, `infra_app_brew_casks` (`orbstack`, `rustdesk`), `infra_app_container_runtime`. Source of the fleet cask list (FR-5).
- `levonk/active/02-config/ansible/inventories/macos-hosts.yml` — inventory: `lzkmbp2016` (x86, control machine), `lzkmbp2018` (remote). Defines `ansible_user: auser`, `macos_nix_flake_dir` (removed by FR-13), `macos_auser`, `macos_auser_ssh_public_key`.
- `levonk/active/02-config/ansible/inventories/group_vars/macos_hosts.yml` — `macos_container_runtime: "auto"`, `macos_netbird_management_url`.
- `justfile` lines 391-412 — `ansible-bootstrap-macos`, `ansible-bootstrap-macos-internal`, `ansible-bootstrap-macos-check`, `macos-manual-bootstrap` recipes. New `ansible-configure-macos` (FR-10) and `ansible-macos-os-update` (FR-11) recipes added here.
- `shared/scripts/bootstrap-macos-manual.sh` — minimal manual pre-bootstrap (SSH + auser + key). Unchanged.

**levonk-nix-config (source repo, darwin parts retired):**
- `flake.nix` — has `darwinConfigurations.mac-aarch64` and `mac-x86_64` (lines ~62-75), `nix-darwin` input. Modified by FR-12.
- `hosts/mac-aarch64/aarch64.nix`, `hosts/mac-x86_64/x86_64.nix` — host configs importing darwin modules + home-manager profiles. Deleted by FR-12.
- `modules/system/darwin/defaults.nix` — `system.defaults` (dock/finder/loginwindow/screencapture/screensaver/SoftwareUpdate/com.apple.commerce). Moved by FR-2; OS auto-install keys changed to `false` per FR-6 (user requirement: OS does not auto-update, apps do).
- `modules/system/darwin/homebrew.nix` — `homebrew` module with personal cask list (firefox, chrome, vscode, iterm2, slack, etc.). Moved by FR-2; cask list overridden by fleet list per FR-5.
- `modules/components/nix/settings.nix` — `nix.settings` (experimental-features, accept-flake-config, auto-optimise-store, keep-outputs/derivations, flake-registry). Moved by FR-2, preserved by FR-8.
- `modules/components/nix/cache.nix` — `nix.settings.substituters`/`trusted-public-keys`. Moved by FR-2, preserved by FR-8.
- `modules/security/privacy-darwin.nix` — `system.defaults` privacy keys (SubmitDiagInfo, AdLib, iCloud, Safari, Spotlight, Maps, Health, imessage, Photos). Moved by FR-2, preserved by FR-7.
- `modules/security/baseline.nix`, `modules/security/default.nix` — home-manager-based security (programs.ssh, programs.gpg, services.gpg-agent, home.packages pass/gopass/rhash/mtr/whois). **NOT moved** (home-manager; out of scope — owned by chezmoi/dotfiles repo).
- `modules/profiles/roles/{cli,gui,dev}.nix`, `modules/profiles/os/mac.nix` — home-manager role profiles. **NOT moved** (home-manager; out of scope).

**levonk/dotfiles (chezmoi, partially changed):**
- Owns the daily user's home directory (zsh, vim, ssh config, gpg-agent, dev tool dotfiles). Referenced by `dotfiles/AGENTS.md`. This is why home-manager is dropped (NFR-5) — chezmoi already owns `~/`.
- `home/current/dot_local/bin/executable_osx-settings.py` — 1393-line Python script applying ~170 macOS settings. ~130 are user-level `defaults write` (stay in chezmoi — nix-darwin's system-level `system.defaults` can't reliably manage per-user prefs). ~7 are sudo-requiring non-defaults (pmset, chflags /Volumes, windowserver) that move to Ansible (FR-16). ~15 are user-session/runtime (hidutil, CUSTOM_DOCK_APPS, PlistBuddy, ~/Library) that stay in chezmoi (FR-17). The script is edited in the dotfiles repo to remove only the 7 sudo-requiring settings.

### Existing code excerpts (will change)

Current playbook nix.conf task (deleted, FR-9) — `bootstrap-macos-host.yml:170-190`:
```yaml
- name: "Ensure nix.conf has flakes + nix-command + optimisation enabled"
  ansible.builtin.copy:
    dest: /etc/nix/nix.conf
    content: |
      experimental-features = nix-command flakes
      auto-optimise-store = true
      ...
```
Replaced declaratively by `modules/nix/settings.nix` → `nix.settings.experimental-features` (FR-8).

Current playbook auser creation (retained, FR-9) — `bootstrap-macos-host.yml:84-126`:
```yaml
- name: "Create admin user (auser)"
  ansible.builtin.command: >
    sysadminctl -addUser {{ macos_auser }} -password {{ vault_macos_auser_password }} -admin -home /Users/{{ macos_auser }}
```
Kept (nix-darwin's `users.users.auser` manages attributes after the account exists; the password stays vault-owned).

levonk-nix-config host config (deleted, FR-12) — `hosts/mac-x86_64/x86_64.nix`:
```nix
{ pkgs, ... }: {
  imports = [ ../../modules/system/darwin/defaults.nix ... ];
  users.users.useracct = { name = "useracct"; home = "/Users/useracct"; };
  home-manager.users.useracct = { ... };  # home-manager — dropped
}
```
Replaced in infrahub by a host config with `users.users.auser` and **no** `home-manager` block (FR-4, NFR-5).

### Repository conventions
- **Ansible modules manage containers — NEVER `docker compose`** (infrahub AGENTS.md). nix-darwin's homebrew module installs OrbStack as a cask; container runtime lifecycle remains Ansible-owned where applicable.
- **Vault edits via user handoff** (infrahub AGENTS.md): the `auser` password stays in `infrahub-levonk-all.vault.yml`; nix-darwin does not touch vault secrets.
- **Hybrid secret storage** (ADR-20260624001): no secrets in `shared/`. The darwin flake lives under `shared/active/02-config/nix/darwin/` and contains no secrets (NFR-2).
- **Infrastructure consolidation** (ADR-20260625001): `infra_*` variable naming for network/port/domain/storage. The new `infra.fleet.containerRuntime` option follows this spirit.
- **git mv for within-repo moves** (user instruction): any file relocation inside infrahub uses `git mv`. Cross-repo moves use `git filter-repo` to retain history (FR-2, NFR-6).
- **just recipes mirror the `*-internal` pattern** (justfile:391-412): new recipes follow `ansible-configure-macos` / `ansible-configure-macos-internal`.

### Design constraints
- No home-manager (user decision; home dir owned by chezmoi/dotfiles).
- Bootstrap stays minimal and fast — major nix-darwin application is a separate configure phase (user decision).
- levonk-nix-config's darwin *system* functionality is kept; its home-manager *user* functionality is not (owned by chezmoi).
- User is new to Nix — local validation before Ansible wiring (FR-14).

## Technical Considerations
- **nix-darwin version**: pin via flake input `nix-darwin.url = "github:LnL7/nix-darwin"` (matches levonk-nix-config's existing input). `nixpkgs` follows `nixpkgs-unstable` (matches existing infrahub flake.nix).
- **auser password**: nix-darwin's `users.users.auser` does not set the password (it can, but we choose not to — vault owns it). The bootstrap playbook creates the account with the vault password first; nix-darwin subsequently manages group membership, home, shell. If `darwin-rebuild switch` runs before the account exists, nix-darwin creates it without a usable password — so **bootstrap must run before configure** (enforced by FR-10 being a separate phase).
- **Container runtime selection**: a custom nix-darwin option `infra.fleet.containerRuntime` (enum `orbstack` | `apple-container`) drives conditional homebrew casks. `apple-container` requires macOS 26+ ARM and no cask install (built-in).
- **Flake location on target**: the configure playbook checks `git status --porcelain` on the control machine. If clean (not dirty), it git-clones infrahub to the target (e.g., `/Users/auser/.local/share/infrahub`) and runs `darwin-rebuild switch --flake /Users/auser/.local/share/infrahub/shared/active/02-config/nix/darwin#<host>`. If dirty (uncommitted local changes), it copies the `shared/active/02-config/nix/darwin/` tree to the target via `ansible.builtin.copy` instead. This supports both reproducible production applies and local dev iteration without committing.
- **Cross-repo history**: `git filter-repo` is added to `devbox.json` packages (user preference: always update devbox.json when a tool is needed). Run via `devbox run git filter-repo`. The filter-repo operation runs on a fresh clone of `levonk-nix-config` (not the working repo), filtering the darwin module paths, then the filtered history is merged into infrahub. Retains blame history. levonk-nix-config's own repo is then cleaned by FR-12's plain `git rm` deletion.
- **osx-settings.py migration scope**: nix-darwin's `system.defaults` writes to the **system-level** `/Library/Preferences/` domain, which is overridden by user-level prefs in `~/Library/Preferences/`. The ~130 `defaults write` settings in osx-settings.py are user-level and stay in chezmoi. Only the ~7 sudo-requiring non-defaults settings (pmset, chflags /Volumes, windowserver) move to Ansible (FR-16). The system-level defaults already in levonk-nix-config's modules (FR-6/7/8) are the only ones that belong in nix-darwin.

## Verification Approach
| Purpose | Command | Expected Result |
|---|---|---|
| Flake builds | `nix flake check ./shared/active/02-config/nix/darwin` (on a Mac) | exit 0, no eval errors |
| Flake lists hosts | `nix flake show ./shared/active/02-config/nix/darwin` | shows `darwinConfigurations.lzkmbp2016`, `darwinConfigurations.lzkmbp2018` |
| Local apply (lzkmbp2016) | `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` | exit 0, system defaults applied |
| Idempotency | re-run above | "no changes" / unchanged generations |
| Rollback | `darwin-rebuild rollback` | previous generation active |
| auser exists | `dscl . -read /Users/auser UniqueID` | succeeds |
| Defaults applied | `defaults read com.apple.dock autohide` | `1` |
| OS auto-install OFF | `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` | `0` |
| App auto-update ON | `defaults read /Library/Preferences/com.apple.commerce AutoUpdate` | `1` |
| Privacy applied | `defaults read com.apple.SubmitDiagInfo AutoSubmit` | `0` |
| nix.conf | `grep experimental-features /etc/nix/nix.conf` | `experimental-features = nix-command flakes` |
| No home-manager | `rg "home-manager" shared/active/02-config/nix/darwin/` | no matches |
| Old flake deleted | `ls shared/active/02-config/nix/flake.nix` | fails (No such file) |
| Playbook shrunk | `rg "Ensure nix.conf\|Symlink GUI\|Install Homebrew cask" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` | no matches |
| Configure recipe | `just ansible-configure-macos-check` (new, dry-run) | runs darwin-rebuild --check |
| OS update recipe | `just ansible-macos-os-update` | triggers softwareupdate --install --all |
| pmset via Ansible | `pmset -g \| grep lidwake` | `lidwake 1` |
| pmset via Ansible | `pmset -g \| grep autorestart` | `autorestart 1` |
| chflags via Ansible | `ls -lO /Volumes \| grep hidden` | no hidden flag |
| osx-settings.py sudo removed | `rg "pmset\|chflags.*Volumes\|windowserver\|sudo" dotfiles/.../executable_osx-settings.py` | no matches |
| osx-settings.py layer comment | `rg "three layers" dotfiles/.../executable_osx-settings.py` | found |
| No osx-defaults module | `rg "osx-defaults" shared/active/02-config/nix/darwin/` | no matches |
| Fleet apps via Nix | `nix profile list` (or system profile) includes orbstack, rustdesk | both present |
| Fleet casks empty | `brew list --cask` | no fleet casks (orbstack/rustdesk absent) |
| git-filter-repo in devbox | `devbox run -- command -v git-filter-repo` | found |
| levonk-nix-config retired | `rg "darwinConfigurations" levonk-nix-config/flake.nix` | no matches |
| Linux configs untouched | `ls levonk-nix-config/hosts/wsl-dev/default.nix` | exists, unchanged |
| Ansible lint | `just ansible-lint` | exit 0 |
| Justfile syntax | `just --list` (in devbox) | lists new recipes |

## Success Criteria (Machine-Checkable)
- [ ] `nix flake check ./shared/active/02-config/nix/darwin` exits 0 on a Mac
- [ ] `nix run nix-darwin -- switch --flake ./shared/active/02-config/nix/darwin#lzkmbp2016` succeeds on lzkmbp2016
- [ ] Re-running the above reports no changes (idempotent)
- [ ] `rg "home-manager" shared/active/02-config/nix/darwin/` returns no matches
- [ ] `rg "Ensure nix.conf|Symlink GUI|Install Homebrew cask" shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` returns no matches
- [ ] `ls shared/active/02-config/nix/flake.nix` fails
- [ ] `rg "darwinConfigurations" levonk-nix-config/flake.nix` returns no matches
- [ ] `levonk-nix-config/hosts/wsl-dev/default.nix` still exists and is byte-identical to pre-migration (`git -C levonk-nix-config diff -- hosts/wsl-dev/` empty)
- [ ] `just ansible-lint` exits 0
- [ ] `defaults read com.apple.dock autohide` returns `1` after configure
- [ ] `defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates` returns `0` after configure (OS does NOT auto-update)
- [ ] `defaults read /Library/Preferences/com.apple.commerce AutoUpdate` returns `1` after configure (apps DO auto-update)
- [ ] `defaults read com.apple.SubmitDiagInfo AutoSubmit` returns `0` after configure
- [ ] `pmset -g | grep lidwake` returns `lidwake 1` after configure (Ansible pmset task)
- [ ] `rg "pmset|chflags.*Volumes|windowserver|sudo" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` returns no matches (sudo fully eliminated from script)
- [ ] `rg "three layers" dotfiles/home/current/dot_local/bin/executable_osx-settings.py` finds the layer-split comment (FR-18)
- [ ] `rg "osx-defaults" shared/active/02-config/nix/darwin/` returns no matches (no user-level defaults module created)
- [ ] `nix profile list` (or system profile) includes `orbstack` and `rustdesk` (installed via Nix, not cask)
- [ ] `brew list --cask` shows no fleet casks (orbstack/rustdesk absent from cask list)
- [ ] `devbox run -- command -v git-filter-repo` succeeds (added to devbox.json)

## Out of Scope
- **Home directory / dotfiles management** — owned by `levonk/dotfiles` (chezmoi). nix-darwin does not install zsh plugins, vim config, ssh client config, gpg-agent, or dev-tool dotfiles.
- **home-manager** — not used anywhere in infrahub's darwin flake (NFR-5).
- **levonk-nix-config's Linux home-manager configs** — untouched (wsl-dev, debian-remote, debian-gui, qubes-dev, nixos).
- **levonk-nix-config's home-manager role/profile modules** (`modules/profiles/roles/*`, `modules/profiles/os/*`, `modules/security/baseline.nix`, `modules/components/dev/*`, etc.) — not moved; they're home-manager and out of scope.
- **Personal cask list** (firefox, chrome, vscode, iterm2, slack, discord, etc. from `levonk-nix-config/modules/system/darwin/homebrew.nix`) — not used by fleet. Fleet uses `infra_app_brew_casks` (orbstack, rustdesk).
- **The upcoming new-machine bootstrap** — uses the current playbook; this migration is a follow-up, not a prerequisite.
- **macOS major OS upgrades** (e.g., 15 → 26) — out of scope; only `softwareupdate --install --all` (FR-11) and automatic-update settings (FR-6). lzkmbp2016 runs OpenCore; OS auto-upgrade is intentionally disabled.
- **Multi-client fleet support beyond levonk** — this PRD covers the levonk client's `macos_hosts`. Generalizing the flake to other clients is a follow-up.
- **osx-settings.py user-level defaults (~130 settings)** — stay in chezmoi/dotfiles. nix-darwin's `system.defaults` writes to the system domain which is overridden by user-level prefs, so migrating them would not reliably apply to the daily-use user. Only the 7 sudo-requiring non-defaults settings move to Ansible (FR-16).

## Risk Assessment
- **Priority:** P2
- **Effort:** L (cross-repo move + flake authoring + playbook rewrite + local validation)
- **Risk:** MED — first real nix-darwin deployment; user is new to Nix; mitigated by FR-14 local-first validation and rollback (NFR-3).

## Success Metrics
- Bootstrap playbook line count drops by ~40% (deletion of nix.conf/flake/symlink/casks blocks).
- One `darwin-rebuild switch` command converges a Mac to full system config (vs. ~10 imperative Ansible tasks today).
- Zero home-manager references in infrahub's darwin flake.
- Single repo (infrahub) holds all macOS system config.

## Open Questions / UNRESOLVED
- `UNRESOLVED: Does nix-darwin's users.users.auser safely adopt an account created by sysadminctl without clobbering the password? — check: deploy bootstrap then configure on a throwaway Mac and verify auser can still sudo with the vault password after darwin-rebuild switch. If it clobbers, set users.users.auser.passwordFile or omit password management.`
- `RESOLVED: git-filter-repo availability — user preference is to add git-filter-repo to devbox.json (not use external tools). The implementation adds "git-filter-repo" to devbox.json packages and runs the cross-repo history move via devbox.`
- `RESOLVED: Flake-on-target strategy — if the infrahub repo is not dirty (clean working tree), the configure playbook git-clones infrahub to the target and runs darwin-rebuild from the clone (reproducible). If the repo is dirty (uncommitted changes), the playbook copies the flake tree to the target instead (so local dev iterations work without committing). The playbook checks `git status --porcelain` on the control machine to decide.`
- `RESOLVED: lzkmbp2016 details — confirmed by running on the machine: macOS 15.7.7 (Build 24G720), x86_64, MacBookPro13,3, running OpenCore (legacy macOS patcher). This is why OS auto-upgrade is disabled (FR-6) — OpenCore may not support the newest macOS. infra.fleet.containerRuntime = "orbstack" for lzkmbp2016 (x86, no Apple Container).`
- `UNRESOLVED: lzkmbp2018 macOS version/architecture — is it macOS 26+ ARM (apple-container) or older/x86 (orbstack)? — check: ssh auser@lzkmbp2018.tale-grouper.ts.net 'sw_vers; uname -m' and set infra.fleet.containerRuntime accordingly in its host config.`
- `UNRESOLVED: Does nix-darwin's homebrew module conflict with an existing Homebrew install on lzkmbp2016 (the control machine already has brew)? — check: run darwin-rebuild switch on lzkmbp2016 and observe whether homebrew.enable re-runs the installer or adopts the existing install; nix-darwin typically adopts existing brew.`
- `UNRESOLVED: Does levonk-nix-config's security/baseline.nix still build after privacy-darwin.nix is moved out? baseline.nix imports privacy-darwin.nix but baseline.nix is home-manager (out of scope, not moved). If privacy-darwin.nix is moved (not copied), levonk-nix-config's Linux security build breaks. — check: run nix flake check on levonk-nix-config after the move; if it fails, copy privacy-darwin.nix instead of moving it (keep a copy in levonk-nix-config for its Linux security module, move the canonical version to infrahub).`
- `UNRESOLVED: Can nix-darwin's system.defaults manage the /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled key (FR-16), or does it stay as an Ansible task? — check: test system.defaults."com.apple.windowserver".DisplayResolutionEnabled = true; in the flake and run darwin-rebuild switch; verify defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled returns 1. If nix-darwin writes to user-level not system-level, keep it as an Ansible task (FR-16).`

## Dependencies
- nix-darwin (`github:LnL7/nix-darwin`) — already used by levonk-nix-config.
- nixpkgs-unstable — already used by infrahub's current flake.nix.
- `git-filter-repo` — added to infrahub's `devbox.json` packages (user preference: update devbox.json when a tool is needed, not use external tools).
- The `levonk/dotfiles` chezmoi repo — owns home dir and the residual osx-settings.py settings (hidutil, CUSTOM_DOCK_APPS, PlistBuddy, ~/Library chflags). The osx-settings.py script is edited in that repo to remove the migrated settings (FR-15/16/17).
- infrahub devbox environment — for `just` recipes, ansible-lint, and git-filter-repo.

## Timeline / Milestones
1. **M1 — Local validation (de-risk):** author `shared/active/02-config/nix/darwin/flake.nix` + moved modules (FR-6/7/8 system-level only, no user-level osx-settings.py migration); run `darwin-rebuild switch` locally on lzkmbp2016; confirm FR-6/7/8 observations. (No Ansible changes yet.)
2. **M2 — Cross-repo move:** add `git-filter-repo` to devbox.json; run filter-repo on a clone of levonk-nix-config to move darwin modules into infrahub with history; retire levonk-nix-config darwin hosts (FR-12).
3. **M3 — Playbook rewrite:** shrink bootstrap (FR-9), add configure playbook + just recipes (FR-10) with clone-if-clean/copy-if-dirty logic, add os-update task (FR-11), add pmset/chflags/windowserver Ansible tasks (FR-16), delete old flake (FR-13).
4. **M4 — osx-settings.py cleanup:** edit `dotfiles/home/current/dot_local/bin/executable_osx-settings.py` to remove the 7 sudo-requiring settings (pmset, chflags /Volumes, windowserver) moved to FR-16, remove the `sudo -v` call (no sudo needed anymore), and add the FR-18 three-layer comment block. The ~130 user-level defaults and conditional `killall` restarts stay.
5. **M5 — Verify on second host:** run configure on lzkmbp2018 (after resolving UNRESOLVED on its arch/runtime).
6. **M6 — Runbook + ADR:** write `nix-darwin-local-validation.md` runbook (FR-14); record an ADR for the nix-darwin-source-of-truth decision and the user-level-vs-system-level defaults split.

## Maintenance Notes
- Future Mac additions: add a `darwinConfigurations.<newhost>` entry + inventory host; no playbook changes.
- Container runtime evolution: when macOS 26+ ARM becomes the fleet norm, flip `infra.fleet.containerRuntime` to `apple-container` per host; the orbstack cask drops out automatically.
- The `infra_app_brew_casks` list in `apps.yml` remains the fleet cask source of truth; the nix-darwin homebrew module reads from it (or a nix-side mirror) — keep them in sync when adding fleet casks.
- Reviewers should scrutinize: (a) no home-manager leakage into the flake, (b) no secrets in the flake, (c) bootstrap-before-configure ordering enforced, (d) levonk-nix-config Linux configs untouched.
- Follow-up explicitly deferred: generalizing the flake to non-levonk clients; migrating the personal cask list for daily-driver Macs that aren't fleet-managed.

## STOP Conditions
Stop and report back (do not improvise) if:
- `darwin-rebuild switch` on lzkmbp2016 fails in a way not covered by the runbook and rollback (`darwin-rebuild rollback`) does not restore the prior state.
- nix-darwin's `users.users.auser` clobbers the auser password set by the bootstrap playbook (UNRESOLVED above) — stop and decide password strategy before proceeding.
- `git filter-repo` is unavailable and the user does not want a plain copy (history loss) — stop and confirm the fallback.
- A moved module has import dependencies on levonk-nix-config modules that are out of scope (home-manager) — stop and surface the coupling rather than pulling home-manager in.
- The configure playbook needs to touch a file outside the documented scope (e.g., vault, Linux configs).
- `just ansible-lint` fails after the playbook rewrite and cannot be fixed without changing an out-of-scope role.

## Adversarial Review

| # | Challenge | What was tested | Result | Fix applied |
|---|---|---|---|---|
| 1 | "Keep functionality" vs "no home-manager" — FR-2 moves `privacy-darwin.nix` but `baseline.nix` imports it and is home-manager. Does moving `privacy-darwin.nix` break the source repo's security module? | Checked: `privacy-darwin.nix` is a `system.defaults` module (nix-darwin), not home-manager. `baseline.nix` imports it but `baseline.nix` itself is home-manager and is NOT moved (out of scope). levonk-nix-config's `baseline.nix` will still import `privacy-darwin.nix` after FR-12 deletes it. | Found — real coupling. | Added to FR-12: levonk-nix-config's `modules/security/baseline.nix` and `default.nix` must have the `privacy-darwin.nix` import removed/adjusted when the file is moved out, OR `privacy-darwin.nix` is copied (not moved) so levonk-nix-config's Linux security still compiles. Flagged as UNRESOLVED: "Does levonk-nix-config's security/baseline.nix still build after privacy-darwin.nix is moved out?" — check: `nix flake check levonk-nix-config` after the move. |
| 2 | FR-4 says nix-darwin manages `users.users.auser`, but FR-9 keeps the `sysadminctl -addUser` task. If configure runs before bootstrap, nix-darwin creates auser with no password. Is ordering enforced? | Checked: FR-10 makes configure a separate phase after bootstrap, but nothing enforces "bootstrap ran first" at runtime. | Found — implicit ordering. | Added explicit note in FR-4/FR-10: bootstrap must run before configure; the configure playbook should assert auser exists (`dscl . -read /Users/auser`) and fail with a clear message if not, rather than letting nix-darwin create a passwordless account. Added to STOP conditions. |
| 3 | FR-5 says use fleet cask list, but `homebrew.nix` from levonk-nix-config has a hardcoded personal cask list. If the file is moved verbatim (FR-2) then "overridden", where does the override happen? | Checked: moving `homebrew.nix` verbatim brings the personal casks with it. FR-5 says override but doesn't say how. | Found — ambiguous. | Clarified FR-5: the moved `homebrew.nix` is **edited** in infrahub to use the fleet cask list (orbstack, rustdesk), not moved verbatim. The personal cask list is dropped. FR-2's "byte-identical" claim is relaxed for `homebrew.nix` specifically (it's the one moved file whose content changes). Added note to FR-2. |
| 4 | FR-2 claims history retention via git filter-repo, but filter-repo rewrites the source repo's history too. Does retiring levonk-nix-config's darwin hosts (FR-12) interact with the filter-repo operation? | Checked: filter-repo on levonk-nix-config would rewrite its history; FR-12 deletes the darwin files. Order matters. | Found — potential history conflict. | Specified ordering in Timeline: M2 (filter-repo move) must happen as a clone-then-filter operation (filter-repo on a fresh clone of levonk-nix-config, push the filtered history to infrahub), NOT on levonk-nix-config's working repo. levonk-nix-config's own history is then cleaned by FR-12's plain deletion. Added to M2. |
| 5 | "softwareupdate --install --all --restart" (FR-11) restarts the machine. Is that safe over SSH from Ansible? | Checked: a restart will drop the SSH connection mid-task. | Found — known Ansible pattern. | FR-11 task must use `async`/`poll: 0` or `ignore_errors: true` with a documented `ponytail:` comment noting the connection drop is expected and the host should be re-checked after reboot. Added to FR-11. |
| 6 | FR-13 deletes `shared/active/02-config/nix/flake.nix` but the directory `shared/active/02-config/nix/` is the parent of the new `darwin/` flake (FR-1). Does deleting the old flake.nix leave the directory empty save for `darwin/`? | Checked: yes, `shared/active/02-config/nix/flake.nix` removed, `shared/active/02-config/nix/darwin/` remains. | No issue — consistent. | No fix needed; confirmed path layout. |
| 7 | Does infrahub's devbox.json need a nix-darwin package added for local `darwin-rebuild` on the control Mac? | Checked: devbox.json has no nix-darwin. `darwin-rebuild` comes from the `nix run nix-darwin` flake input, not a devbox package. | No issue — `nix run` supplies it. | No fix needed; noted that devbox.json is unchanged. |
| 8 | User requirement: "OS of the macs don't automatically update, apps are fine to auto-update." But levonk-nix-config's defaults.nix has `AutomaticallyInstallMacOSUpdates = true`, `ConfigDataInstall = true`, `CriticalUpdateInstall = true`. FR-6 originally said "preserve" those values. | Checked: the user's requirement directly contradicts the source values. "Keep functionality" means keep the *settings management*, not the specific auto-install-on values. | Found — contradiction with user requirement. | FR-6 updated: the three OS-auto-install keys are set to `false` (deliberate deviation, like homebrew.nix's cask list). `AutomaticCheckEnabled` and `AutomaticDownload` stay `true` (check + download, just don't install). `com.apple.commerce.AutoUpdate` stays `true` (apps auto-update). Verification table and success criteria updated with `AutomaticallyInstallMacOSUpdates = 0` and `AutoUpdate = 1` checks. |
| 9 | FR-15 originally proposed migrating ~140 user-level `defaults write` settings from osx-settings.py to nix-darwin's `system.defaults`. But `defaults write` writes to the user's `~/Library/Preferences/` domain, while nix-darwin's `system.defaults` writes to the system-level `/Library/Preferences/` domain. System defaults are OVERRIDDEN by user-level prefs. Would the migrated settings actually apply to the daily-use user (micro)? | Checked: no. If micro has existing user-level prefs (from running osx-settings.py before), they shadow the system-level ones. nix-darwin's system.defaults would apply to auser (who doesn't need them) and as fallbacks for new users, but not reliably to micro. | Found — fundamental layer mismatch. | FR-15 reversed: user-level settings stay in chezmoi. No osx-defaults.nix module created. Only the genuinely system-level settings (already in FR-6/7/8 from levonk-nix-config) go in nix-darwin. FR-17 expanded to explicitly list the ~130 user-level settings that stay. The sudo prompt problem is solved by FR-16 (moving 7 sudo settings to Ansible), not by migrating user settings to the wrong layer. |
| 10 | FR-16 moves pmset to Ansible, but pmset settings are power-management and may differ between a laptop (lzkmbp2016) and a desktop/fleet Mac. Are the pmset values appropriate for all hosts? | Checked: `pmset -b sleep 5` (battery) is laptop-specific; a desktop Mac has no battery. `pmset -c sleep 0` (charging) is also laptop-specific. | Found — host-type assumption. | FR-16 pmset tasks are conditional on host type (laptop vs desktop). For lzkmbp2016 (MacBookPro13,3, laptop) all 5 pmset settings apply. For lzkmbp2018 or future desktop Macs, the battery-related pmset settings (`-b sleep 5`) are skipped. Added note to FR-16: pmset tasks are tagged and conditional on `ansible_facts['product_name']` containing "Book" (laptop) vs not. |
| 11 | Does nix-darwin's system.defaults manage the /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled key (FR-16), or does it stay as an Ansible task? | Checked: nix-darwin may support `system.defaults."com.apple.windowserver".DisplayResolutionEnabled` but this writes to the system domain. The osx-settings.py script writes to `/Library/Preferences/com.apple.windowserver` explicitly with sudo, which IS the system domain — so this one is a legitimate nix-darwin candidate. | Partial — needs runtime check. | Left as UNRESOLVED: test in the flake during M1; if nix-darwin handles it, move to FR-6/8; if not, keep as Ansible task (FR-16). |
| 12 | User pointed out: "things shouldn't be installed via casks if they're in Nix." FR-5 originally said use the fleet cask list (orbstack, rustdesk). Are those in nixpkgs? | Checked via `nix search nixpkgs`: orbstack (2.2.1-20628), rustdesk (1.4.8), firefox-devedition-bin (152.0b8), raycast (1.104.17) — ALL in nixpkgs. The fleet cask list should be empty. | Found — casks unnecessary for fleet apps. | FR-5 rewritten: prefer Nix `environment.systemPackages` over Homebrew casks when the app is in nixpkgs. Fleet cask list becomes empty (both orbstack and rustdesk move to nix packages). Moved homebrew.nix's personal cask list is dropped. Behavior difference noted: nix apps update via flake lock, not brew auto-update (a feature for fleet). |

## Self-Grade

| # | Standard | Pass/Fail | Fix (if fail) |
|---|---|---|---|
| 1 | Every requirement states its expected observation | Pass | All 14 FRs have an "Expected observation" block. |
| 2 | Every unsettled assumption is marked UNRESOLVED with the exact check | Pass | 6 UNRESOLVED items, each with an exact check command/file. |
| 3 | Abort/STOP conditions exist for moments to stop and flag | Pass | 6 STOP conditions covering rebuild failure, password clobber, filter-repo unavailability, home-manager coupling, out-of-scope touches, lint failure. |
| 4 | Verification is spelled out (which runs, when, what pass looks like) | Pass | Verification Approach table with 15 checks; Success Criteria with 11 machine-checkable boxes; M1-M5 milestones sequence the verification. |
| 5 | It passed an adversarial review (challenges recorded, fixes applied) | Pass | 12 challenges recorded; 10 found issues, all fixed (coupling #1, ordering #2, ambiguity #3, history #4, reboot #5, OS-auto-install #8, user-level-layer-mismatch #9, pmset-laptop-assumption #10, windowserver-domain #11, casks-vs-nix #12); 2 confirmed no-issue (#6, #7). |
| 6 | It is autonomously implementable (mid-tier model can implement without asking questions) | Pass | File paths, module mappings, playbook line ranges, justfile recipe patterns, flake input URLs, osx-settings.py setting categorization, and verification commands are all concrete. Residual UNRESOLVED items (4) all have exact check commands and don't block initial implementation — they're runtime verification steps. |

All points pass. Ready for task generation upon user confirmation.

---
*Generated from the greenfield PRD workflow. Awaiting user feedback before task generation.*
