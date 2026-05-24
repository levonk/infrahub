# Port 4461 Blocking Diagnostic Script
# Purpose: Identify where TCP/4460 (NTS-KE) is being blocked
# Run this in PowerShell (does not require Administrator)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Port 4460 Blocking Diagnostic" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test servers
$servers = @(
    "time.google.com",
    "time2.google.com",
    "time.nist.gov"
)

# 1. Test TCP/4460 connectivity from Windows
Write-Host "1. Testing TCP/4460 from Windows Host" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "Testing $server`:4460... " -NoNewline
    $result = Test-NetConnection -ComputerName $server -Port 4460 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($result) {
        Write-Host "OPEN" -ForegroundColor Green
    } else {
        Write-Host "BLOCKED/TIMEOUT" -ForegroundColor Red
    }
}
Write-Host ""

# 2. Compare with working port (443)
Write-Host "2. Baseline Test - TCP/443 (HTTPS)" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$testServer = "time.google.com"
Write-Host "Testing $testServer`:443... " -NoNewline
$result = Test-NetConnection -ComputerName $testServer -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
if ($result) {
    Write-Host "OPEN" -ForegroundColor Green
} else {
    Write-Host "BLOCKED/TIMEOUT" -ForegroundColor Red
}
Write-Host ""

# 3. Check Windows Firewall rules
Write-Host "3. Checking Windows Firewall Rules" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
try {
    $blockRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {$_.Action -eq "Block" -and $_.Enabled -eq "True"}
    $port4460Rules = Get-NetFirewallPortFilter -ErrorAction SilentlyContinue | Where-Object {$_.RemotePort -eq "4460"}

    if ($port4460Rules) {
        Write-Host "Found firewall rules for port 4460:" -ForegroundColor Red
        $port4460Rules | Get-NetFirewallRule | Format-Table DisplayName, Action, Enabled -AutoSize
    } else {
        Write-Host "No Windows Firewall rules found for port 4460" -ForegroundColor Green
    }
} catch {
    Write-Host "Unable to check firewall rules (may need Administrator)" -ForegroundColor Yellow
}
Write-Host ""

# 4. Check for third-party security software
Write-Host "4. Checking for Security Software" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$securitySoftware = @(
    "Norton*",
    "McAfee*",
    "Kaspersky*",
    "Bitdefender*",
    "Avast*",
    "AVG*",
    "Malwarebytes*",
    "ESET*",
    "Trend Micro*",
    "Sophos*",
    "Windows Defender"
)

$foundSoftware = @()
foreach ($software in $securitySoftware) {
    $installed = Get-Process -Name $software.Replace("*", "") -ErrorAction SilentlyContinue
    if ($installed) {
        $foundSoftware += $software
    }
}

if ($foundSoftware.Count -gt 0) {
    Write-Host "Found security software:" -ForegroundColor Yellow
    foreach ($sw in $foundSoftware) {
        Write-Host "  - $sw" -ForegroundColor Yellow
    }
    Write-Host "Check these applications' firewall settings for port 4460 blocks" -ForegroundColor Yellow
} else {
    Write-Host "No common third-party security software detected" -ForegroundColor Green
}
Write-Host ""

# 5. Check VPN status
Write-Host "5. Checking VPN Status" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$vpnConnections = Get-VpnConnection -ErrorAction SilentlyContinue
if ($vpnConnections) {
    $activeVpn = $vpnConnections | Where-Object {$_.ConnectionStatus -eq "Connected"}
    if ($activeVpn) {
        Write-Host "Active VPN connections found:" -ForegroundColor Yellow
        $activeVpn | Format-Table Name, ServerAddress, ConnectionStatus -AutoSize
        Write-Host "VPN may be blocking port 4460" -ForegroundColor Yellow
    } else {
        Write-Host "VPN configured but not connected" -ForegroundColor Green
    }
} else {
    Write-Host "No VPN connections found" -ForegroundColor Green
}
Write-Host ""

