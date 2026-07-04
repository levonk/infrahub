#Requires -Version 5.1
<#
.SYNOPSIS
    Performs the minimal manual steps needed before Ansible can take over
    a fresh Windows 10/11 machine.

.DESCRIPTION
    Run this ON the target Windows machine (not the control Mac).
    Must be run as Administrator.

    What it does:
      1. Enables OpenSSH Server
      2. Installs Python 3.12 via winget
      3. Installs docker Python package (needed by Ansible community.docker modules)
      4. Creates the ansible service account
      5. Adds the SSH public key for the ansible user
      6. Verifies SSH access is working

    After this, run from the control Mac:
      just ansible-bootstrap-windows-docker

.PARAMETER SshKey
    Path to the SSH public key file to install for the ansible user.
    If omitted, uses the embedded default key (lzkmbp2016-micro-oracle).

.PARAMETER SshKeyString
    The SSH public key string directly (useful for non-interactive runs).

.EXAMPLE
    .\bootstrap-windows-manual.ps1 -SshKey C:\Users\admin\.ssh\id_rsa.pub

.EXAMPLE
    .\bootstrap-windows-manual.ps1 -SshKeyString "ssh-rsa AAAA... user@host"

.EXAMPLE
    .\bootstrap-windows-manual.ps1
    # Prompts you to paste the public key
#>

param(
    [string]$SshKey,
    [string]$SshKeyString
)

$ErrorActionPreference = "Stop"
$AnsibleUser = "ansible"

# ponytail: PS 5.1 with $ErrorActionPreference=Stop surfaces native command stderr as
# a terminating NativeCommandError even with 2>$null. This wrapper suppresses it —
# icacls/takeown calls are best-effort (icacls /C continues on error); specific
# failures on authorized_keys are handled by the dedicated repair blocks in step 5.
function Invoke-Suppressed {
    param([Parameter(Mandatory)][scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Command 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
}

# --- Check admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click Start -> 'Windows PowerShell (Admin)' or 'Terminal (Admin)' and re-run."
    exit 1
}

Write-Host "=== Windows Manual Bootstrap ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME"
Write-Host "OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Host "Ansible user: $AnsibleUser"
Write-Host ""

# --- Step 1: Enable OpenSSH Server ---
Write-Host "[1/6] Enabling OpenSSH Server..." -ForegroundColor Yellow

$sshCap = Get-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" -ErrorAction SilentlyContinue
if ($sshCap -and $sshCap.State -eq "Installed") {
    Write-Host "  OpenSSH Server already installed" -ForegroundColor Green
} else {
    Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" | Out-Null
    Write-Host "  OpenSSH Server installed" -ForegroundColor Green
}

# Start and auto-start the service
$sshService = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshService.Status -ne "Running") {
    Start-Service sshd
    Write-Host "  sshd service started" -ForegroundColor Green
} else {
    Write-Host "  sshd service already running" -ForegroundColor Green
}
Set-Service -Name sshd -StartupType Automatic

# Firewall rule (idempotent)
$fwRule = Get-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
if (-not $fwRule) {
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
        -LocalPort 22 -Profile Any | Out-Null
    Write-Host "  Firewall rule created" -ForegroundColor Green
} else {
    Write-Host "  Firewall rule already exists" -ForegroundColor Green
}
Write-Host ""

# --- Step 2: Install Python 3.12 ---
Write-Host "[2/6] Installing Python 3.12..." -ForegroundColor Yellow

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $pyVer = & python --version 2>&1
    Write-Host "  Python already installed: $pyVer" -ForegroundColor Green
} else {
    # Check if winget is available
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        Write-Host "  winget not found. Install 'App Installer' from Microsoft Store." -ForegroundColor Red
        Write-Host "  Or download Python from https://www.python.org/downloads/" -ForegroundColor Red
        exit 1
    }
    winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements | Out-Null

    # Refresh PATH for current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Python 3.12 installed" -ForegroundColor Green
}
Write-Host ""

# --- Step 3: Install docker Python package ---
Write-Host "[3/6] Installing docker Python package..." -ForegroundColor Yellow

$dockerPip = & python -m pip show docker 2>$null
if ($dockerPip) {
    Write-Host "  docker Python package already installed" -ForegroundColor Green
} else {
    & python -m pip install docker
    Write-Host "  docker Python package installed" -ForegroundColor Green
}
Write-Host ""

# --- Step 4: Create ansible service account ---
Write-Host "[4/6] Creating $AnsibleUser service account..." -ForegroundColor Yellow

