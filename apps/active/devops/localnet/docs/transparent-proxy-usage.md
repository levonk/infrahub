# Transparent Proxy Usage Guide

## Overview

This homelab uses a **container-based transparent proxy gateway** instead of host network modifications. This approach:

✅ Works on **Windows 11 + Docker Desktop + WSL2**  
✅ Works on **macOS + Docker Desktop**  
✅ Works on **Linux** (any distribution)  
✅ Requires **no host network modifications**  
✅ Allows **opt-in per container**

## Architecture

### Three-Tier Access Model

The homelab uses a **three-tier access model**:

```
┌─────────────────────────────────────────────────────────┐
│  Tier 1: Host (Windows 11 / WSL2)                       │
│  Access: EXPLICIT CONFIGURATION                         │
│  • Can access services via localhost ports              │
│  • Can access internet directly                         │
│  • Can bypass homelab services                          │
└────────────────────────┬────────────────────────────────┘
                         │ (explicit config)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Tier 2: Service Containers                             │
│  • DNS (dnsdist, CoreDNS, dnscrypt-proxy)               │
│  • Web Proxy (Envoy, Squid, Privoxy, Tor)              │
│  • NTP (chronyd with NTS)                               │
│  • Monitoring (Prometheus, Grafana, Jaeger)             │
│  • Artifacts (Nexus, Verdaccio)                         │
│  • VPN (WireGuard)                                      │
│                                                          │
│  Access: DIRECT to internet for upstream queries        │
└────────────────────────┬────────────────────────────────┘
                         │ (transparent gateway)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Tier 3: App Containers (Under Observation)             │
│  Access: TRANSPARENT (enforced)                         │
│  • MUST go through transparent gateway                  │
│  • CANNOT access internet directly                      │
│  • CANNOT bypass homelab services                       │
│                                                          │
│  All traffic: Logged, Filtered, Monitored               │
└─────────────────────────────────────────────────────────┘
```

### Traffic Flow

```
App Container (Tier 3)
    ↓ (automatic interception)
Transparent Gateway
    ↓ (iptables DNAT)
Service Containers (Tier 2)
    ↓ (upstream queries)
Internet

Host (Tier 1)
    ↓ (explicit config)
Service Containers (Tier 2)
    ↓ (upstream queries)
Internet
```

**Key Point:** Service containers (Tier 2) have **direct internet access** for upstream queries (DNS, NTP, packages). App containers (Tier 3) **cannot access internet** except through Tier 2 services.

## Two Access Modes

### 1. Transparent Mode (Automatic)

Containers that use the transparent gateway get automatic interception:

```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - homelab
    dns:
      - transparent-gateway  # Use gateway as DNS server
    # That's it! DNS, NTP, HTTP/HTTPS automatically intercepted
```

**What gets intercepted:**
- DNS queries (port 53) → dnsdist
- NTP requests (port 123) → chronyd  
- HTTP requests (port 80) → Squid proxy
- HTTPS requests (port 443) → Squid proxy

### 2. Direct Mode (Explicit)

External access (host, internet, VPN) uses explicit configuration:

```bash
# From Windows host
dig example.com @localhost -p 5353

# Configure browser proxy
HTTP Proxy: localhost:3128

# Access dashboards
http://localhost:3000  # Grafana
http://localhost:9090  # Prometheus
```

## Adding Containers to Transparent Proxy

### Example: Node.js Application

```yaml
services:
  my-nodejs-app:
    build: ./my-app
    networks:
      - homelab
    dns:
      - transparent-gateway
    environment:
      - NODE_ENV=production
    depends_on:
      - transparent-gateway
```

**Result:** All DNS, NTP, and HTTP/HTTPS traffic automatically routed through homelab services!

### Example: Python Application

```yaml
services:
  my-python-app:
    image: python:3.11-slim
    networks:
      - homelab
    dns:
      - transparent-gateway
    command: python app.py
    depends_on:
      - transparent-gateway
```

### Example: Database Container

```yaml
services:
  postgres:
    image: postgres:15
    networks:
      - homelab
    dns:
      - transparent-gateway  # Gets DNS resolution through homelab
    environment:
      - POSTGRES_PASSWORD=secret
    depends_on:
      - transparent-gateway
```

## Verification

### Check if Transparent Proxy is Working

```bash
# 1. Start your app container with transparent gateway DNS
docker compose up -d my-app

# 2. Check DNS resolution (should go through dnsdist)
docker compose exec my-app nslookup example.com

# 3. Check HTTP traffic (should go through Squid)
docker compose exec my-app curl -v http://example.com

# 4. View gateway logs
docker compose logs transparent-gateway

# 5. View dnsdist logs (should show queries from your app)
docker compose logs dnsdist
```

