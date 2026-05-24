# 🪟 Windows Client Setup Guide

Complete guide to configure a Windows machine to use Home Lab In-a-Box services.

## Prerequisites

- Windows 10 (1903+) or Windows 11
- Windows Server 2019 or newer (for server editions)
- Network access to the Home Lab host
- Administrator privileges
- PowerShell 5.1 or newer

## Environment Variables

Throughout this guide, replace this value:

```powershell
# Set your Home Lab host IP address
$HOMELAB_HOST = "192.168.1.100"
```

---

## 🌐 Part 1: Base Network Services

### DNS Configuration

#### Option A: System-Wide DNS (Recommended)

**Using PowerShell (Administrator)**:

```powershell
# 1. Get your active network adapter name
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object Name, InterfaceDescription

# 2. Set the adapter name (replace 'Ethernet' with your adapter name)
$AdapterName = "Ethernet"

# 3. Set Home Lab DNS as primary
Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ServerAddresses $HOMELAB_HOST,"1.1.1.1"

# 4. Verify configuration
Get-DnsClientServerAddress -InterfaceAlias $AdapterName

# 5. Clear DNS cache
Clear-DnsClientCache

# 6. Test DNS resolution
Resolve-DnsName google.com -Server $HOMELAB_HOST
```

**Using Network Settings GUI**:

1. Open **Settings** → **Network & Internet**
2. Click on your connection type (**Ethernet** or **Wi-Fi**)
3. Click **Properties**
4. Under **IP settings**, click **Edit**
5. Select **Manual** and enable **IPv4**
6. Set **Preferred DNS** to your Home Lab IP (e.g., `192.168.1.100`)
7. Set **Alternate DNS** to `1.1.1.1` or `8.8.8.8`
8. Click **Save**

**Using Control Panel (Legacy)**:

1. Open **Control Panel** → **Network and Internet** → **Network Connections**
2. Right-click your adapter → **Properties**
3. Select **Internet Protocol Version 4 (TCP/IPv4)** → **Properties**
4. Select **Use the following DNS server addresses**
5. **Preferred DNS server**: Your Home Lab IP
6. **Alternate DNS server**: `1.1.1.1` or `8.8.8.8`
7. Click **OK**

#### Option B: Per-Application DNS

**Firefox**:

1. Go to `about:config`
2. Set `network.trr.mode` = `2` (TRR with fallback)
3. Set `network.trr.uri` = `https://192.168.1.100/dns-query`

**Chrome/Edge**:

1. Settings → Privacy and security → Security
2. Scroll to **Advanced** → **Use secure DNS**
3. Select **Custom** and enter: `https://192.168.1.100/dns-query`

---

### NTP Configuration

**Using PowerShell (Administrator)**:

```powershell
# 1. Stop Windows Time service
Stop-Service w32time

# 2. Configure NTP server
w32tm /config /manualpeerlist:"$HOMELAB_HOST,0x8 time.google.com,0x8" /syncfromflags:manual /reliable:yes /update

# 3. Start Windows Time service
Start-Service w32time

# 4. Force synchronization
w32tm /resync /force

# 5. Verify configuration
w32tm /query /status
w32tm /query /source
w32tm /query /peers
```

**Using Registry Editor (Advanced)**:

```powershell
# Configure via registry
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
Set-ItemProperty -Path $RegPath -Name "NtpServer" -Value "$HOMELAB_HOST,0x8 time.google.com,0x8"
Set-ItemProperty -Path $RegPath -Name "Type" -Value "NTP"

# Restart time service
Restart-Service w32time

# Verify
w32tm /query /configuration
```

**Using Group Policy (Domain environments)**:

1. Open **gpedit.msc**
2. Navigate to: **Computer Configuration** → **Administrative Templates** → **System** → **Windows Time Service** → **Time Providers**
3. Enable **Configure Windows NTP Client**
4. Set **NtpServer** to: `192.168.1.100,0x8 time.google.com,0x8`
5. Set **Type** to: `NTP`
6. Run `gpupdate /force`