$existingUser = Get-LocalUser -Name $AnsibleUser -ErrorAction SilentlyContinue
if ($existingUser) {
    Write-Host "  $AnsibleUser already exists" -ForegroundColor Green
} else {
    New-LocalUser -Name $AnsibleUser -Description "Ansible deployment service account" -NoPassword | Out-Null
    Set-LocalUser -Name $AnsibleUser -PasswordNeverExpires $true
    Write-Host "  Created $AnsibleUser" -ForegroundColor Green
}

# Set a random password if the user has none. Windows' default LimitBlankPasswordUse
# policy (HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LimitBlankPasswordUse=1) blocks ALL
# network logons -- including SSH -- for accounts with empty passwords, even when pubkey
# auth succeeds. The password just needs to exist; Ansible still uses key auth exclusively.
# ponytail: idempotent -- only sets a password if PasswordLastSet is null (never set).
$userAccount = Get-LocalUser -Name $AnsibleUser
if (-not $userAccount.PasswordLastSet) {
    $rngBytes = New-Object byte[] 24
    ([System.Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($rngBytes)
    $randomPassword = [Convert]::ToBase64String($rngBytes)
    $securePassword = ConvertTo-SecureString $randomPassword -AsPlainText -Force
    Set-LocalUser -Name $AnsibleUser -Password $securePassword
    Write-Host "  Set random password (Windows blocks network logon for empty-password accounts)" -ForegroundColor Green
    Write-Host "  Password (save if you need interactive login; Ansible uses key auth):" -ForegroundColor Cyan
    Write-Host "    $randomPassword" -ForegroundColor White
} else {
    Write-Host "  Password already set" -ForegroundColor Green
}

# Create .ssh directory
$sshDir = "C:\Users\$AnsibleUser\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
# Set permissions -- ansible gets full control, Administrators get full control so the
# admin running this bootstrap can write authorized_keys in step 5. The authorized_keys
# file itself is locked down to ansible-only after the key is written.
# ponytail: unconditional (idempotent) so re-runs repair an ACL left broken by a prior run.
Invoke-Suppressed { icacls $sshDir /inheritance:r /grant:r "$AnsibleUser`:(OI)(CI)F" /grant:r "Administrators`:(OI)(CI)F" }
# Reassign ownership to the ansible user. Win32-OpenSSH StrictModes (default on)
# silently rejects authorized_keys whose owner is not the user or SYSTEM. Files
# created by the admin are owned by Administrators, so sshd refuses the key
# even when the ACL is correct. icacles can't change owner; takeown.exe + icacls /setowner.
# ponytail: idempotent -- runs every time, no-op if already correct.
Invoke-Suppressed { takeown /f $sshDir /r /d y }
Invoke-Suppressed { icacls $sshDir /setowner "$AnsibleUser" /T /C }
Write-Host "  .ssh directory ready" -ForegroundColor Green
Write-Host ""

# --- Step 5: Add SSH public key ---
Write-Host "[5/6] Adding SSH public key for $AnsibleUser..." -ForegroundColor Yellow

# Get the public key
# Embedded default -- the control Mac's lzkmbp2016-micro-oracle key (also in client inventory).
# Override with -SshKey <path> or -SshKeyString "<key>" for a different key.
$defaultPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEWRbHy2sWZLKET/74zvt0rZa4ET2zjes/SB+Y/3BmKp lzkmbp2016-micro-oracle"
$pubKey = $null
if ($SshKeyString) {
    $pubKey = $SshKeyString
} elseif ($SshKey) {
    if (-not (Test-Path $SshKey)) {
        Write-Host "ERROR: SSH key file not found: $SshKey" -ForegroundColor Red
        exit 1
    }
    $pubKey = Get-Content $SshKey -Raw
} else {
    $pubKey = $defaultPubKey
    Write-Host "  Using embedded default key (lzkmbp2016-micro-oracle)" -ForegroundColor Green
}

if (-not $pubKey -or $pubKey.Trim() -eq "") {
    Write-Host "ERROR: No SSH public key provided" -ForegroundColor Red
    exit 1
}
$pubKey = $pubKey.Trim()

# Write to authorized_keys (idempotent -- append if key missing, skip if already present)
$authKeysPath = "$sshDir\authorized_keys"

# Repair the file ACL and ownership BEFORE reading/writing -- a prior run may have
# left it locked to ansible-only, blocking the running admin from reading or appending.
# The .ssh directory ACL (Administrators:(OI)(CI)F) lets us create the file if missing,
# but an existing file with /inheritance:r doesn't inherit that grant. Running icacls
# here ensures the admin can access the file regardless of its prior state.
# Ownership is also repaired: files created by the admin are owned by Administrators,
# which sshd's StrictModes silently rejects (owner must be the user or SYSTEM).
# ponytail: takeown must run BEFORE icacls /grant. An elevated admin can always
# take ownership (SeTakeOwnershipPrivilege) but can only modify a DACL if it's
# the owner or has WRITE_DAC. A prior run leaves the file owned by $AnsibleUser
# with no Administrators ACE, so icacls /grant would silently fail without the
# takeown first.
if (Test-Path $authKeysPath) {
    Invoke-Suppressed { takeown /f $authKeysPath }
    Invoke-Suppressed { icacls $authKeysPath /inheritance:r /grant:r "$AnsibleUser`:(R)" /grant:r "NT SERVICE\sshd`:(R)" /grant:r "Administrators`:(F)" }
    Invoke-Suppressed { icacls $authKeysPath /setowner "$AnsibleUser" /C }
}

$existingKeys = $null
if (Test-Path $authKeysPath) {
    $existingKeys = Get-Content $authKeysPath -Raw -ErrorAction SilentlyContinue
}
if ($existingKeys -and $existingKeys.Contains($pubKey)) {
    Write-Host "  SSH public key already in $authKeysPath" -ForegroundColor Green
} else {
    Add-Content -Path $authKeysPath -Value $pubKey -Encoding ASCII
    # ACL matches Microsoft's documented baseline for %UserProfile%\.ssh\authorized_keys
    # (PowerShell/Win32-OpenSSH #870): user gets read, sshd service account gets read.
    # SYSTEM bypasses the DACL so it isn't listed explicitly; Administrators is intentionally
    # absent so a compromised admin context can't tamper with the key material.
    Invoke-Suppressed { icacls $authKeysPath /inheritance:r /grant:r "$AnsibleUser`:(R)" /grant:r "NT SERVICE\sshd`:(R)" }
    # Reassign ownership to ansible -- see StrictModes note above. Files created by the
    # admin are owned by Administrators; sshd rejects keys not owned by user or SYSTEM.
    Invoke-Suppressed { takeown /f $authKeysPath }
    Invoke-Suppressed { icacls $authKeysPath /setowner "$AnsibleUser" /C }
    Write-Host "  SSH public key added to $authKeysPath" -ForegroundColor Green
}
Write-Host ""

# --- Step 6: Verify ---
Write-Host "[6/6] Verification..." -ForegroundColor Yellow

$sshServiceCheck = Get-Service sshd
Write-Host "  sshd: $($sshServiceCheck.Status) (Startup: $($sshServiceCheck.StartType))"

$pyVer = & python --version 2>&1
Write-Host "  Python: $pyVer"

$dockerPipCheck = & python -m pip show docker 2>$null
if ($dockerPipCheck) {
    Write-Host "  docker pip: installed"
} else {
    Write-Host "  docker pip: NOT installed" -ForegroundColor Red
}

$userCheck = Get-LocalUser -Name $AnsibleUser -ErrorAction SilentlyContinue
if ($userCheck) {
    Write-Host "  $AnsibleUser user: exists (enabled: $($userCheck.Enabled))" -NoNewline
    if ($userCheck.PasswordLastSet) {
        Write-Host " (password set: $($userCheck.PasswordLastSet))" -ForegroundColor Green
    } else {
        Write-Host " (NO PASSWORD -- SSH will be blocked by LimitBlankPasswordUse)" -ForegroundColor Red
        Write-Host "ERROR: $AnsibleUser has no password. Re-run step 4 or set one manually:" -ForegroundColor Red
        Write-Host "  \$pw = Read-Host -AsSecureString; Set-LocalUser -Name $AnsibleUser -Password \$pw" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  $AnsibleUser user: NOT found" -ForegroundColor Red
    exit 1
}

$keyCheck = Get-Content $authKeysPath -ErrorAction SilentlyContinue
if ($keyCheck) {
    Write-Host "  authorized_keys: $($keyCheck.Substring(0, [Math]::Min(40, $keyCheck.Length)))..." -ForegroundColor Green
} else {
    Write-Host "  authorized_keys: NOT found" -ForegroundColor Red
    Write-Host "ERROR: authorized_keys is missing or empty at $authKeysPath" -ForegroundColor Red
    Write-Host "  Re-run step 5 or add the key manually:" -ForegroundColor Red
    Write-Host "  Add-Content -Path '$authKeysPath' -Value '<your-ssh-public-key>'" -ForegroundColor Red
    exit 1
}

# Get this machine's IP for the hint
$lanIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Wi*,Ethernet* -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
if (-not $lanIp) { $lanIp = "<windows-ip>" }

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Cyan
Write-Host "From the control Mac, verify SSH access:"
Write-Host "  ssh $AnsibleUser@$lanIp"
Write-Host ""
Write-Host "Then run the Ansible bootstrap:"
Write-Host "  just ansible-bootstrap-windows-docker"