# 6. Network adapter information
Write-Host "6. Network Adapter Information" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    Write-Host "$($adapter.Name): $($adapter.InterfaceDescription)" -ForegroundColor Cyan
}
Write-Host ""

# 7. DNS resolution test
Write-Host "7. DNS Resolution Test" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
foreach ($server in $servers) {
    Write-Host "Resolving $server... " -NoNewline
    try {
        $ips = [System.Net.Dns]::GetHostAddresses($server)
        Write-Host "OK ($($ips.Count) addresses)" -ForegroundColor Green
    } catch {
        Write-Host "FAILED" -ForegroundColor Red
    }
}
Write-Host ""

# 8. Detailed connection test with timing
Write-Host "8. Detailed Connection Test (with timing)" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow
$testServer = "time.google.com"
Write-Host "Testing $testServer`:4460 with details..." -ForegroundColor Cyan
$result = Test-NetConnection -ComputerName $testServer -Port 4460 -WarningAction SilentlyContinue

Write-Host "  Remote Address: $($result.RemoteAddress)" -ForegroundColor Gray
Write-Host "  TCP Test Succeeded: $($result.TcpTestSucceeded)" -ForegroundColor $(if ($result.TcpTestSucceeded) { "Green" } else { "Red" })
Write-Host "  Ping Succeeded: $($result.PingSucceeded)" -ForegroundColor $(if ($result.PingSucceeded) { "Green" } else { "Yellow" })
if ($result.PingReplyDetails) {
    Write-Host "  Ping Reply Time: $($result.PingReplyDetails.RoundtripTime)ms" -ForegroundColor Gray
}
Write-Host ""

# Summary and recommendations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY & RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$port4460Blocked = -not (Test-NetConnection -ComputerName "time.google.com" -Port 4460 -WarningAction SilentlyContinue -InformationLevel Quiet)
$port443Works = Test-NetConnection -ComputerName "time.google.com" -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet

if ($port4460Blocked -and $port443Works) {
    Write-Host ""
    Write-Host "DIAGNOSIS: Port 4460 is specifically blocked" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes (in order of likelihood):" -ForegroundColor Yellow
    Write-Host "  1. ISP blocking non-standard ports" -ForegroundColor Yellow
    Write-Host "  2. Router firewall settings" -ForegroundColor Yellow
    if ($foundSoftware.Count -gt 0) {
        Write-Host "  3. Third-party security software (detected above)" -ForegroundColor Yellow
    }
    if ($activeVpn) {
        Write-Host "  4. VPN blocking the port (VPN active)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Green
    Write-Host "  1. Check router admin panel for port filtering" -ForegroundColor White
    Write-Host "  2. Contact ISP to ask about port 4460 blocking" -ForegroundColor White
    Write-Host "  3. Use fallback non-NTS servers (already configured)" -ForegroundColor White
    Write-Host ""
    Write-Host "CURRENT WORKAROUND:" -ForegroundColor Cyan
    Write-Host "  Your chronyd is using fallback servers successfully:" -ForegroundColor White
    Write-Host "    - Cloudflare NTP (time.cloudflare.com)" -ForegroundColor White
    Write-Host "    - Apple NTP (time.apple.com)" -ForegroundColor White
    Write-Host "    - Microsoft NTP (time.windows.com)" -ForegroundColor White
    Write-Host "  These provide reliable time sync without NTS encryption." -ForegroundColor White
} elseif (-not $port4460Blocked) {
    Write-Host ""
    Write-Host "DIAGNOSIS: Port 4460 is OPEN from Windows!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This suggests the block is WSL2/Docker-specific." -ForegroundColor Yellow
    Write-Host "Check Docker Desktop network settings." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "DIAGNOSIS: Network connectivity issues detected" -ForegroundColor Red
    Write-Host "Both port 4460 and 443 are blocked - check internet connection" -ForegroundColor Red
}

Write-Host ""
Write-Host "Script completed." -ForegroundColor Cyan
Write-Host ""
