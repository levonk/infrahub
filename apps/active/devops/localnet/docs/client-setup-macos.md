# 🍎 macOS Client Setup Guide

Complete guide to configure a macOS machine to use Home Lab In-a-Box services.

## Prerequisites

- macOS 11 (Big Sur) or newer
- Network access to the Home Lab host
- Administrator privileges
- Homebrew (recommended) - Install from [brew.sh](https://brew.sh)

## Environment Variables

Throughout this guide, replace this value:

```bash
# Set your Home Lab host IP address
export HOMELAB_HOST="192.168.1.100"
```

---

## 🌐 Part 1: Base Network Services

### DNS Configuration

#### Option A: System-Wide DNS (Recommended)

**Using System Preferences (GUI)**:

1. Open **System Preferences** → **Network**
2. Select your active connection (Wi-Fi or Ethernet)
3. Click **Advanced**
4. Go to **DNS** tab
5. Click **+** and add your Home Lab IP (e.g., `192.168.1.100`)
6. Add fallback DNS: `1.1.1.1` and `8.8.8.8`
7. Click **OK** → **Apply**

**Using networksetup (CLI)**:

```bash
# 1. List network services
networksetup -listallnetworkservices

# 2. Set DNS servers (replace "Wi-Fi" with your service name)
SERVICE_NAME="Wi-Fi"
sudo networksetup -setdnsservers "$SERVICE_NAME" ${HOMELAB_HOST} 1.1.1.1 8.8.8.8

# 3. Verify configuration
networksetup -getdnsservers "$SERVICE_NAME"

# 4. Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 5. Test DNS resolution
dig @${HOMELAB_HOST} google.com
nslookup google.com
```

**Using scutil (Advanced)**:

```bash
# Create a custom DNS configuration
sudo scutil <<EOF
d.init
d.add ServerAddresses * ${HOMELAB_HOST} 1.1.1.1
set State:/Network/Service/CustomDNS/DNS
quit
EOF

# Verify
scutil --dns
```

#### Option B: Per-Application DNS

**Firefox**:

1. Go to `about:config`
2. Set `network.trr.mode` = `2` (TRR with fallback)
3. Set `network.trr.uri` = `https://${HOMELAB_HOST}/dns-query`

**Chrome/Safari**:

Chrome and Safari use system DNS settings, so configure system-wide DNS instead.

**Command-line tools**:

```bash
# dig with custom DNS
dig @${HOMELAB_HOST} google.com

# host with custom DNS  
host google.com ${HOMELAB_HOST}

# curl with custom DNS resolver
curl --dns-servers ${HOMELAB_HOST} https://example.com
```

---

### NTP Configuration

**Using systemsetup (GUI Equivalent)**:

```bash
# 1. Check current time server
sudo systemsetup -getnetworktimeserver

# 2. Enable network time
sudo systemsetup -setusingnetworktime on

# 3. Set Home Lab as NTP server
sudo systemsetup -setnetworktimeserver ${HOMELAB_HOST}

# 4. Verify configuration
sudo systemsetup -getnetworktimeserver

# 5. Force synchronization
sudo sntp -sS ${HOMELAB_HOST}
```

**Using timed (Alternative for older macOS)**:

```bash
# 1. Configure time daemon
sudo launchctl unload /System/Library/LaunchDaemons/org.ntp.ntpd.plist 2>/dev/null || true

# 2. Create custom NTP configuration
sudo tee /etc/ntp.conf > /dev/null <<EOF
# Home Lab NTP Server
server ${HOMELAB_HOST} iburst prefer
server time.google.com iburst
server time.apple.com iburst

# Drift file
driftfile /var/db/ntp.drift

# Allow stepping on startup
tinker panic 0
EOF

# 3. Restart time service
sudo launchctl load /System/Library/LaunchDaemons/org.ntp.ntpd.plist

# 4. Check synchronization
ntpq -p
```

**Using chrony (Homebrew Alternative)**:

```bash
# 1. Install chrony via Homebrew
brew install chrony

# 2. Configure chrony
sudo tee /opt/homebrew/etc/chrony.conf > /dev/null <<EOF
# Home Lab NTP server
server ${HOMELAB_HOST} iburst prefer
server time.google.com iburst
server time.apple.com iburst

# Allow stepping on startup
makestep 1.0 3

# Drift file
driftfile /opt/homebrew/var/lib/chrony/drift

# Log directory
logdir /opt/homebrew/var/log/chrony
EOF

# 3. Start chrony service
brew services start chrony

# 4. Verify synchronization
chronyc tracking
chronyc sources -v
```

---

### Web Proxy Configuration

#### Option A: System-Wide Proxy

**Using System Preferences (GUI)**:

1. Open **System Preferences** → **Network**
2. Select your active connection
3. Click **Advanced** → **Proxies** tab
4. Check **Web Proxy (HTTP)** and **Secure Web Proxy (HTTPS)**
5. For both, set **Server** to Home Lab IP and **Port** to `3128`
6. Add to **Bypass proxy for these hosts**: `localhost, 127.0.0.1, *.local`
7. Click **OK** → **Apply**

**Using networksetup (CLI)**:

```bash
# 1. Get your network service name
networksetup -listallnetworkservices

# 2. Set proxy for your service (replace "Wi-Fi" with your service name)
SERVICE_NAME="Wi-Fi"

# 3. Enable web proxy (HTTP)
sudo networksetup -setwebproxy "$SERVICE_NAME" ${HOMELAB_HOST} 3128 off

# 4. Enable secure web proxy (HTTPS)
sudo networksetup -setsecurewebproxy "$SERVICE_NAME" ${HOMELAB_HOST} 3128 off

# 5. Set proxy bypass domains
sudo networksetup -setproxybypassdomains "$SERVICE_NAME" localhost 127.0.0.1 "*.local"

# 6. Verify configuration
networksetup -getwebproxy "$SERVICE_NAME"
networksetup -getsecurewebproxy "$SERVICE_NAME"
```

**Using environment variables**:

```bash
# 1. Add to ~/.zshrc or ~/.bash_profile
cat >> ~/.zshrc <<'EOF'

# Home Lab Proxy Configuration
export HOMELAB_PROXY="192.168.1.100:3128"
export http_proxy="http://${HOMELAB_PROXY}"
export https_proxy="http://${HOMELAB_PROXY}"
export ftp_proxy="http://${HOMELAB_PROXY}"
export no_proxy="localhost,127.0.0.1,*.local"
export HTTP_PROXY="${http_proxy}"
export HTTPS_PROXY="${https_proxy}"
export FTP_PROXY="${ftp_proxy}"
export NO_PROXY="${no_proxy}"
EOF

# 2. Apply to current session
source ~/.zshrc

# 3. Test proxy
curl -I -x http://${HOMELAB_HOST}:3128 https://google.com
```

#### Option B: Per-Application Proxy

**Git**:

```bash
# Configure Git to use proxy
git config --global http.proxy http://${HOMELAB_HOST}:3128
git config --global https.proxy http://${HOMELAB_HOST}:3128

# Verify
git config --global --get http.proxy
```

**Homebrew**:

```bash
# Configure Homebrew proxy
export HOMEBREW_HTTP_PROXY="http://${HOMELAB_HOST}:3128"
export HOMEBREW_HTTPS_PROXY="http://${HOMELAB_HOST}:3128"

# Add to ~/.zshrc to persist
echo 'export HOMEBREW_HTTP_PROXY="http://${HOMELAB_HOST}:3128"' >> ~/.zshrc
echo 'export HOMEBREW_HTTPS_PROXY="http://${HOMELAB_HOST}:3128"' >> ~/.zshrc
```

**cURL**:

```bash
# Create ~/.curlrc
cat >> ~/.curlrc <<EOF
proxy = http://${HOMELAB_HOST}:3128
EOF
```

**Docker Desktop for Mac**:

1. Open **Docker Desktop** → **Preferences**
2. Go to **Resources** → **Proxies**
3. Enable **Manual proxy configuration**
4. Set **Web Server (HTTP)**: `http://192.168.1.100:3128`
5. Set **Secure Web Server (HTTPS)**: `http://192.168.1.100:3128`
6. Set **Bypass for these hosts**: `localhost,127.0.0.1,*.local`
7. Click **Apply & Restart**

---

## 📦 Part 2: Artifact Repositories

### NPM Configuration (Verdaccio)

```bash
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

```bash
# Create .npmrc in project root
cat > .npmrc <<EOF
registry=http://${HOMELAB_HOST}:4873/
EOF
```

---

### Maven Configuration (Nexus)

```bash
# 1. Backup existing settings
cp ~/.m2/settings.xml ~/.m2/settings.xml.backup 2>/dev/null || true

# 2. Create Maven settings
mkdir -p ~/.m2
cat > ~/.m2/settings.xml <<EOF
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
EOF

# 3. Test by building a Maven project
mvn clean package
```

---

### Docker Registry (Nexus)

```bash
# 1. Create Docker daemon config directory
mkdir -p ~/.docker

# 2. Configure Docker to use insecure registry (HTTP)
cat > ~/.docker/daemon.json <<EOF
{
  "insecure-registries": ["${HOMELAB_HOST}:8082"],
  "registry-mirrors": ["http://${HOMELAB_HOST}:8082"]
}
EOF

# 3. Restart Docker Desktop
# Manually restart via Docker Desktop UI, or:
osascript -e 'quit app "Docker"'
sleep 2
open -a Docker

# 4. Test pull through cache
docker pull ${HOMELAB_HOST}:8082/library/alpine:latest

# 5. Tag and push to private registry
docker tag alpine:latest ${HOMELAB_HOST}:8082/alpine:latest
docker push ${HOMELAB_HOST}:8082/alpine:latest
```

---

### Python/PyPI Configuration (Nexus)

```bash
# 1. Create pip configuration directory
mkdir -p ~/Library/Application\ Support/pip

# 2. Configure pip (macOS uses pip.conf in Application Support)
cat > ~/Library/Application\ Support/pip/pip.conf <<EOF
[global]
index-url = http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
trusted-host = ${HOMELAB_HOST}
EOF

# Alternative location: ~/.config/pip/pip.conf (XDG standard)
mkdir -p ~/.config/pip
cat > ~/.config/pip/pip.conf <<EOF
[global]
index-url = http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
trusted-host = ${HOMELAB_HOST}
EOF

# 3. Test by installing a package
pip install requests

# 4. Verify configuration
pip config list
```

---

### Homebrew Cache (Optional)

**Configure Homebrew to use local cache**:

```bash
# 1. Set Homebrew cache directory
export HOMEBREW_CACHE="/opt/homebrew/cache"

# 2. Configure Homebrew to use proxy (covered earlier)
export HOMEBREW_HTTP_PROXY="http://${HOMELAB_HOST}:3128"

# 3. Add to ~/.zshrc to persist
echo 'export HOMEBREW_CACHE="/opt/homebrew/cache"' >> ~/.zshrc

# 4. Test
brew update
brew install <package>
```

---

## 🧪 Verification & Testing

### Test DNS

```bash
# Test basic resolution
dig @${HOMELAB_HOST} google.com
nslookup google.com ${HOMELAB_HOST}

# Test DNSSEC
dig +dnssec google.com @${HOMELAB_HOST}

# Verify system DNS
scutil --dns | grep nameserver

# Flush cache and test
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Test NTP

```bash
# Check synchronization status
sudo systemsetup -getnetworktimeserver

# Test NTP server
sntp -d ${HOMELAB_HOST}

# For chrony users
chronyc tracking
chronyc sources -v
```

### Test Proxy

```bash
# Test HTTP proxy
curl -I -x http://${HOMELAB_HOST}:3128 http://google.com

# Test HTTPS proxy
curl -I -x http://${HOMELAB_HOST}:3128 https://google.com

# Check if proxy is being used
env | grep -i proxy

# Check system proxy settings
networksetup -getwebproxy "Wi-Fi"
networksetup -getsecurewebproxy "Wi-Fi"
```

### Test Artifact Repositories

```bash
# Test Verdaccio
curl http://${HOMELAB_HOST}:4873/

# Test Nexus
curl http://${HOMELAB_HOST}:8081/service/rest/v1/status

# Test npm registry
npm ping --registry http://${HOMELAB_HOST}:4873/
```

---

## 🔧 Troubleshooting

### DNS Issues

```bash
# Check if DNS port is reachable
nc -zvu ${HOMELAB_HOST} 53

# Test with explicit DNS server
dig @${HOMELAB_HOST} google.com

# Check current DNS servers
scutil --dns

# Clear DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Check mDNSResponder logs
log show --predicate 'process == "mDNSResponder"' --last 30m
```

### NTP Issues

```bash
# Check if NTP port is reachable
nc -zvu ${HOMELAB_HOST} 123

# Check current time server
sudo systemsetup -getnetworktimeserver

# Manual time sync
sudo sntp -sS ${HOMELAB_HOST}

# Check time synchronization logs
log show --predicate 'process == "timed"' --last 30m
```

### Proxy Issues

```bash
# Test direct connection (bypass proxy)
curl -I --noproxy "*" https://google.com

# Check proxy connectivity
nc -zv ${HOMELAB_HOST} 3128

# Test with verbose output
curl -v -x http://${HOMELAB_HOST}:3128 https://google.com

# Check environment variables
env | grep -i proxy

# Check system proxy settings
networksetup -getwebproxy "Wi-Fi"
```

---

## 🔄 Reverting Configuration

### Revert DNS

```bash
# Reset to DHCP-provided DNS
SERVICE_NAME="Wi-Fi"
sudo networksetup -setdnsservers "$SERVICE_NAME" "Empty"

# Verify
networksetup -getdnsservers "$SERVICE_NAME"

# Flush cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Revert NTP

```bash
# Reset to default Apple time servers
sudo systemsetup -setnetworktimeserver time.apple.com

# Verify
sudo systemsetup -getnetworktimeserver

# For chrony users
brew services stop chrony
```

### Revert Proxy

```bash
# Disable system-wide proxy
SERVICE_NAME="Wi-Fi"
sudo networksetup -setwebproxystate "$SERVICE_NAME" off
sudo networksetup -setsecurewebproxystate "$SERVICE_NAME" off

# Unset environment variables
unset http_proxy https_proxy ftp_proxy no_proxy
unset HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY

# Remove from shell config (edit ~/.zshrc manually)

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

## 💡 Tips for macOS Users

### Scripting Configuration

Create a configuration script `configure-homelab.sh`:

```bash
#!/bin/bash
set -euo pipefail

HOMELAB_HOST="${1:-192.168.1.100}"
SERVICE_NAME="${2:-Wi-Fi}"

echo "Configuring macOS for Home Lab: ${HOMELAB_HOST}"

# DNS
echo "Setting DNS..."
sudo networksetup -setdnsservers "$SERVICE_NAME" ${HOMELAB_HOST} 1.1.1.1
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# NTP
echo "Setting NTP..."
sudo systemsetup -setusingnetworktime on
sudo systemsetup -setnetworktimeserver ${HOMELAB_HOST}

# Proxy
echo "Setting Proxy..."
sudo networksetup -setwebproxy "$SERVICE_NAME" ${HOMELAB_HOST} 3128 off
sudo networksetup -setsecurewebproxy "$SERVICE_NAME" ${HOMELAB_HOST} 3128 off
sudo networksetup -setproxybypassdomains "$SERVICE_NAME" localhost 127.0.0.1 "*.local"

echo "Configuration complete!"
echo "Verify with: networksetup -getdnsservers $SERVICE_NAME"
```

Make it executable and run:

```bash
chmod +x configure-homelab.sh
./configure-homelab.sh 192.168.1.100 "Wi-Fi"
```

### Using launchd for Automatic Configuration

Create a LaunchAgent to ensure settings persist across reboots:

```bash
# Create launch agent
sudo tee /Library/LaunchDaemons/com.homelab.config.plist > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.homelab.config</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/configure-homelab.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the launch agent
sudo launchctl load /Library/LaunchDaemons/com.homelab.config.plist
```

---

**Last Updated**: 2025-01-21  
**Tested On**: macOS 11 (Big Sur), macOS 12 (Monterey), macOS 13 (Ventura), macOS 14 (Sonoma)
