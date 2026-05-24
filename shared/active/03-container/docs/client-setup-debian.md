# 🐧 Debian Linux Client Setup Guide

Complete guide to configure a Debian Linux machine to use Home Lab In-a-Box services.

## Prerequisites

- Debian 11 (Bullseye) or newer
- Network access to the Home Lab host
- sudo/root privileges
- Basic command-line familiarity

## Environment Variables

Throughout this guide, replace these values:

```bash
# Set your Home Lab host IP address
export HOMELAB_HOST="192.168.1.100"
```

---

## 🌐 Part 1: Base Network Services

### DNS Configuration

#### Option A: System-Wide DNS (Recommended)

**Using systemd-resolved (Debian 11+)**:

```bash
# 1. Backup current configuration
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup

# 2. Configure systemd-resolved
sudo tee /etc/systemd/resolved.conf.d/homelab.conf > /dev/null <<EOF
[Resolve]
DNS=${HOMELAB_HOST}
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=no
DNSSEC=allow-downgrade
EOF

# 3. Remove existing /etc/resolv.conf symlink
sudo rm /etc/resolv.conf

# 4. Create new symlink
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# 5. Restart systemd-resolved
sudo systemctl restart systemd-resolved

# 6. Verify configuration
resolvectl status
```

**Using /etc/resolv.conf (Legacy/Simple)**:

```bash
# 1. Backup current configuration
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# 2. Update DNS configuration
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver ${HOMELAB_HOST}
nameserver 1.1.1.1
options edns0 trust-ad
EOF

# 3. Make immutable (prevent DHCP from overwriting)
sudo chattr +i /etc/resolv.conf

# 4. Test DNS resolution
dig @${HOMELAB_HOST} google.com
nslookup google.com
```

**To revert immutable /etc/resolv.conf**:

```bash
sudo chattr -i /etc/resolv.conf
```

#### Option B: Per-Application DNS

For applications that support custom DNS:

```bash
# Firefox
# about:config -> network.trr.mode = 2
# network.trr.uri = https://${HOMELAB_HOST}/dns-query

# Chrome/Chromium
# Settings -> Privacy and security -> Security -> 
# Advanced -> Use secure DNS -> Custom: https://${HOMELAB_HOST}/dns-query

# curl with custom DNS
curl --dns-servers ${HOMELAB_HOST} https://example.com
```

---

### NTP Configuration

**Using systemd-timesyncd (Default)**:

```bash
# 1. Stop and disable other NTP services
sudo systemctl stop ntp || true
sudo systemctl disable ntp || true

# 2. Configure systemd-timesyncd
sudo tee /etc/systemd/timesyncd.conf > /dev/null <<EOF
[Time]
NTP=${HOMELAB_HOST}
FallbackNTP=time.google.com time.cloudflare.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF

# 3. Restart timesyncd
sudo systemctl restart systemd-timesyncd
sudo systemctl enable systemd-timesyncd

# 4. Verify synchronization
timedatectl status
systemctl status systemd-timesyncd

# 5. Show detailed status
timedatectl timesync-status
```

**Using chrony (Alternative)**:

```bash
# 1. Install chrony
sudo apt update
sudo apt install -y chrony

# 2. Configure chrony
sudo tee /etc/chrony/chrony.conf > /dev/null <<EOF
# Home Lab NTP server
server ${HOMELAB_HOST} iburst prefer
server time.google.com iburst
server time.cloudflare.com iburst

# Allow stepping on startup
makestep 1.0 3

# Enable kernel synchronization
rtcsync

# Log directory
logdir /var/log/chrony
EOF

# 3. Restart chrony
sudo systemctl restart chrony
sudo systemctl enable chrony

# 4. Verify synchronization
chronyc tracking
chronyc sources -v
```

---

### Web Proxy Configuration

#### Option A: System-Wide Proxy

**Using environment variables**:

