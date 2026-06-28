# Manual Windows Docker Host — Initial Install

> **Purpose**: Minimal manual steps to bootstrap a fresh Windows 10/11 machine
> so Ansible can take over and do the rest (install Docker Desktop, Git,
> Tailscale, configure the host, deploy containers).
>
> **Target machine**: `dtop202311` (Windows desktop running Docker Desktop)
> **Tailscale name**: `dtop202311.tale-grouper.ts.net`
> **Ansible user**: `ansible` (dedicated service account)
>
> **Location**: `shared/active/08-docs/runbooks/` — generic instructions,
>   reusable across clients. Client-specific values (hostnames, Tailscale
>   names, SSH keys) are in the levonk client inventory.

## Quick path — use the script

Run this **on the target Windows machine** in an admin PowerShell:

```powershell
# If the key file is on the Windows machine:
.\shared\scripts\bootstrap-windows-manual.ps1 -SshKey C:\Users\admin\.ssh\lzkmbp2016-micro-oracle.pub

# Or pass the key string directly:
.\shared\scripts\bootstrap-windows-manual.ps1 -SshKeyString "ssh-rsa AAAA... user@host"

# Interactive mode (prompts for key paste):
.\shared\scripts\bootstrap-windows-manual.ps1
```

The script does everything below automatically. Skip to
[What Ansible does next](#what-ansible-does-next) after running it.

## Manual steps (if you prefer to do it by hand)

## What this covers

The chicken-and-egg problem: Ansible needs SSH + Python to connect, but
those aren't on a fresh Windows install. This doc gets the machine to the
point where Ansible can SSH in and do everything else.

**Manual steps below**: ~10 commands, ~10 minutes.
**Then Ansible does**: WSL2, Docker Desktop, Git, Tailscale, docker-users
group, service directories, container deployments.

---

## Step 1: Open PowerShell as Administrator

Right-click Start → "Windows PowerShell (Admin)" or "Terminal (Admin)".

All commands below run in that admin PowerShell window.

## Step 2: Enable OpenSSH Server

```powershell
# Install the OpenSSH Server feature
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the service and set it to auto-start
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Allow SSH through the firewall (port 22)
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
  -LocalPort 22 -Profile Any
```

## Step 3: Install Python 3

```powershell
# Install Python 3.12 via winget (pre-installed on Windows 11 21H2+)
winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements

# Refresh PATH for the current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify
python --version
```

If `winget` is not available (older Windows 10), install it from the
Microsoft Store (search "App Installer") or download Python from
https://www.python.org/downloads/ and run the installer with
"Add Python to PATH" checked.

## Step 4: Install docker Python package

The `community.docker` Ansible modules need the `docker` Python library
on the target machine.

```powershell
# Install the docker Python library (needed by Ansible community.docker modules)
pip install docker
```

## Step 5: Create the ansible service account

```powershell
# Create a dedicated deployment user (no password — SSH key auth only)
New-LocalUser -Name ansible -Description "Ansible deployment service account" -NoPassword

# Prevent password expiry
Set-LocalUser -Name ansible -PasswordNeverExpires $true

# Create the .ssh directory for the ansible user
$sshDir = "C:\Users\ansible\.ssh"
New-Item -ItemType Directory -Path $sshDir -Force

# Set permissions — only ansible user should have access
icacls $sshDir /inheritance:r /grant:r "ansible:(OI)(CI)F"
```

## Step 6: Add your SSH public key

From your Mac (the Ansible control machine), copy your public key to
the Windows machine's ansible user:

```bash
# From your Mac — replace <windows-ip> with the machine's current IP
# (use the Tailscale IP if already on the Tailnet, or the LAN IP)
ssh administrator@<windows-ip> "Add-Content -Path C:\Users\ansible\.ssh\authorized_keys -Value '$(cat ~/.ssh/id_rsa.pub)'"
```

Or if you can't SSH yet (no admin SSH key set up), copy the key manually:
1. On your Mac: `cat ~/.ssh/id_rsa.pub`
2. On the Windows machine, in the admin PowerShell:
   ```powershell
   # Paste your public key here (the entire line starting with ssh-rsa or ssh-ed25519)
   $pubKey = "ssh-rsa AAAA... your@email"
   Add-Content -Path "C:\Users\ansible\.ssh\authorized_keys" -Value $pubKey

   # Set correct permissions on authorized_keys
   icacls "C:\Users\ansible\.ssh\authorized_keys" /inheritance:r /grant:r "ansible:(R)"
   ```

## Step 7: Verify SSH access from your Mac

```bash
# From your Mac — should get a PowerShell prompt without password prompt
ssh ansible@<windows-ip>

# If using Tailscale (after the machine is on the Tailnet):
ssh ansible@dtop202311.tale-grouper.ts.net
```

If this works, you're done with manual setup. Ansible takes over from here.

---

## What Ansible does next

Run these from your Mac (the Ansible control machine) in the infrahub repo:

```bash
# 1. Bootstrap the Windows host (installs WSL2, Docker Desktop, Git, Tailscale,
#    adds ansible to docker-users, creates service directories)
just ansible-bootstrap-windows-docker

# 2. Deploy WorldMonitor self-hosted stack
just ansible-deploy-worldmonitor
```

The bootstrap playbook (`bootstrap-windows-docker-host.yml`) will:
- Enable WSL2 (`wsl --install --no-distribution`)
- Install Docker Desktop via winget
- Install Git via winget
- Install Tailscale via winget
- Join Tailscale with the auth key from vault (hostname: dtop202311)
- Add the `ansible` user to the `docker-users` group
- Create `C:\localnet\services\` directory structure
- Reboot if WSL2 was just enabled (Ansible reconnects automatically)

---

## If the machine is already on Tailscale

If the Windows machine is already on your Tailnet (e.g., you installed
Tailscale manually during initial Windows setup), you can skip the
Tailscale install in the bootstrap playbook. The playbook detects
existing Tailscale and only installs if missing.

## Replacing the machine

When you replace this Windows machine with a new one:
1. Run through Steps 1–7 above on the new machine
2. Update `ansible_host` in `inventories/windows-docker.yml` if the
   Tailscale name changed
3. Run `just ansible-bootstrap-windows-docker`
4. Run `just ansible-deploy-worldmonitor`

That's it — the new machine is back to the same state.

## Troubleshooting

### SSH connection refused
- Check `Get-Service sshd` shows Running status
- Check firewall: `Get-NetFirewallRule -Name sshd | Select Enabled`
- Check the machine is reachable: `ping dtop202311.tale-grouper.ts.net`

### Python not found by Ansible
- Check the path in `ansible_python_interpreter` matches the installed version
- Run `dir "C:\Program Files\Python3*"` to find the exact path
- Update the inventory if the version differs (e.g., Python311 vs Python312)

### docker pip package missing
- Run as the ansible user: `pip install docker`
- Or as admin: `& "C:\Program Files\Python312\python.exe" -m pip install docker`

### winget not found
- Install "App Installer" from the Microsoft Store
- Or update Windows: Settings → Windows Update
