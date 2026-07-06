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
      4. Creates the service account (configadmin) with admin privileges
      5. Adds the SSH public key for the service user
      6. Verifies SSH access is working

    After this, run from the control Mac:
      just ansible-bootstrap-windows-docker

.PARAMETER SshKey
    Path to the SSH public key file to install for the service user.
    If omitted, uses the embedded default key (lzkmbp2016-micro-oracle).

.PARAMETER SshKeyString
    The SSH public key string directly (useful for non-interactive runs).

.PARAMETER ServiceUserName
    Name of the service account to create (default: configadmin).
    This account gets admin privileges for system configuration.

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
    [string]$SshKeyString,
    [string]$ServiceUserName = "configadmin"
)

$ErrorActionPreference = "Stop"

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
Write-Host "Service user: $ServiceUserName (admin)"
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

# Remove the default "Match Group administrators" block from sshd_config. Win32-OpenSSH
# ships with this block, which redirects admin users' keys to a shared
# C:\ProgramData\ssh\administrators_authorized_keys file. We want each user to have their
# own ~/.ssh/authorized_keys (per-user key management, better audit trail). The service
# account is an admin, so without removing this block sshd would ignore its personal key file.
# ponytail: idempotent -- runs every time, no-op if already removed.
$sshdConfig = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfig) {
    $cfgLines = Get-Content $sshdConfig
    $newCfgLines = @()
    $inMatchBlock = $false
    foreach ($line in $cfgLines) {
        if ($line -match '^\s*Match Group administrators') {
            $inMatchBlock = $true
            continue
        }
        if ($inMatchBlock) {
            if ($line -and $line -notmatch '^\s') {
                $inMatchBlock = $false
                $newCfgLines += $line
            } elseif ($line.Trim()) {
                continue
            }
        } else {
            $newCfgLines += $line
        }
    }
    if ($cfgLines.Count -ne $newCfgLines.Count) {
        [System.IO.File]::WriteAllLines($sshdConfig, $newCfgLines)
        Write-Host "  Removed Match Group administrators block (using per-user authorized_keys)" -ForegroundColor Green
    } else {
        Write-Host "  sshd_config already uses per-user authorized_keys" -ForegroundColor Green
    }
}

Write-Host ""

# --- Step 2: Install Python 3.12 ---
Write-Host "[2/6] Installing Python 3.12..." -ForegroundColor Yellow

# Check for REAL Python -- Get-Command python finds the Windows Store stub
# (C:\Users\*\AppData\Local\Microsoft\WindowsApps\python.exe, 0 bytes) which is NOT
# real Python, it's a redirect to the Microsoft Store. The stub makes --version
# fail silently or open the Store. We must check the actual file size or try running it.
$pythonExe = $null
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $stubCheck = & python --version 2>&1
    # The stub either returns nothing, opens the Store, or errors. Real Python returns "Python 3.x.y"
    if ($stubCheck -match '^Python 3\.\d+\.\d+') {
        $pythonExe = $pythonCmd.Source
        Write-Host "  Python already installed: $stubCheck at $pythonExe" -ForegroundColor Green
    } else {
        Write-Host "  Found Windows Store stub, not real Python -- installing..." -ForegroundColor Yellow
    }
}

