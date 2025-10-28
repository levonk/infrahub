# Architecture Decision: Container-Only Transparent Proxying

## Problem Statement

Original design assumed bare-metal Linux with host network control (nftables, sysctl). This doesn't work for:
- Windows 11 + Docker Desktop + WSL2
- Containerized environments
- Scenarios where host network modification is not desired/possible

## User Requirements

1. **Transparent proxying for other containers** (not host traffic)
2. **Explicit configuration for external access** (host, internet)
3. **No host network modifications**
4. **Works in Docker Desktop/WSL2 environment**

## Solution: Docker-Native Transparent Proxy

### Architecture Options

#### Option 1: Sidecar Proxy Pattern (Recommended)
```
App Container → Sidecar Proxy → DNS/NTP/Web Services
```
- Each app container gets a sidecar proxy container
- Sidecar intercepts traffic via iptables within its own network namespace
- No host modifications needed

#### Option 2: Gateway Container Pattern
```
App Containers → Gateway Container → DNS/NTP/Web Services
                 (with iptables)
```
- Single gateway container with NET_ADMIN capability
- All app containers route through gateway
- Gateway performs transparent interception

#### Option 3: Docker Network Plugin
```
Custom Docker Network → Intercepts DNS/HTTP → Services
```
- Most complex, requires custom network driver
- Not recommended for initial implementation

## Chosen Solution: Gateway Container Pattern

### Why Gateway Pattern?

✅ **Pros:**
- Single point of configuration
- Works in Docker Desktop/WSL2
- No host modifications
- Easy to enable/disable per container
- Centralized logging and monitoring

❌ **Cons:**
- Single point of failure (mitigated by restart policies)
- Requires NET_ADMIN capability (acceptable in controlled environment)

### Implementation Design

```yaml
services:
  # Transparent Proxy Gateway
  transparent-gateway:
    image: alpine:latest
    cap_add:
      - NET_ADMIN
    networks:
      - localnet
    # iptables rules for transparent interception
    
  # App containers that want transparent proxying
  app:
    networks:
      - localnet
    dns:
      - transparent-gateway  # Use gateway as DNS
    # No other configuration needed!
    
  # Services (DNS, NTP, Web Proxy)
  dnsdist:
    networks:
      - localnet
```

### Traffic Flow

1. **Container Traffic (Transparent)**:
   ```
   App Container → Gateway Container (iptables REDIRECT) → DNS/Proxy Services
   ```

2. **External Traffic (Explicit)**:
   ```
   Host/Internet → Direct Port → DNS/Proxy Services
   ```

3. **VPN Traffic**:
   ```
   VPN Client → WireGuard → Homelab Network → Services
   ```

## Migration Plan

1. **Remove** `setup-host.sh` and host nftables configuration
2. **Create** `transparent-gateway` container with iptables rules
3. **Update** docker-compose.yml with gateway pattern
4. **Document** how to add containers to transparent proxy network
5. **Test** in Docker Desktop/WSL2 environment

## Benefits

- ✅ Works on Windows + Docker Desktop + WSL2
- ✅ Works on macOS + Docker Desktop
- ✅ Works on Linux (bare metal or VM)
- ✅ No host modifications required
- ✅ Easy to opt-in per container
- ✅ Centralized management
- ✅ Better isolation

## Trade-offs

- Requires NET_ADMIN capability for gateway container
- Adds one extra hop for transparent traffic (negligible latency)
- Gateway container must be running for transparent proxying to work
