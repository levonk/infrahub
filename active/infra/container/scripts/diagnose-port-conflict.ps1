# Diagnose port conflicts on Windows
# Usage: .\diagnose-port-conflict.ps1 -Port 5353

param(
    [int]$Port = 5353,
    [switch]$ShowAll = $false
)

Write-Host "=== Port Conflict Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host "Checking port $Port for active connections..." -ForegroundColor Yellow
Write-Host ""

# Get all connections on the specified port
$connections = netstat -ano | Select-String $Port

if ($connections.Count -eq 0) {
    Write-Host "✓ No connections found on port $Port" -ForegroundColor Green
    exit 0
}

Write-Host "Found $(($connections | Measure-Object).Count) connection(s) on port $Port:" -ForegroundColor Yellow
Write-Host ""

# Parse and deduplicate by PID
$pids = @{}
foreach ($line in $connections) {
    $parts = $line -split '\s+' | Where-Object { $_ }
    if ($parts.Count -ge 5) {
        $pid = $parts[-1]
        if ($pid -match '^\d+$') {
            $pids[$pid] = $true
        }
    }
}

# Get process details for each unique PID
$processes = @()
foreach ($pid in $pids.Keys) {
    try {
        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($process) {
            $processes += @{
                PID = $pid
                Name = $process.ProcessName
                Memory = "{0:N0} KB" -f ($process.WorkingSet / 1KB)
                Path = $process.Path
            }
        }
    }
    catch {
        # Process may have terminated
    }
}

# Display results
if ($processes.Count -eq 0) {
    Write-Host "Could not identify processes. Try running as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Processes using port $Port`:" -ForegroundColor Cyan
Write-Host ""

foreach ($proc in $processes | Sort-Object -Property Name) {
    Write-Host "  PID: $($proc.PID)" -ForegroundColor White
    Write-Host "  Name: $($proc.Name)" -ForegroundColor Green
    Write-Host "  Memory: $($proc.Memory)" -ForegroundColor Gray
    if ($proc.Path) {
        Write-Host "  Path: $($proc.Path)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Provide recommendations
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host ""

$systemServices = @("svchost", "services", "system")
$isSystemService = $processes | Where-Object { $systemServices -contains $_.Name }

if ($isSystemService) {
    Write-Host "⚠️  System service detected. Options:" -ForegroundColor Yellow
    Write-Host "  1. Change LocalNet service to use a different port (recommended)" -ForegroundColor White
    Write-Host "  2. Stop the conflicting Windows service (if safe)" -ForegroundColor White
    Write-Host "  3. Restart WSL2: wsl --shutdown" -ForegroundColor White
}
else {
    Write-Host "💡 Application detected. Options:" -ForegroundColor Yellow
    Write-Host "  1. Close the application" -ForegroundColor White
    Write-Host "  2. Change LocalNet service to use a different port" -ForegroundColor White
}

Write-Host ""
Write-Host "For more details, see: internal-docs/troubleshooting-port-in-use.md" -ForegroundColor Cyan