---

### Web Proxy Configuration

#### Option A: System-Wide Proxy

**Using PowerShell**:

```powershell
# 1. Configure proxy settings
$ProxyServer = "${HOMELAB_HOST}:3128"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value $ProxyServer
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyOverride -Value "localhost;127.0.0.1;<local>"

# 2. Set environment variables (for current session)
$env:HTTP_PROXY = "http://$ProxyServer"
$env:HTTPS_PROXY = "http://$ProxyServer"
$env:NO_PROXY = "localhost,127.0.0.1,.local"

# 3. Set system-wide environment variables (requires Admin)
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://$ProxyServer", "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://$ProxyServer", "Machine")
[System.Environment]::SetEnvironmentVariable("NO_PROXY", "localhost,127.0.0.1,.local", "Machine")

# 4. Verify configuration
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyEnable, ProxyServer
```

**Using Settings GUI**:

1. Open **Settings** → **Network & Internet** → **Proxy**
2. Under **Manual proxy setup**, enable **Use a proxy server**
3. Set **Address** to your Home Lab IP
4. Set **Port** to `3128`
5. Set **Don't use proxy for** to: `localhost;127.0.0.1;<local>`
6. Click **Save**

**Using Internet Options (Legacy)**:

1. Open **Control Panel** → **Internet Options**
2. Go to **Connections** tab → **LAN settings**
3. Check **Use a proxy server for your LAN**
4. Set **Address** to Home Lab IP and **Port** to `3128`
5. Click **Advanced** and add exceptions: `localhost;127.0.0.1;<local>`
6. Click **OK**

#### Option B: Per-Application Proxy

**Git for Windows**:

```powershell
# Configure Git to use proxy
git config --global http.proxy http://${HOMELAB_HOST}:3128
git config --global https.proxy http://${HOMELAB_HOST}:3128

# Verify
git config --global --get http.proxy
```

**PowerShell/Invoke-WebRequest**:

```powershell
# Per-command proxy
$ProxyUrl = "http://${HOMELAB_HOST}:3128"
Invoke-WebRequest -Uri "https://google.com" -Proxy $ProxyUrl

# Set default proxy for session
$PSDefaultParameterValues = @{
    'Invoke-RestMethod:Proxy' = $ProxyUrl
    'Invoke-WebRequest:Proxy' = $ProxyUrl
}
```

**cURL (Windows)**:

```powershell
# Create .curlrc in user home directory
$CurlConfig = "$env:USERPROFILE\.curlrc"
@"
proxy = http://${HOMELAB_HOST}:3128
"@ | Out-File -FilePath $CurlConfig -Encoding ASCII
```

**WSL (Windows Subsystem for Linux)**:

```powershell
# Configure proxy for WSL
# Add to ~/.bashrc or ~/.zshrc in WSL:
wsl bash -c @"
echo 'export http_proxy=http://${HOMELAB_HOST}:3128' >> ~/.bashrc
echo 'export https_proxy=http://${HOMELAB_HOST}:3128' >> ~/.bashrc
echo 'export no_proxy=localhost,127.0.0.1,.local' >> ~/.bashrc
"@
```

**Docker Desktop for Windows**:

1. Open **Docker Desktop** → **Settings**
2. Go to **Resources** → **Proxies**
3. Enable **Manual proxy configuration**
4. Set **Web Server (HTTP)**: `http://192.168.1.100:3128`
5. Set **Secure Web Server (HTTPS)**: `http://192.168.1.100:3128`
6. Set **Bypass for these hosts**: `localhost,127.0.0.1,.local`
7. Click **Apply & Restart**

---

## 📦 Part 2: Artifact Repositories

### NPM Configuration (Verdaccio)

**PowerShell**:

