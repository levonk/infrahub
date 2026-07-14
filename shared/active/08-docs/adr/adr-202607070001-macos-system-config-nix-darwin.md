# ADR-202607070001: macOS System Configuration via nix-darwin

## Status
ACCEPTED

## Context

infrahub manages a fleet of macOS hosts (`lzkmbp2016`, `lzkmbp2018`) for the
levonk environment. Before this ADR, macOS system configuration was performed
by an imperative Ansible playbook that did system surgery: `dscl`/`sysadminctl`
for the admin user, hand-written `nix.conf`, manual `.app` symlinks to
`/Applications`, `community.general.homebrew_cask` loops, `systemsetup
-setremotelogin`. This was non-declarative, hard to reproduce, and overlapped
with both `levonk-nix-config` (which had a nix-darwin scaffold that was never
deployed) and `levonk/dotfiles` (which had an `osx-settings.py` script mixing
user-level `defaults write` with sudo-requiring `pmset`/`chflags` calls).

A migration was required to:
1. Make macOS system config declarative and reproducible.
2. Establish a single source of truth for system-level settings.
3. cleanly separate system-owned settings from user-owned settings.
4. Shrink the Ansible bootstrap to a minimal fast phase.

The full migration requirements are in the PRD at
`internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`.

## Decision

### nix-darwin flake owns system-wide macOS configuration

A nix-darwin flake at `shared/active/02-config/nix/darwin/flake.nix` is the
single source of truth for macOS system configuration. It defines
`darwinConfigurations` per host and imports shared modules:

- `modules/system/defaults.nix` — `system.defaults` (dock, finder,
  loginwindow, screencapture, screensaver, SoftwareUpdate policy,
  com.apple.commerce). OS auto-install is OFF (lzkmbp2016 runs OpenCore);
  App Store app auto-update remains ON.
- `modules/system/homebrew.nix` — Homebrew integration (cask list is empty or
  minimal; fleet apps come from nixpkgs via `environment.systemPackages`).
- `modules/nix/settings.nix` — `nix.settings` (experimental-features,
  auto-optimise-store, flake-registry). Replaces the imperative
  `/etc/nix/nix.conf` copy task.
- `modules/nix/cache.nix` — substituters and trusted-public-keys.
- `modules/security/privacy-darwin.nix` — privacy defaults
  (SubmitDiagInfo, AdLib, iCloud, Safari, Spotlight, Maps, Health, imessage,
  Photos).
- `modules/fleet/default.nix` — `infra.fleet.containerRuntime` option
  (`"orbstack"` | `"apple-container"`), `users.users.auser` admin account,
  fleet packages from nixpkgs.

Applied via `darwin-rebuild switch --flake .#<hostname>` (the
`osx-rebuild.sh` script in dotfiles wraps this — see Cross-References).

### Ansible bootstrap shrinks to a minimal fast phase

`shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml` is
reduced to:
1. Create `auser` admin user (needed before nix-darwin can manage it).
2. Enable Remote Login (SSH).
3. Install Nix multi-user daemon (prerequisite for `darwin-rebuild`).
4. Join Tailscale (vault auth key).
5. Join Netbird (optional, vault setup key).

System config application (`darwin-rebuild switch`) is a separate idempotent
"configure" phase invoked after bootstrap.

### Sudo-requiring non-defaults move to Ansible

Settings that need root but aren't `defaults write` (`pmset` power management,
`chflags /Volumes`, windowserver HiDPI) move from the dotfiles
`osx-settings.py` script to Ansible tasks sharing one `become` session. This
eliminates the 11 sudo prompts from the dotfiles script.

### home-manager is rejected

home-manager is not used anywhere in infrahub's darwin flake (NFR-5). The
daily user's home directory is owned by `levonk/dotfiles` (chezmoi), not
nix-darwin. Two reasons:

1. **Overlap:** chezmoi already owns `~/` — zsh, vim, ssh config, gpg-agent,
   dev tool dotfiles. Adding home-manager would create two competing owners of
   the same directory tree.
2. **Read-only breakage (decisive):** home-manager deploys files with strict
   read-only permissions (Nix store immutability + symlinks into `~/`). Tools
   that update their own configuration files — most GUI macOS apps, many CLI
   tools with `init`/`config` commands, and `defaults write` itself — break
   when the target is read-only or a symlink into the store. The failure is
   silent or confusing: writes hit a temp file, the rename across the symlink
   boundary fails, and the user's change is lost.

   chezmoi has the opposite default: deployed files are plain writable copies.
   When a tool modifies its own config, the change lands in the live file and
   the user can **absorb** it (`chezmoi re-add`/`chezmoi edit`), **reject** it
   (`chezmoi apply` overwrites with source), or **restore** it (`chezmoi diff`
   + git history). This absorb/reject/restore loop is the daily workflow for a
   dotfiles repo that coexists with self-modifying tools. home-manager's
   read-only model makes that loop impossible.

**Scope of rejection:** home-manager is rejected for the macOS user layer
*only*. `levonk-nix-config`'s Linux home-manager configs (wsl-dev,
debian-remote, debian-gui, qubes-dev, nixos) remain untouched.

## Cross-References

- **User layer (per-user macOS preferences):** dotfiles ADR-202607071200 —
  `internal-docs/adr/2026/07/adr-202607071200-macos-prefs-three-layer-architecture.md`
  in the [levonk/dotfiles](https://github.com/levonk/dotfiles) repo. Documents
  `executable_osx-settings.py` (163 user-level settings, idempotent, zero
  sudo) and the home-manager rejection rationale in detail.
- **Migration PRD (full requirements, NFR-5):**
  `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`
  (this repo).
- **Bridge script (user-facing entry point for system-layer changes):**
  `home/current/dot_local/bin/executable_osx-rebuild.sh` in the
  levonk/dotfiles repo — wraps `darwin-rebuild switch` with `FLAKE_DIR` /
  `HOSTNAME_SHORT` env vars and bootstrap-vs-post-install lookup.
- **Flake source:** `shared/active/02-config/nix/darwin/` (this repo).

## Consequences

### Positive
- Single declarative source of truth for macOS system config.
- Bootstrap is fast and minimal; system config is a separate idempotent phase.
- Fleet apps come from nixpkgs (declarative, reproducible) instead of Homebrew
  casks (imperative, auto-updating).
- No home-manager — no read-only breakage, no competing owner of `~/`.
- Per-host `infra.fleet.containerRuntime` selects OrbStack vs Apple Container
  without per-host imperative commands.

### Negative
- Two repos must be applied to converge a Mac: `osx-rebuild.sh` (system) +
  `chezmoi apply` (user). A single `just` target in dotfiles could chain them,
  but is not yet implemented.
- nix-installed macOS GUI apps update via `darwin-rebuild switch` with an
  updated flake lock, not via `brew upgrade` auto-update. This is a feature
  for fleet management (no surprise updates) but differs from cask behavior.
- System-level `defaults` can override user-level `defaults` set by
  `osx-settings.py` (system wins on conflict). The split is intentional: if a
  setting must be fleet-mandated, it belongs here, not in dotfiles.
