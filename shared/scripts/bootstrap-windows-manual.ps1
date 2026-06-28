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
    If omitted, you'll be prompted to paste a key.

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
    Write-Host "  Created $AnsibleUser (no password, SSH key auth only)" -ForegroundColor Green
}

# Create .ssh directory
$sshDir = "C:\Users\$AnsibleUser\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
# Set permissions — only ansible user should have access
icacls $sshDir /inheritance:r /grant:r "$AnsibleUser`:(OI)(CI)F" 2>$null | Out-Null
Write-Host "  .ssh directory ready" -ForegroundColor Green
Write-Host ""

# --- Step 5: Add SSH public key ---
Write-Host "[5/6] Adding SSH public key for $AnsibleUser..." -ForegroundColor Yellow

# Get the public key
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
    # Interactive — prompt for key
    Write-Host "  Paste the SSH public key (from the control Mac's ~/.ssh/lzkmbp2016-micro-oracle.pub):" -ForegroundColor White
    Write-Host "  (paste the entire line starting with ssh-rsa or ssh-ed25519, then press Enter)" -ForegroundColor White
    $pubKey = Read-Host "  Key"
}

if (-not $pubKey -or $pubKey.Trim() -eq "") {
    Write-Host "ERROR: No SSH public key provided" -ForegroundColor Red
    exit 1
}
$pubKey = $pubKey.Trim()

# Write to authorized_keys (overwrite to avoid duplicates on re-run)
$authKeysPath = "$sshDir\authorized_keys"
Set-Content -Path $authKeysPath -Value $pubKey -Encoding ASCII
icacls $authKeysPath /inheritance:r /grant:r "$AnsibleUser`:(R)" 2>$null | Out-Null
Write-Host "  SSH public key added to $authKeysPath" -ForegroundColor Green
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
    Write-Host "  $AnsibleUser user: exists (enabled: $($userCheck.Enabled))"
} else {
    Write-Host "  $AnsibleUser user: NOT found" -ForegroundColor Red
}

$keyCheck = Get-Content $authKeysPath -ErrorAction SilentlyContinue
if ($keyCheck) {
    Write-Host "  authorized_keys: $($keyCheck.Substring(0, [Math]::Min(40, $keyCheck.Length)))..."
} else {
    Write-Host "  authorized_keys: NOT found" -ForegroundColor Red
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