```powershell
# 1. Configure npm registry
npm config set registry http://${HOMELAB_HOST}:4873/

# 2. Verify configuration
npm config get registry

# 3. Test by searching for a package
npm search express

# 4. (Optional) Configure for specific scope
npm config set @mycompany:registry http://${HOMELAB_HOST}:4873/

# 5. (Optional) Revert to default
# npm config delete registry
```

**Project-specific configuration (.npmrc)**:

```powershell
# Create .npmrc in project root
@"
registry=http://${HOMELAB_HOST}:4873/
"@ | Out-File -FilePath ".npmrc" -Encoding ASCII
```

---

### Maven Configuration (Nexus)

**PowerShell**:

```powershell
# 1. Create Maven settings directory
$MavenDir = "$env:USERPROFILE\.m2"
New-Item -ItemType Directory -Force -Path $MavenDir

# 2. Backup existing settings
if (Test-Path "$MavenDir\settings.xml") {
    Copy-Item "$MavenDir\settings.xml" "$MavenDir\settings.xml.backup"
}

# 3. Create Maven settings
$SettingsXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <mirrors>
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://${HOMELAB_HOST}:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
</settings>
"@
$SettingsXml | Out-File -FilePath "$MavenDir\settings.xml" -Encoding UTF8

# 4. Test by building a Maven project
mvn clean package
```

---

### Docker Registry (Nexus)

**Docker Desktop Configuration**:

```powershell
# 1. Create or update Docker daemon config
$DockerConfigPath = "$env:USERPROFILE\.docker\daemon.json"
$DockerConfig = @{
    "insecure-registries" = @("${HOMELAB_HOST}:8082")
    "registry-mirrors" = @("http://${HOMELAB_HOST}:8082")
}

# 2. Save configuration
$DockerConfig | ConvertTo-Json | Out-File -FilePath $DockerConfigPath -Encoding UTF8

# 3. Restart Docker Desktop (manually or via PowerShell)
Restart-Service -Name "com.docker.service" -Force

# 4. Test pull through cache
docker pull ${HOMELAB_HOST}:8082/library/alpine:latest

# 5. Tag and push to private registry
docker tag alpine:latest ${HOMELAB_HOST}:8082/alpine:latest
docker push ${HOMELAB_HOST}:8082/alpine:latest
```

---

### Python/PyPI Configuration (Nexus)

**PowerShell**:

```powershell
# 1. Create pip configuration directory
$PipConfigDir = "$env:APPDATA\pip"
New-Item -ItemType Directory -Force -Path $PipConfigDir

# 2. Configure pip
$PipConfig = @"
[global]
index-url = http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
trusted-host = ${HOMELAB_HOST}
"@
$PipConfig | Out-File -FilePath "$PipConfigDir\pip.ini" -Encoding ASCII

# 3. Test by installing a package
pip install requests

# 4. Verify configuration
pip config list
```

**Alternative: Per-Project Configuration**:

```powershell
# Create pip.conf in project root
@"
[global]
index-url = http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
trusted-host = ${HOMELAB_HOST}
"@ | Out-File -FilePath "pip.conf" -Encoding ASCII
```

---

## 🧪 Verification & Testing

### Test DNS

```powershell
# Test basic resolution
Resolve-DnsName google.com -Server $HOMELAB_HOST

# Test with nslookup
nslookup google.com $HOMELAB_HOST

# Check current DNS servers
Get-DnsClientServerAddress

# Clear and test
Clear-DnsClientCache
Resolve-DnsName google.com
```

### Test NTP

```powershell
# Check synchronization status
w32tm /query /status

# Show current time source
w32tm /query /source

# Show peer information
w32tm /query /peers

# Force sync and test
w32tm /resync /force
```

### Test Proxy

```powershell
# Test HTTP proxy
Invoke-WebRequest -Uri "http://google.com" -Proxy "http://${HOMELAB_HOST}:3128"

# Test HTTPS proxy
Invoke-WebRequest -Uri "https://google.com" -Proxy "http://${HOMELAB_HOST}:3128"

# Check registry settings
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Check environment variables
Get-ChildItem Env: | Where-Object {$_.Name -like "*PROXY*"}
```