if (-not $pythonExe) {
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

    # Verify the install actually worked -- find the real python.exe
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pythonExe -and (& python --version 2>&1) -match '^Python 3\.\d+\.\d+') {
        Write-Host "  Python 3.12 installed: $pythonExe" -ForegroundColor Green
    } else {
        # winget may have installed to a per-user path not yet on PATH
        $userPython = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe" -ErrorAction SilentlyContinue
        $machinePython = Get-ChildItem -Path "C:\Program Files\Python312\python.exe" -ErrorAction SilentlyContinue
        if ($userPython) {
            $pythonExe = $userPython.FullName
        } elseif ($machinePython) {
            $pythonExe = $machinePython.FullName
        }
        if ($pythonExe -and (Test-Path $pythonExe)) {
            $env:Path = "$(Split-Path $pythonExe);$env:Path"
            $pyVer = & $pythonExe --version 2>&1
            Write-Host "  Python 3.12 installed: $pyVer at $pythonExe" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Python install failed. Install manually from https://www.python.org/downloads/" -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host ""

# --- Step 3: Install docker Python package ---
Write-Host "[3/6] Installing docker Python package..." -ForegroundColor Yellow

# Use the verified python.exe, not whatever 'python' resolves to on PATH (could still be the stub)
# ponytail: pip show writes "Package(s) not found" to stderr, which PS 5.1 with
# $ErrorActionPreference=Stop turns into a terminating NativeCommandError (2>$null
# doesn't suppress it). Use Invoke-Suppressed to check, then install if missing.
$dockerPip = $null
Invoke-Suppressed { $dockerPip = & $pythonExe -m pip show docker 2>&1 }
if ($dockerPip -and ($dockerPip -join "`n").Contains('Name: docker')) {
    Write-Host "  docker Python package already installed" -ForegroundColor Green
} else {
    Invoke-Suppressed { & $pythonExe -m pip install docker 2>&1 | Out-Null }
    Write-Host "  docker Python package installed" -ForegroundColor Green
}
Write-Host ""

# --- Step 4: Create service account (admin) ---
Write-Host "[4/6] Creating $ServiceUserName service account..." -ForegroundColor Yellow

$existingUser = Get-LocalUser -Name $ServiceUserName -ErrorAction SilentlyContinue
if ($existingUser) {
    Write-Host "  $ServiceUserName already exists" -ForegroundColor Green
} else {
    New-LocalUser -Name $ServiceUserName -Description "Configuration management service account" -NoPassword | Out-Null
    Set-LocalUser -Name $ServiceUserName -PasswordNeverExpires $true
    Write-Host "  Created $ServiceUserName" -ForegroundColor Green
}

# Set a random password if the user has none. Windows' default LimitBlankPasswordUse
# policy (HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LimitBlankPasswordUse=1) blocks ALL
# network logons -- including SSH -- for accounts with empty passwords, even when pubkey
# auth succeeds. The password just needs to exist; Ansible still uses key auth exclusively.
# ponytail: idempotent -- only sets a password if PasswordLastSet is null (never set).
$userAccount = Get-LocalUser -Name $ServiceUserName
if (-not $userAccount.PasswordLastSet) {
    $rngBytes = New-Object byte[] 24
    ([System.Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($rngBytes)
    $randomPassword = [Convert]::ToBase64String($rngBytes)
    $securePassword = ConvertTo-SecureString $randomPassword -AsPlainText -Force
    Set-LocalUser -Name $ServiceUserName -Password $securePassword
    Write-Host "  Set random password (Windows blocks network logon for empty-password accounts)" -ForegroundColor Green
    Write-Host "  Password (save if you need interactive login; Ansible uses key auth):" -ForegroundColor Cyan
    Write-Host "    $randomPassword" -ForegroundColor White
} else {
    Write-Host "  Password already set" -ForegroundColor Green
}

# Add to Administrators group -- the service account needs admin to install software,
# configure the system, and apply hardening playbooks.
# ponytail: idempotent -- Add-LocalGroupMember errors on duplicate, so check first.
$adminGroup = Get-LocalGroup -Name Administrators
$isAdmin = $adminGroup.Members | Where-Object { $_.Name -eq $ServiceUserName }
if ($isAdmin) {
    Write-Host "  $ServiceUserName already in Administrators group" -ForegroundColor Green
} else {
    Add-LocalGroupMember -Group Administrators -Member $ServiceUserName
    Write-Host "  Added $ServiceUserName to Administrators group" -ForegroundColor Green
}

# Trigger profile creation by running a process as the service user. The profile
# directory is NOT created until first logon. Windows may append the machine name
# (e.g. C:\Users\configadmin.DTOP202311) if C:\Users\<name> already exists from a
# prior run or manual creation. We must use the REAL profile path from the registry,
# not assume C:\Users\<name>.
$profilePath = $null
$sid = (New-Object System.Security.Principal.NTAccount($ServiceUserName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
if (Test-Path $regKey) {
    $profilePath = (Get-ItemProperty $regKey).ProfileImagePath
}
if (-not $profilePath -or -not (Test-Path $profilePath)) {
    if ($securePassword) {
        Write-Host "  Triggering profile creation for $ServiceUserName..." -ForegroundColor Yellow
        # Run a harmless command as the service user to force Windows to create the profile
        $cred = New-Object System.Management.Automation.PSCredential($ServiceUserName, $securePassword)
        # ponytail: cmd /c exit 0 is the lightest possible logon trigger; no UI, no session.
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "exit 0" -Credential $cred -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        # Now check the registry again
        if (Test-Path $regKey) {
            $profilePath = (Get-ItemProperty $regKey).ProfileImagePath
        }
    } else {
        Write-Host "  WARNING: Profile not found and password was set by a prior run." -ForegroundColor Yellow
        Write-Host "  Profile will be created on first SSH login. Key may need manual placement." -ForegroundColor Yellow
    }
}
if (-not $profilePath) {
    # Fallback: use the expected path (may not have the .MACHINE suffix)
    $profilePath = "C:\Users\$ServiceUserName"
}
Write-Host "  Profile path: $profilePath" -ForegroundColor Green

# Create .ssh directory in the REAL profile path
$sshDir = "$profilePath\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
# Set permissions -- service user gets full control, Administrators get full control so the
# admin running this bootstrap can write authorized_keys in step 5, SYSTEM gets full control
# (sshd runs as SYSTEM and needs to traverse the directory), sshd service account gets RX.
# The authorized_keys file itself is locked down after the key is written.
# ponytail: unconditional (idempotent) so re-runs repair an ACL left broken by a prior run.
Invoke-Suppressed { icacls $sshDir /inheritance:r /grant:r "$ServiceUserName`:(OI)(CI)F" /grant:r "Administrators`:(OI)(CI)F" /grant:r "NT AUTHORITY\SYSTEM`:(OI)(CI)F" /grant:r "NT SERVICE\sshd`:(OI)(CI)RX" }
# Reassign ownership to the service user. Win32-OpenSSH StrictModes (default on)
# silently rejects authorized_keys whose owner is not the user or SYSTEM. Files
# created by the admin are owned by Administrators, so sshd refuses the key
# even when the ACL is correct. icacles can't change owner; takeown.exe + icacls /setowner.
# ponytail: idempotent -- runs every time, no-op if already correct.
Invoke-Suppressed { takeown /f $sshDir /r /d y }
Invoke-Suppressed { icacls $sshDir /setowner "$ServiceUserName" /T /C }
Write-Host "  .ssh directory ready at $sshDir" -ForegroundColor Green
Write-Host ""

# --- Step 5: Add SSH public key ---
Write-Host "[5/6] Adding SSH public key for $ServiceUserName..." -ForegroundColor Yellow

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
# left it locked to the service user only, blocking the running admin from reading/appending.
# The .ssh directory ACL (Administrators:(OI)(CI)F) lets us create the file if missing,
# but an existing file with /inheritance:r doesn't inherit that grant. Running icacls
# here ensures the admin can access the file regardless of its prior state.
# Ownership is also repaired: files created by the admin are owned by Administrators,
# which sshd's StrictModes silently rejects (owner must be the user or SYSTEM).
# ponytail: takeown must run BEFORE icacls /grant. An elevated admin can always
# take ownership (SeTakeOwnershipPrivilege) but can only modify a DACL if it's
# the owner or has WRITE_DAC. A prior run leaves the file owned by $ServiceUserName
# with no Administrators ACE, so icacls /grant would silently fail without the
# takeown first.
if (Test-Path $authKeysPath) {
    Invoke-Suppressed { takeown /f $authKeysPath }
    Invoke-Suppressed { icacls $authKeysPath /inheritance:r /grant:r "$ServiceUserName`:(R)" /grant:r "NT SERVICE\sshd`:(R)" /grant:r "NT AUTHORITY\SYSTEM`:(F)" /grant:r "Administrators`:(F)" }
    Invoke-Suppressed { icacls $authKeysPath /setowner "$ServiceUserName" /C }
}

$existingKeys = $null
if (Test-Path $authKeysPath) {
    $existingKeys = Get-Content $authKeysPath -Raw -ErrorAction SilentlyContinue
}
if ($existingKeys -and $existingKeys.Contains($pubKey)) {
    Write-Host "  SSH public key already in $authKeysPath" -ForegroundColor Green
} else {
    Add-Content -Path $authKeysPath -Value $pubKey -Encoding ASCII
    # ACL: service user gets read, sshd service account gets read, SYSTEM gets full
    # (sshd runs as SYSTEM -- without SYSTEM:(F) on some Win32-OpenSSH builds the key
    #  is silently unreadable even with NT SERVICE\sshd:(R); see Win32-OpenSSH #2264),
    # Administrators gets full so the admin running bootstrap can repair on re-runs.
    Invoke-Suppressed { icacls $authKeysPath /inheritance:r /grant:r "$ServiceUserName`:(R)" /grant:r "NT SERVICE\sshd`:(R)" /grant:r "NT AUTHORITY\SYSTEM`:(F)" /grant:r "Administrators`:(F)" }
    # Reassign ownership to the service user -- see StrictModes note above. Files created
    # by the admin are owned by Administrators; sshd rejects keys not owned by user or SYSTEM.
    Invoke-Suppressed { takeown /f $authKeysPath }
    Invoke-Suppressed { icacls $authKeysPath /setowner "$ServiceUserName" /C }
    Write-Host "  SSH public key added to $authKeysPath" -ForegroundColor Green
}
Write-Host ""

# --- Step 6: Verify ---
Write-Host "[6/6] Verification..." -ForegroundColor Yellow

$sshServiceCheck = Get-Service sshd
Write-Host "  sshd: $($sshServiceCheck.Status) (Startup: $($sshServiceCheck.StartType))"

$pyVer = & $pythonExe --version 2>&1
Write-Host "  Python: $pyVer ($pythonExe)"

$dockerPipCheck = & $pythonExe -m pip show docker 2>$null
if ($dockerPipCheck) {
    Write-Host "  docker pip: installed"
} else {
    Write-Host "  docker pip: NOT installed" -ForegroundColor Red
}

$userCheck = Get-LocalUser -Name $ServiceUserName -ErrorAction SilentlyContinue
if ($userCheck) {
    Write-Host "  $ServiceUserName user: exists (enabled: $($userCheck.Enabled))" -NoNewline
    if ($userCheck.PasswordLastSet) {
        Write-Host " (password set: $($userCheck.PasswordLastSet))" -ForegroundColor Green
    } else {
        Write-Host " (NO PASSWORD -- SSH will be blocked by LimitBlankPasswordUse)" -ForegroundColor Red
        Write-Host "ERROR: $ServiceUserName has no password. Re-run step 4 or set one manually:" -ForegroundColor Red
        Write-Host "  \$pw = Read-Host -AsSecureString; Set-LocalUser -Name $ServiceUserName -Password \$pw" -ForegroundColor Red
        exit 1
    }
    # Verify admin group membership
    $adminCheck = (Get-LocalGroupMember -Group Administrators -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "\\$ServiceUserName$" })
    if ($adminCheck) {
        Write-Host "  $ServiceUserName in Administrators group: yes" -ForegroundColor Green
    } else {
        Write-Host "  $ServiceUserName in Administrators group: NO" -ForegroundColor Red
        Write-Host "ERROR: $ServiceUserName is not an admin. Re-run step 4 or add manually:" -ForegroundColor Red
        Write-Host "  Add-LocalGroupMember -Group Administrators -Member $ServiceUserName" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  $ServiceUserName user: NOT found" -ForegroundColor Red
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
Write-Host "Service account: $ServiceUserName (admin)"
Write-Host "Profile: $profilePath"
Write-Host "Key file: $authKeysPath"
Write-Host ""
Write-Host "From the control Mac, verify SSH access:"
Write-Host "  ssh $ServiceUserName@$lanIp"
Write-Host ""
Write-Host "Then run the Ansible bootstrap:"
Write-Host "  just ansible-bootstrap-windows-docker"
