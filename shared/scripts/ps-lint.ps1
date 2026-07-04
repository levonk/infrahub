#Requires -Version 7.0
<#
.SYNOPSIS
    Runs PSScriptAnalyzer on all .ps1 files under the shared/ directory.
    Used by `just ps-lint-internal`. Installs PSScriptAnalyzer if missing.
#>
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -AcceptLicense
}

$files = @(Get-ChildItem -Path "$Root/shared" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "ps-lint.ps1" })
if ($files.Count -eq 0) {
    Write-Host "No .ps1 files found."
    exit 0
}

Write-Host "Linting $($files.Count) .ps1 file(s)..."
$results = @($files.FullName | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Severity Error,Warning })
if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
    exit 1
} else {
    Write-Host "No issues found." -ForegroundColor Green
    exit 0
}
