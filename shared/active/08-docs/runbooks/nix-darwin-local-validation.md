# Runbook: nix-darwin Local Validation

> **PRD**: `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`
> **ADR**: `shared/active/08-docs/adr/adr-202607070001-macos-system-config-nix-darwin.md`

This runbook describes how to locally apply and validate a nix-darwin
configuration on a macOS fleet host. It is the companion to the
`configure-macos-host.yml` Ansible playbook, which automates the same
steps remotely. Use this runbook when you are physically on the Mac you
want to configure (or SSH'd into it) and want to iterate on the flake
without a full Ansible run.

## Prerequisites

1. **Nix installed (multi-user daemon)** — the Nix daemon must be running
   (`launchctl print system/org.nixos.nix-daemon` should succeed). If not,
   run the bootstrap playbook first:
   `just ansible-bootstrap-macos`.
2. **Flakes + nix-command enabled** — `/etc/nix/nix.conf` must contain
   `experimental-features = nix-command flakes`. The configure playbook
   writes this; for a manual check:
   ```bash
   grep experimental-features /etc/nix/nix.conf
   ```
3. **The darwin flake checked out locally** — the infrahub repo (with the
   `levonk/` submodule initialised) must be present on the Mac:
   - Shared module library: `shared/active/02-config/nix/darwin/`
     (exports `modules.*`, no `darwinConfigurations`).
   - Client-specific host configs: `levonk/active/02-config/nix/darwin/`
     (defines `darwinConfigurations.lzkmbp2016`, `lzkmbp2018`).
   - Verify the submodule is initialised:
     ```bash
     git submodule status levonk
     ```
4. **auser admin account exists** — created by the bootstrap playbook.
   nix-darwin manages it declaratively after bootstrap.

## Local Apply

Run from the infrahub repo root on the target Mac. Replace `<hostname>`
with the nix-darwin configuration name (e.g. `lzkmbp2016`, `lzkmbp2018`):

```bash
cd ~/p/gh/levonk/infrahub

sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin \
  -- switch --flake ./levonk/active/02-config/nix/darwin#<hostname>
```

> The shared flake at `shared/active/02-config/nix/darwin/flake.nix`
> exports a module library only — it has no `darwinConfigurations`. You
> must point `--flake` at the **client** flake
> (`levonk/active/02-config/nix/darwin`) which imports the shared modules
> and defines per-host configurations.

### Expected Output

A successful apply prints lines similar to:

```
building the system configuration...
activating the configuration...
reloading service org.nixos.nix-daemon...
reloading service homebrew...
useradd: warning: ...
```

The final line is typically silent (exit 0) with no error. If you see
`error: unsupported Nix option` or `error: attribute 'x' missing`, see
Troubleshooting below.

## Verification

After a successful apply, run these spot-checks on the target Mac:

### OS auto-updates OFF (OpenCore requirement)

```bash
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates
# Expected: 0
```

### Diagnostics auto-submit OFF

```bash
defaults read com.apple.SubmitDiagInfo AutoSubmit
# Expected: 0
```

### Fleet apps in system packages, not casks

Fleet apps (Discord, Bitwarden, OrbStack, etc.) are declared in
`environment.systemPackages` (nixpkgs), **not** as Homebrew casks. Verify:

```bash
# Nix-managed GUI apps should appear in the system profile:
ls /run/current-system/sw/Applications/ | grep -i discord

# And NOT in Homebrew casks (should be empty or only non-fleet apps):
brew list --cask | grep -i discord
# Expected: no output
```

### Homebrew cask list is minimal

```bash
brew list --cask
# Expected: only apps not available in nixpkgs (e.g. firefox, visual-studio-code)
```

## Idempotency

Re-running the apply command should produce no diff or report the
configuration as already active:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin \
  -- switch --flake ./levonk/active/02-config/nix/darwin#<hostname>
```

On a second run with no flake changes, the output is typically:

```
building the system configuration...
activating the configuration...
```

No services are reloaded (nix-darwin detects no diff). If a service
reloads unexpectedly, the flake input may have changed (run `nix flake
update` to inspect).

## Rollback

nix-darwin maintains a generation history. To revert to the previous
configuration:

```bash
sudo darwin-rebuild rollback
```

This activates the previous generation and reloads services. To list all
available generations:

```bash
darwin-rebuild generations
```

Output looks like:

```
1   2026-07-07 14:32:11   initial
2   2026-07-08 09:15:02   nix-darwin base
3   2026-07-08 10:44:30   fleet apps added
```

To switch to a specific generation (not just the previous one):

```bash
sudo darwin-rebuild switch --generation <N>
```

## Troubleshooting

### `error: unsupported system.defaults key`

You used a `system.defaults.*` option that does not exist in this version
of nix-darwin. Check the option against the
[nix-darwin options search](https://daiderd.com/nix-darwin/manual/).
Common gotchas:

- `system.defaults.SoftwareUpdate.ConfigDataInstall` — use
  `system.defaults.SoftwareUpdate.ConfigDataInstall` (boolean) not a string.
- `system.defaults.dock` keys are flat (`autohide`, `orientation`) not
  nested under sub-attrsets.

Fix: correct the key in `modules/system/defaults.nix` and re-apply.

### Homebrew cask removal after switching to nix

When a package moves from a Homebrew cask to `environment.systemPackages`,
`darwin-rebuild switch` installs the nix version but does **not**
uninstall the cask. You may end up with two copies (one in
`/Applications` from the cask, one symlinked from the nix profile).

Fix:
```bash
brew uninstall --cask <name>
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin \
  -- switch --flake ./levonk/active/02-config/nix/darwin#<hostname>
```

Set `homebrew.onActivation.cleanup = "uninstall"` (or `"zap"`) in
`modules/system/homebrew.nix` to make nix-darwin remove undeclared casks
automatically on the next switch. The current safe default is `"none"`.

### auser password clobbered by nix-darwin

If `users.users.auser` in the fleet module sets a `hashedPassword`, every
`darwin-rebuild switch` overwrites the password set during bootstrap or
changed by the user via `passwd`. Symptoms: the user cannot log in after
a switch, or the password reverts.

Fix: do **not** set `hashedPassword` in the flake. The auser password is
vault-owned and set once by the bootstrap playbook. The flake should
only manage the account's existence, UID, groups, and shell — not the
password. If a password must be rotated, do it via Ansible (vault) and
leave the flake's `users.users.auser` without a `hashedPassword` field.

### `error: flake 'path:...' does not provide attribute 'darwinConfigurations'`

You pointed `--flake` at the shared flake
(`shared/active/02-config/nix/darwin`) instead of the client flake
(`levonk/active/02-config/nix/darwin`). The shared flake exports
`modules.*` only. Re-run with the client flake path.

### `nix-darwin` not found / `nix run` fails

The `nix-darwin` input may not be in the flake lock. From the client
flake directory:

```bash
cd levonk/active/02-config/nix/darwin
nix flake lock --update-input nix-darwin
```

Then re-run the apply command from the repo root.

## See Also

- **ADR**: `shared/active/08-docs/adr/adr-202607070001-macos-system-config-nix-darwin.md`
- **Configure playbook**: `shared/active/02-config/ansible/playbooks/configure-macos-host.yml`
- **Bootstrap playbook**: `shared/active/02-config/ansible/playbooks/bootstrap-macos-host.yml`
- **PRD**: `internal-docs/feature/2026/07/nix-darwin-use/feat-202607060157-nix-darwin-migration.md`
- **Shared flake**: `shared/active/02-config/nix/darwin/flake.nix`
- **Client flake**: `levonk/active/02-config/nix/darwin/flake.nix`
