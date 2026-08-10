# Manual Linux Host — Initial Install

> **Purpose**: Minimal manual steps to bootstrap a fresh Linux machine so
> Ansible can take over and do the rest (install packages, configure services,
> deploy containers, join Tailscale/Netbird).
>
> **Target machines**: Linux servers/desktops managed by infrahub.
>   Supports Debian/Ubuntu and RHEL/Rocky/Alma/Fedora.
>   Example: `kckinai` (Ubuntu, GPU box), `oci-cloud-server` (Oracle Cloud Ubuntu).
>
> **Location**: `shared/active/08-docs/runbooks/` — generic instructions,
>   reusable across clients. Client-specific values (hostnames, Tailscale
>   names, SSH keys) are in the client inventory.

## Quick path — use the script

Run this **on the target Linux box** (must have sudo access):

```bash
# From the infrahub repo on the target machine:
shared/scripts/bootstrap-linux-manual.sh --ssh-key <your-ssh-key.pub>

# Or if the key is on the control Mac, copy it over first:
# (on control Mac) scp <your-ssh-key.pub> target-linux:/tmp/
# (on target)      shared/scripts/bootstrap-linux-manual.sh --ssh-key /tmp/<your-ssh-key.pub>

# Interactive mode (prompts for password, uses embedded default key):
shared/scripts/bootstrap-linux-manual.sh

# Custom admin username (defaults to 'auser'):
shared/scripts/bootstrap-linux-manual.sh --user lk --ssh-key ~/.ssh/foo.pub
```

The script does everything below automatically. Skip to
[What Ansible does next](#what-ansible-does-next) after running it.

## Manual steps (if you prefer to do it by hand)

The chicken-and-egg problem: Ansible needs SSH to a sudo user, but a fresh
Linux install may not have SSH running or the admin user created. This doc
gets the machine to the point where Ansible can SSH in and do everything else.

**Manual steps below**: ~6 commands, ~5 minutes.
**Then Ansible does**: package updates, Docker, Nix, Tailscale, Netbird,
container deployments, SSH hardening, monitoring.

---

## Step 1: Install and enable SSH server

Most server installs include SSH, but minimal/desktop installs may not.

```bash
# Debian/Ubuntu:
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh

# RHEL/Rocky/Alma/Fedora:
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
```

## Step 2: Create the admin user

The Ansible control machine connects as a dedicated admin user. This keeps
the daily-use account separate for safety.

```bash
# Create the user
sudo useradd -m -s /bin/bash auser

# Set a password (needed for sudo)
sudo passwd auser

# Add to the admin group
# Debian/Ubuntu:
sudo usermod -aG sudo auser
# RHEL/Rocky/Alma:
sudo usermod -aG wheel auser
```

## Step 3: Grant auser passwordless sudo (NOPASSWD)

Required for unattended Ansible runs. Without this, every `become: true` task
would need `--ask-become-pass`, breaking automated configure/deploy runs.

```bash
echo 'auser ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/auser
sudo chown root:root /etc/sudoers.d/auser
sudo chmod 0440 /etc/sudoers.d/auser
sudo visudo -cf /etc/sudoers.d/auser   # validate — must say "parsed OK"
```

## Step 4: Add your SSH public key

From your Ansible control machine, copy the public key (same key used for
other hosts):

```bash
# Create the .ssh directory
sudo mkdir -p /home/auser/.ssh
sudo chown auser:auser /home/auser/.ssh
sudo chmod 700 /home/auser/.ssh

# Add the public key
cat <your-ssh-key.pub> | sudo tee /home/auser/.ssh/authorized_keys
sudo chown auser:auser /home/auser/.ssh/authorized_keys
sudo chmod 600 /home/auser/.ssh/authorized_keys
```

## Step 5: Verify SSH access from your control Mac

```bash
# Should connect without a password prompt
ssh auser@<linux-ip>

# If using Tailscale (after the machine is on the Tailnet):
ssh auser@kckinai.tale-grouper.ts.net
```

If this works, you're done with manual setup. Ansible takes over from here.

---

## What Ansible does next

Run this from your control Mac in the infrahub repo:

```bash
# Cloud server (OCI) — full bootstrap (packages, Docker, Nix, VPN, services):
just ansible-deploy-bootstrap

# AI inference host (kckinai) — Tailscale + OpenLIT GPU collector:
just ansible-bootstrap-ai-inference

# Or run a specific playbook directly:
ansible-playbook \
  -i levonk/active/02-config/ansible/inventories/localnet.yml \
  shared/active/02-config/ansible/playbooks/bootstrap-ai-inference-host.yml \
  --vault-password-file ~/.ansible/vault_password \
  --limit kckinai
```

The bootstrap playbooks will:
- Update system packages
- Install Docker and required Python packages
- Install Nix (multi-user daemon, where applicable)
- Join Tailscale with the auth key from vault
- Configure SSH hardening
- Deploy container services
- Re-assert passwordless sudo for the admin user (idempotent — safe to re-run)

---

## Replacing the machine

When you replace a Linux box with a new one:
1. Run through Steps 1–5 above on the new machine
2. Update `ansible_host` in the relevant inventory file if the
   hostname/IP changed
3. Run the appropriate bootstrap playbook
4. Deploy any services

That's it — the new machine is back to the same state.

## Troubleshooting

### SSH connection refused
- Check SSH is running: `sudo systemctl status ssh` (or `sshd`)
- Check firewall: `sudo ufw status` (Debian) or `sudo firewall-cmd --list-all` (RHEL)
- Check the machine is reachable: `ping <hostname>`

### auser not found
- Create it manually: `sudo useradd -m -s /bin/bash auser && sudo passwd auser`
- Add to admin group: `sudo usermod -aG sudo auser` (or `wheel` on RHEL)
- Verify: `getent passwd auser`

### sudo: auser is not in the sudoers file
- Debian: `sudo usermod -aG sudo auser`
- RHEL: `sudo usermod -aG wheel auser`
- NOPASSWD is required for unattended Ansible (the host-os-bootstrap role
  sets it up automatically, but the manual script should do it first to
  avoid the chicken-and-egg of needing `--ask-become-pass` on the first run):
  `echo 'auser ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/auser && sudo chmod 0440 /etc/sudoers.d/auser`

### Python3 not found
- Ansible needs Python3 on the target. Most distros ship it, but minimal
  installs may not.
- Install: `sudo apt-get install -y python3` (Debian) or `sudo dnf install -y python3` (RHEL)
