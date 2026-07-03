# SSH ACL Drift Check — deployed by common-windows-ssh-hardening Ansible role.
# Runs as a scheduled task (twice daily). Verifies that the .ssh directory and
# authorized_keys file for the ansible service account have the ACL mandated by
# Microsoft's OpenSSH docs (PowerShell/Win32-OpenSSH #870). If non-conformant,
# writes a Warning event to the Application log (source: SSH-AclDriftCheck).
# Exit code 0 always — this is a check, not a repair. Ansible repairs on next run.

param(
    [string]$UserName = "ansible"
)

$ErrorActionPreference = "Stop"
$EventSource = "SSH-AclDriftCheck"
$SshDir = "C:\Users\$UserName\.ssh"
$AuthKeysPath = "$SshDir\authorized_keys"

# Ensure the event source exists (requires admin once, then persists).
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, "Application")
}

$problems = @()

# --- Check .ssh directory ACL ---
if (-not (Test-Path $SshDir)) {
    $problems += ".ssh directory missing: $SshDir"
} else {
    $dirAcl = (Get-Acl $SshDir).Access | Where-Object { $_.AccessControlType -eq "Allow" } |
        ForEach-Object { "$($_.IdentityReference)|$($_.FileSystemRights)|$($_.InheritanceFlags)" }

    $expectedDirAces = @(
        "$env:COMPUTERNAME\$UserName|FullControl|ContainerInherit, ObjectInherit",
        "BUILTIN\Administrators|FullControl|ContainerInherit, ObjectInherit"
    )

    foreach ($ace in $expectedDirAces) {
        # ponytail: substring match instead of exact equality — InheritanceFlags string
        # ordering can vary across PowerShell versions. Ceiling: false positive if a
        # wrong SID has a superset string. Upgrade path: parse ACEs as structured objects.
        $identity = ($ace -split '\|')[0]
        if (-not ($dirAcl | Where-Object { $_ -like "$identity|*" })) {
            $problems += ".ssh directory missing ACE: $ace"
        }
    }
}

# --- Check authorized_keys file ACL ---
if (-not (Test-Path $AuthKeysPath)) {
    $problems += "authorized_keys missing: $AuthKeysPath"
} else {
    $fileAcl = (Get-Acl $AuthKeysPath).Access | Where-Object { $_.AccessControlType -eq "Allow" } |
        ForEach-Object { "$($_.IdentityReference)|$($_.FileSystemRights)" }

    $expectedFileAces = @(
        "$env:COMPUTERNAME\$UserName|Read",
        "NT SERVICE\sshd|Read"
    )

    foreach ($ace in $expectedFileAces) {
        $identity = ($ace -split '\|')[0]
        if (-not ($fileAcl | Where-Object { $_ -like "$identity|*" })) {
            $problems += "authorized_keys missing ACE: $ace"
        }
    }
}

if ($problems.Count -gt 0) {
    $msg = $problems -join "`n"
    [System.Diagnostics.EventLog]::WriteEntry($EventSource, $msg, [System.Diagnostics.EventLogEntryType]::Warning, 1)
    Write-Output "NON_CONFORMANT: $msg"
} else {
    Write-Output "CONFORMANT"
}
exit 0