### Test from Windows Host (Direct Mode)

```powershell
# Test DNS (direct port)
nslookup example.com 127.0.0.1 -port=5353

# Test web proxy
curl -x http://localhost:3128 http://example.com

# Access Grafana
Start-Process "http://localhost:3000"
```

## Benefits of This Approach

### ✅ Cross-Platform Compatibility

- **Windows 11 + Docker Desktop**: Works perfectly in WSL2
- **macOS + Docker Desktop**: No issues
- **Linux**: Works on any distribution

### ✅ No Host Modifications

- No `nftables` or `iptables` on host
- No `sysctl` changes
- No kernel modules
- No admin/sudo required on host

### ✅ Opt-In Per Container

```yaml
# Container WITH transparent proxy
my-app:
  dns: [transparent-gateway]

# Container WITHOUT transparent proxy  
my-other-app:
  # No dns configuration - uses default
```

### ✅ Easy Debugging

```bash
# See what's being intercepted
docker compose logs transparent-gateway

# See DNS queries
docker compose logs dnsdist

# See web proxy traffic
docker compose logs squid
```

## Limitations

### What This Does NOT Do

❌ **Does not intercept host traffic**  
   - Your Windows/Mac/Linux host traffic is NOT intercepted
   - Use explicit configuration (proxy settings, DNS server)

❌ **Does not intercept containers not using the gateway**  
   - Only containers with `dns: [transparent-gateway]` are affected
   - Other containers use default Docker DNS

❌ **Does not work for containers on different networks**  
   - Containers must be on the `homelab` network
   - Use `networks: [homelab]` in your service definition

### Security Considerations

⚠️ **NET_ADMIN Capability**  
The transparent gateway requires `NET_ADMIN` capability to modify iptables. This is:
- ✅ Safe in controlled homelab environment
- ✅ Isolated to container network namespace
- ⚠️ Should not be used for untrusted containers

⚠️ **Single Point of Failure**  
If the transparent gateway container stops:
- Containers using it will lose DNS resolution
- Mitigation: `restart: unless-stopped` policy

## Troubleshooting

### Container Can't Resolve DNS

**Symptom:** `nslookup: can't resolve 'example.com'`

**Solution:**
```yaml
# Ensure container uses transparent gateway DNS
services:
  my-app:
    dns:
      - transparent-gateway  # Add this
```

### Transparent Proxy Not Intercepting

**Check 1:** Is gateway running?
```bash
docker compose ps transparent-gateway
```

**Check 2:** Are iptables rules loaded?
```bash
docker compose exec transparent-gateway iptables -t nat -L -n
```

**Check 3:** Is container on correct network?
```bash
docker compose exec my-app ip route
# Should show gateway IP
```

### Host Can't Access Services

**Remember:** Host uses **direct mode**, not transparent mode.

```bash
# Use explicit ports
curl http://localhost:3128  # Squid proxy
dig @localhost -p 5353 example.com  # DNS
```

## Migration from Host-Based Setup

If you previously had `setup-host.sh`:

1. **Remove** host nftables rules:
   ```bash
   sudo nft flush ruleset
   ```

2. **Remove** sysctl changes (optional):
   ```bash
   sudo sysctl -w net.ipv4.ip_forward=0
   ```

3. **Use** container-based gateway instead:
   ```bash
   docker compose up -d transparent-gateway
   ```

## Advanced: Custom Gateway Configuration

### Override DNS Server

```yaml
transparent-gateway:
  environment:
    - DNS_SERVER=custom-dns
    - DNS_PORT=53
```

### Override Web Proxy

```yaml
transparent-gateway:
  environment:
    - WEB_PROXY=custom-proxy
    - WEB_PROXY_PORT=8080
```

### Disable Specific Interception

Edit `configs/transparent-gateway/entrypoint.sh` and comment out unwanted rules:

```bash
# Disable HTTP interception
# iptables -t nat -A PREROUTING -p tcp --dport 80 ...
```

## Summary

| Feature | Host-Based (Old) | Container-Based (New) |
|---------|------------------|----------------------|
| **Windows Support** | ❌ No | ✅ Yes |
| **macOS Support** | ❌ No | ✅ Yes |
| **Linux Support** | ✅ Yes | ✅ Yes |
| **Host Modifications** | ⚠️ Required | ✅ None |
| **Opt-In Per Container** | ❌ No | ✅ Yes |
| **Docker Desktop** | ❌ Doesn't work | ✅ Works |
| **WSL2** | ⚠️ Complex | ✅ Simple |

**Recommendation:** Use container-based transparent gateway for all deployments.
