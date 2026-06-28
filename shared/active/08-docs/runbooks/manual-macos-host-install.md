# Manual macOS Host — Initial Install

> **Purpose**: Minimal manual steps to bootstrap a fresh Mac so Ansible can
> take over and do the rest (create auser admin user, install Nix, Homebrew,
> container runtime, apps, Tailscale, Netbird).
>
> **Target machines**: Mac laptops/desktops managed by infrahub.
>   Example: `lzkmbp2016`, `lzkmbp2018` (levonk client).
>
> **Location**: `shared/active/08-docs/runbooks/` — generic instructions,
>   reusable across clients. Client-specific values (hostnames, Tailscale
>   names, SSH keys) are in the client inventory.

## Quick path — use the script

Run this **on the target Mac** (must have sudo access):

```bash
# From the infrahub repo on the target Mac:
shared/scripts/bootstrap-macos-manual.sh --ssh-key ~/.ssh/lzkmbp2016-micro-oracle.pub

# Or if the key is on the control Mac, copy it over first:
# (on control Mac) scp ~/.ssh/lzkmbp2016-micro-oracle.pub target-mac:/tmp/
# (on target Mac)  shared/scripts/bootstrap-macos-manual.sh --ssh-key /tmp/lzkmbp2016-micro-oracle.pub

# Interactive mode (prompts for key paste):
shared/scripts/bootstrap-macos-manual.sh
```

The script does everything below automatically. Skip to
[What Ansible does next](#what-ansible-does-next) after running it.

## Manual steps (if you prefer to do it by hand)

## What this covers

The chicken-and-egg problem: Ansible needs SSH to an admin user, but a fresh
Mac may not have Remote Login enabled or the admin user created. This doc
gets the machine to the point where Ansible can SSH in and do everything else.

**Manual steps below**: ~8 commands, ~10 minutes.
**Then Ansible does**: Nix (multi-user daemon), Homebrew, OrbStack, GUI/CLI
apps (git, zsh, cmux, tailscale, netbird, raycast, firefox developer edition,
rustdesk), Tailscale join, Netbird join, SSH server enable.

---

## Step 1: Enable Remote Login (SSH server)

**System Settings** → **General** → **Sharing** → enable **Remote Login**.

Or from Terminal:
```bash
sudo systemsetup -setremotelogin on
```

## Step 2: Create the auser admin user

The Ansible control machine connects as a dedicated `auser` admin user.
This mirrors the `cuser` pattern used on Linux hosts, and keeps the
daily-use account (e.g. `micro`) separate and non-admin for safety.

```bash
# Create the auser user with admin rights (password will be set from vault)
sudo sysadminctl -addUser auser -password - -admin -home /Users/auser

# Verify the user was created and is in the admin group
dscl . -read /Users/auser UniqueID
dseditgroup -o checkmember -m auser admin
```

## Step 3: Add your SSH public key to the auser user

From your Ansible control machine, copy the public key (same key used for OCI):

```bash
# Create the .ssh directory for the auser user
sudo mkdir -p /Users/auser/.ssh
sudo chown auser:staff /Users/auser/.ssh
sudo chmod 700 /Users/auser/.ssh

# Add the public key (from the control Mac)
cat ~/.ssh/lzkmbp2016-micro-oracle.pub | sudo tee /Users/auser/.ssh/authorized_keys
sudo chown auser:staff /Users/auser/.ssh/authorized_keys
sudo chmod 600 /Users/auser/.ssh/authorized_keys
```

## Step 4: Verify SSH access from your control Mac

```bash
# Should connect without a password prompt
ssh auser@<mac-ip>

# If using Tailscale (after the machine is on the Tailnet):
ssh auser@lzkmbp2016.tale-grouper.ts.net
```

If this works, you're done with manual setup. Ansible takes over from here.

---

## What Ansible does next

Run this from your control Mac in the infrahub repo:

```bash
# Bootstrap the macOS host (creates/verifies auser admin user, installs Nix,
# Homebrew, OrbStack, apps, Tailscale, Netbird, enables SSH)
just ansible-bootstrap-macos
```

The bootstrap playbook (`bootstrap-macos-host.yml`) will:
- Ensure the `auser` admin user exists (creates if missing)
- Add the SSH public key to the auser user
- Ensure the auser user is in the admin group
- Enable Remote Login (SSH server) if not already on
- Install Nix in multi-user daemon mode with flakes enabled
- Install Homebrew
- Install CLI tools via Nix flake: git, zsh, tailscale, netbird
- Install GUI apps via Nix flake: cmux, Firefox Developer Edition, Raycast
- Symlink GUI .app bundles to /Applications (so they appear in Spotlight/Launchpad)
- Install Homebrew casks: OrbStack (container runtime), RustDesk
- Join Tailscale with the auth key from vault
- Join Netbird with the setup key from vault (if configured)

---

## If the machine is already on Tailscale

If the Mac is already on your Tailnet (e.g., you installed Tailscale
manually during initial setup), the bootstrap playbook detects existing
Tailscale and only joins if not already connected.

## Replacing the machine

When you replace this Mac with a new one:
1. Run through Steps 1–4 above on the new machine
2. Update `ansible_host` in `inventories/macos-hosts.yml` if the
   Tailscale name changed
3. Run `just ansible-bootstrap-macos`
4. Deploy any services (e.g., `just ansible-deploy-worldmonitor`)

That's it — the new machine is back to the same state.

## Troubleshooting

### SSH connection refused
- Check **System Settings** → **General** → **Sharing** → **Remote Login** is ON
- Check the machine is reachable: `ping lzkmbp2016.tale-grouper.ts.net`
- Check firewall: **System Settings** → **Network** → **Firewall**

### auser not found
- Create it manually: `sudo sysadminctl -addUser auser -password - -admin`
- Verify: `dscl . -read /Users/auser UniqueID`

### Nix installation fails
- Check you have admin/sudo access
- Check macOS version: Nix requires macOS 12+
- Check for existing Nix: `ls /nix` — if present but broken, uninstall first:
  `sudo rm -rf /nix` (careful — this removes all Nix packages)

### OrbStack won't start
- OrbStack requires macOS 13+ (Ventura)
- On macOS 26+ ARM Macs, the playbook auto-selects Apple Container instead

### GUI apps not appearing in /Applications
- The playbook symlinks .app bundles from the Nix profile to /Applications
- If they don't appear, run manually:
  ```bash
  sudo -u auser nix run /Users/auser/.local/share/infrahub-nix#symlink-apps
  ```
- Check the Nix profile has the apps:
  ```bash
  ls /Users/auser/.local/state/nix/profiles/profile/Applications/
  ```

### Homebrew cask install fails
- Check Homebrew is installed: `brew --version`
- Check /Applications is writable: `ls -la /Applications`
- Try installing manually: `brew install --cask orbstack`