```bash
# 1. Create proxy configuration
sudo tee /etc/profile.d/localnet-proxy.sh > /dev/null <<'EOF'
# Home Lab Proxy Configuration
export HOMELAB_PROXY="192.168.1.100:3128"
export http_proxy="http://${HOMELAB_PROXY}"
export https_proxy="http://${HOMELAB_PROXY}"
export ftp_proxy="http://${HOMELAB_PROXY}"
export no_proxy="localhost,127.0.0.1,::1,.local"
export HTTP_PROXY="${http_proxy}"
export HTTPS_PROXY="${https_proxy}"
export FTP_PROXY="${ftp_proxy}"
export NO_PROXY="${no_proxy}"
EOF

# 2. Make executable
sudo chmod +x /etc/profile.d/localnet-proxy.sh

# 3. Apply to current session
source /etc/profile.d/localnet-proxy.sh

# 4. Configure APT to use proxy
sudo tee /etc/apt/apt.conf.d/95localnet-proxy > /dev/null <<EOF
Acquire::http::Proxy "http://${HOMELAB_HOST}:3128";
Acquire::https::Proxy "http://${HOMELAB_HOST}:3128";
EOF

# 5. Test proxy
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

**Wget**:

```bash
# Create/update ~/.wgetrc
cat >> ~/.wgetrc <<EOF
http_proxy = http://${HOMELAB_HOST}:3128
https_proxy = http://${HOMELAB_HOST}:3128
use_proxy = on
EOF
```

**cURL**:

```bash
# Create/update ~/.curlrc
cat >> ~/.curlrc <<EOF
proxy = http://${HOMELAB_HOST}:3128
EOF
```

**Docker**:

```bash
# 1. Create Docker daemon config directory
sudo mkdir -p /etc/systemd/system/docker.service.d

# 2. Configure HTTP proxy
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOF
[Service]
Environment="HTTP_PROXY=http://${HOMELAB_HOST}:3128"
Environment="HTTPS_PROXY=http://${HOMELAB_HOST}:3128"
Environment="NO_PROXY=localhost,127.0.0.1,docker-registry.local"
EOF

# 3. Reload and restart Docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# 4. Verify
sudo systemctl show --property=Environment docker
```

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
npm config delete registry
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
# 1. Configure Docker to use insecure registry (HTTP)
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["${HOMELAB_HOST}:8082"],
  "registry-mirrors": ["http://${HOMELAB_HOST}:8082"]
}
EOF

# 2. Restart Docker
sudo systemctl restart docker

# 3. Test pull through cache
docker pull ${HOMELAB_HOST}:8082/library/alpine:latest

# 4. Tag and push to private registry
docker tag alpine:latest ${HOMELAB_HOST}:8082/alpine:latest
docker push ${HOMELAB_HOST}:8082/alpine:latest
```

---

### Python/PyPI Configuration (Nexus)

```bash
# 1. Create pip configuration directory
mkdir -p ~/.config/pip

# 2. Configure pip
cat > ~/.config/pip/pip.conf <<EOF
[global]
index-url = http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
trusted-host = ${HOMELAB_HOST}
EOF

# 3. Test by installing a package
pip install requests

# 4. (Optional) Per-project configuration
# Create pip.conf in project root or use requirements.txt:
# --index-url http://${HOMELAB_HOST}:8081/repository/pypi-public/simple
# --trusted-host ${HOMELAB_HOST}
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
cat /etc/resolv.conf
resolvectl status
```

### Test NTP

```bash
# Check synchronization status
timedatectl status

# Show current time sources
timedatectl timesync-status

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

# Check systemd-resolved status
systemctl status systemd-resolved
resolvectl statistics
```

### NTP Issues

```bash
# Check if NTP port is reachable
nc -zvu ${HOMELAB_HOST} 123

# Check timesyncd logs
journalctl -u systemd-timesyncd -f

# Manual time sync
sudo timedatectl set-ntp false
sudo timedatectl set-ntp true
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
```

---

## 🔄 Reverting Configuration

### Revert DNS

```bash
# systemd-resolved
sudo rm /etc/systemd/resolved.conf.d/homelab.conf
sudo systemctl restart systemd-resolved

# /etc/resolv.conf
sudo chattr -i /etc/resolv.conf
sudo cp /etc/resolv.conf.backup /etc/resolv.conf
```

### Revert NTP

```bash
# systemd-timesyncd
sudo systemctl stop systemd-timesyncd
sudo rm /etc/systemd/timesyncd.conf
sudo systemctl start systemd-timesyncd

# chrony
sudo systemctl stop chrony
sudo systemctl disable chrony
```

### Revert Proxy

```bash
# Remove system-wide proxy
sudo rm /etc/profile.d/localnet-proxy.sh
sudo rm /etc/apt/apt.conf.d/95localnet-proxy

# Unset environment variables
unset http_proxy https_proxy ftp_proxy no_proxy
unset HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY

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

**Last Updated**: 2025-01-21  
**Tested On**: Debian 11 (Bullseye), Debian 12 (Bookworm)