### Test Artifact Repositories

```powershell
# Test Verdaccio
Invoke-WebRequest -Uri "http://${HOMELAB_HOST}:4873/"

# Test Nexus
Invoke-WebRequest -Uri "http://${HOMELAB_HOST}:8081/service/rest/v1/status"

# Test npm registry
npm ping --registry http://${HOMELAB_HOST}:4873/
```

---

## 🔧 Troubleshooting

### DNS Issues

```powershell
# Check if DNS port is reachable
Test-NetConnection -ComputerName $HOMELAB_HOST -Port 53

# Test with explicit DNS server
Resolve-DnsName google.com -Server $HOMELAB_HOST

# Check DNS client service
Get-Service -Name Dnscache
Restart-Service -Name Dnscache

# View DNS cache
Get-DnsClientCache

# Clear DNS cache
Clear-DnsClientCache
```

### NTP Issues

```powershell
# Check if NTP port is reachable (UDP 123 - requires admin)
# Note: Test-NetConnection doesn't support UDP well, use w32tm instead

# Check Windows Time service status
Get-Service -Name w32time

# Restart Windows Time service
Restart-Service -Name w32time

# View time service logs
w32tm /query /status /verbose

# Re-register time service
w32tm /unregister
w32tm /register
Restart-Service -Name w32time
```

### Proxy Issues

```powershell
# Test direct connection (bypass proxy)
Invoke-WebRequest -Uri "https://google.com" -NoProxy

# Check proxy connectivity
Test-NetConnection -ComputerName $HOMELAB_HOST -Port 3128

# Test with verbose output
$ProgressPreference = 'Continue'
Invoke-WebRequest -Uri "https://google.com" -Proxy "http://${HOMELAB_HOST}:3128" -Verbose

# Check current proxy settings
netsh winhttp show proxy
```

---

## 🔄 Reverting Configuration

### Revert DNS

```powershell
# Reset to automatic DNS
$AdapterName = "Ethernet"  # Replace with your adapter name
Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ResetServerAddresses

# Verify
Get-DnsClientServerAddress -InterfaceAlias $AdapterName

# Clear cache
Clear-DnsClientCache
```

### Revert NTP

```powershell
# Reset to default Windows time servers
w32tm /config /syncfromflags:domhier /update
Restart-Service w32time

# Verify
w32tm /query /source
```

### Revert Proxy

```powershell
# Disable proxy in registry
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0

# Remove environment variables
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $null, "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $null, "Machine")
[System.Environment]::SetEnvironmentVariable("NO_PROXY", $null, "Machine")

# For current session
Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue

# Git
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## 📚 Additional Resources

- [Home Lab README](../README.md)
- [Architecture Overview](./architecture.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Port Mapping Reference](./port-mapping.md)

---

## 💡 Tips for Windows Users

### Running Scripts

If you get execution policy errors, run PowerShell as Administrator and execute:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Quick Configuration Script

Create a script `configure-homelab.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$HomeLab Host
)

# DNS
$AdapterName = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).Name
Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ServerAddresses $HomeLab Host,"1.1.1.1"

# NTP
Stop-Service w32time
w32tm /config /manualpeerlist:"$HomeLab Host,0x8" /syncfromflags:manual /reliable:yes /update
Start-Service w32time
w32tm /resync /force

# Proxy
$ProxyServer = "${HomeLab Host}:3128"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value $ProxyServer

Write-Host "Configuration complete!" -ForegroundColor Green
```

Run it:

```powershell
.\configure-homelab.ps1 -HomeLab Host "192.168.1.100"
```

---

**Last Updated**: 2025-01-21  
**Tested On**: Windows 10 (21H2, 22H2), Windows 11 (22H2, 23H2), Windows Server 2022
