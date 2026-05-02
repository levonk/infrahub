# DNS Troubleshooting Guide

## Overview

This guide covers DNS-specific issues in the Home Lab In-a-Box infrastructure, with focus on the dnsdist → CoreDNS → dnscrypt-proxy chain.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Common Issues](#common-issues)
  - [DNS Resolution Failures](#dns-resolution-failures)
  - [IP Address Mismatches](#ip-address-mismatches)
  - [Network Recreation Problems](#network-recreation-problems)
  - [dnsdist Cannot Resolve Hostnames](#dnsdist-cannot-resolve-hostnames)
- [Validation Tools](#validation-tools)
- [Service Dependency Chain](#service-dependency-chain)
- [Recovery Procedures](#recovery-procedures)

---

## Quick Diagnostics

### Check DNS Service Status

```bash
# Check all DNS services
docker compose ps dnsdist coredns dnscrypt-proxy

# Check DNS service logs
docker compose logs --tail=50 dnsdist
docker compose logs --tail=50 coredns
docker compose logs --tail=50 dnscrypt-proxy
```

### Test DNS Resolution

```bash
# Test direct mode (port from .env, default 15353)
dig example.com @localhost -p 15353

# Test transparent mode (port 53)
dig example.com @localhost -p 53

# Test from inside a container
docker compose exec dnsdist dig example.com @127.0.0.1
```

### Validate IP Configuration

```bash
# Run the validation script
./scripts/validate-dns-ips.sh
```

---

## Common Issues

### DNS Resolution Failures

**Symptoms:**
- `dig` queries timeout or return SERVFAIL
- dnsdist logs show "No downstream servers defined"
- CoreDNS logs show connection errors

**Diagnosis:**

```bash
# Check if dnsdist can reach upstream servers
docker compose exec dnsdist dig example.com @172.20.255.51

# Check CoreDNS health
docker compose exec coredns curl -f http://localhost:8080/health

# Check dnscrypt-proxy status
docker compose logs dnscrypt-proxy | grep -i error
```

**Solution:**

1. Verify IP addresses match configuration:
   ```bash
   ./scripts/validate-dns-ips.sh
   ```

2. If IPs are mismatched, follow remediation steps from the script output

3. Restart DNS chain in correct order:
   ```bash
   docker compose restart dnscrypt-proxy coredns dnsdist
   ```

---

### IP Address Mismatches

**Symptoms:**
- dnsdist logs: "Marking downstream coredns (172.20.X.X:53) as 'down'"
- Validation script reports IP mismatches
- DNS resolution works initially but fails after network recreation

**Root Cause:**

dnsdist 2.1 parses its configuration file at startup and cannot resolve Docker hostnames. It requires static IP addresses to reference upstream servers. When the Docker network is recreated (via `docker compose down`), containers may receive different IPs from DHCP if they conflict with the reserved range.

**Why We Use High IP Range (172.20.255.x):**

The network subnet is `172.20.0.0/16` (65,534 usable IPs). We reserve the **top of the range** for DNS infrastructure:

- **DNS Services**: `172.20.255.50` - `172.20.255.59` (high range, reserved)
- **Other Services**: Docker DHCP assigns from `172.20.0.2` upward (low range)

This prevents IP conflicts because:
1. Docker's DHCP starts from the bottom of the range
2. DNS services claim IPs from the top of the range
3. They never overlap, even after network recreation

**Diagnosis:**

```bash
# Run validation script
./scripts/validate-dns-ips.sh

# Check actual container IPs
<<<<<<< HEAD
docker inspect localnet-coredns localnet-dnscrypt-proxy --format='{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
=======
docker inspect localnet-dns-coredns localnet-dns-dnscrypt-proxy --format='{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
>>>>>>> 002-claude-code-integration

# Check expected IPs in docker-compose.yml
grep -A 2 "ipv4_address" docker-compose.yml | grep -E "(coredns|dnscrypt-proxy)" -A 1

# Check expected IPs in dnsdist.conf
grep "address=" configs/dns/dnsdist.conf | grep -E "(coredns|dnscrypt-proxy)"
```

**Solution:**

If IPs don't match, the containers started in the wrong order or there's a configuration mismatch:

```bash
# Recreate DNS services to get correct IPs
docker compose down dnsdist coredns dnscrypt-proxy
docker compose up -d dnscrypt-proxy coredns dnsdist

# Verify
./scripts/validate-dns-ips.sh
```

---

### Network Recreation Problems

**Symptoms:**
- DNS works fine initially
- After `docker compose down && docker compose up`, DNS stops working
- IP addresses have changed

**Root Cause:**

When you run `docker compose down`:
1. The Docker network is completely destroyed
2. All IP reservations are lost
3. On `docker compose up`, containers may start in different order
4. DHCP may assign different IPs despite static IP configuration

However, with our **high IP range strategy**, this should not cause conflicts because:
- DNS services always get `172.20.255.x` (top of range)
- Other services get `172.20.0.x` (bottom of range)
- No overlap possible

**Prevention:**

✅ **Use these commands** (preserve network):
```bash
docker compose restart              # Restart all services
docker compose restart dnsdist      # Restart specific service
docker compose stop && docker compose start  # Stop and start
```

❌ **Avoid these commands** (destroy network):
```bash
docker compose down                 # Destroys network
docker compose down && docker compose up  # Full recreation
```

**Recovery:**

If you must use `docker compose down`:

1. After recreation, immediately validate:
   ```bash
   ./scripts/validate-dns-ips.sh
   ```

2. If validation fails (shouldn't happen with high IP range), recreate DNS services:
   ```bash
   docker compose down dnsdist coredns dnscrypt-proxy
   docker compose up -d dnscrypt-proxy coredns dnsdist
   ```

3. Verify again:
   ```bash
   ./scripts/validate-dns-ips.sh
   ```

---

### dnsdist Cannot Resolve Hostnames

**Symptoms:**
- dnsdist logs: "Error creating new server with address coredns:53: Unable to convert presentation address"
- dnsdist starts but has no upstream servers

**Root Cause:**

dnsdist 2.1 limitation: It parses the configuration file during startup and cannot resolve Docker hostnames at that time. Docker's DNS service is not yet available when dnsdist reads its config.

**Why We Use Static IPs:**

```yaml
# docker-compose.yml
coredns:
  networks:
    homelab:
      ipv4_address: 172.20.255.51  # Static IP in high range

dnscrypt-proxy:
  networks:
    homelab:
      ipv4_address: 172.20.255.50  # Static IP in high range
```

```lua
-- configs/dns/dnsdist.conf
newServer({address="172.20.255.51:53", name="coredns", ...})
newServer({address="172.20.255.50:5300", name="dnscrypt-proxy", ...})
```

**Why High IP Range (172.20.255.x):**

Using the top of the IP range ensures:
1. **No DHCP conflicts** - Docker DHCP starts from `172.20.0.2` upward
2. **Predictable IPs** - DNS services always get the same IPs
3. **Survives restarts** - Works even after `docker compose down`
4. **Scalable** - Room for more DNS infrastructure in `172.20.255.x` range

**Solution:**

This is by design. The static IP + high range configuration is the correct approach. If you see this error, it means:

1. Static IPs are not configured in docker-compose.yml, OR
2. The configuration file is using hostnames instead of IPs

Fix by ensuring both files use static IPs in the high range as documented.

---

## Validation Tools

### IP Validation Script

**Location:** `scripts/validate-dns-ips.sh`

**Purpose:** Validates that DNS container IP addresses match configuration across:
- `docker-compose.yml` (static IP assignments)
- `configs/dns/dnsdist.conf` (upstream server references)
- Running containers (actual assigned IPs)

**Usage:**
```bash
./scripts/validate-dns-ips.sh
```

**Exit Codes:**
- `0` - All IPs match, configuration is valid
- `1` - IP mismatches detected, remediation needed

**When to Run:**
- After `docker compose up` (especially after `docker compose down`)
- After network recreation
- When DNS services are not working correctly
- As part of startup validation in CI/CD

**Example Output (Success):**
```
=========================================
DNS IP Address Validation
=========================================

CoreDNS:
  Expected (docker-compose.yml): 172.20.255.51
  Expected (dnsdist.conf):       172.20.255.51
  Actual (running container):    172.20.255.51
  ✅ PASS: All IPs match

dnscrypt-proxy:
  Expected (docker-compose.yml): 172.20.255.50
  Expected (dnsdist.conf):       172.20.255.50
  Actual (running container):    172.20.255.50
  ✅ PASS: All IPs match

=========================================
✅ All DNS IP addresses are correctly configured
=========================================
```

**Example Output (Failure):**
```
=========================================
DNS IP Address Validation
=========================================

CoreDNS:
  Expected (docker-compose.yml): 172.20.255.51
  Expected (dnsdist.conf):       172.20.255.51
  Actual (running container):    172.20.0.7
  ❌ FAIL: IP mismatch with docker-compose.yml

=========================================
❌ IP address mismatches detected
=========================================

REMEDIATION OPTIONS:

Option 1: Recreate containers to match configuration
  docker compose down dnsdist coredns dnscrypt-proxy
  docker compose up -d dnscrypt-proxy coredns dnsdist
  # Then run this script again to verify

Option 2: Update docker-compose.yml to match actual IPs
  Edit: /path/to/docker-compose.yml
  Set coredns ipv4_address: 172.20.0.7

Option 3: Update dnsdist.conf to match actual IPs
  Edit: /path/to/dnsdist.conf
  Set coredns address: 172.20.0.7:53
  Then: docker compose restart dnsdist
```

### DNS Leak Test

**Location:** `tests/dns-leak-test.sh`

**Purpose:** Verifies that all DNS queries are routed through the local infrastructure and ODoH is enabled.

**Usage:**
```bash
./tests/dns-leak-test.sh
```

---

## Service Dependency Chain

### DNS Chain (Bottom to Top)

```
1. dnscrypt-proxy (172.20.255.50:5300)
   ↓ ODoH encrypted queries
2. coredns (172.20.255.51:53)
   ↓ DNSSEC validation + caching
3. dnsdist (port 53/15353)
   ↓ Load balancing + filtering
4. Client applications
```

### IP Address Architecture

```
Network: 172.20.0.0/16 (65,534 usable IPs)

┌─────────────────────────────────────────────┐
│ 172.20.0.1 - Gateway                        │
├─────────────────────────────────────────────┤
│ 172.20.0.2 - 172.20.254.254                 │
│ DHCP Range (Dynamic Assignment)             │
│ - tor, privoxy, squid, envoy                │
│ - prometheus, grafana, elasticsearch        │
│ - nexus, verdaccio                          │
│ - wireguard, transparent-gateway            │
│ - All other services                        │
├─────────────────────────────────────────────┤
│ 172.20.255.1 - 172.20.255.49                │
│ Reserved for future DNS infrastructure      │
├─────────────────────────────────────────────┤
│ 172.20.255.50 - dnscrypt-proxy (Static)     │
│ 172.20.255.51 - coredns (Static)            │
│ 172.20.255.52 - dnsdist (Future, if needed) │
│ 172.20.255.53-59 - Reserved for DNS         │
├─────────────────────────────────────────────┤
│ 172.20.255.60 - 172.20.255.254              │
│ Reserved for other static infrastructure    │
└─────────────────────────────────────────────┘
```

### Restart Order

When troubleshooting, always restart in dependency order:

```bash
# Restart entire DNS chain (bottom to top)
docker compose restart dnscrypt-proxy coredns dnsdist

# Or restart individually with delays
docker compose restart dnscrypt-proxy
sleep 5
docker compose restart coredns
sleep 5
docker compose restart dnsdist
```

---

## Recovery Procedures

### Full DNS Reset

```bash
# 1. Stop DNS services
docker compose down dnsdist coredns dnscrypt-proxy

# 2. Verify network is clean
docker network inspect localnet_localnet

# 3. Start in correct order
docker compose up -d dnscrypt-proxy
sleep 5
docker compose up -d coredns
sleep 5
docker compose up -d dnsdist

# 4. Validate
./scripts/validate-dns-ips.sh

# 5. Test resolution
dig example.com @localhost -p 15353
```

### Network Recreation

If you need to recreate the entire network:

```bash
# 1. Stop everything
docker compose down

# 2. Remove network (if needed)
docker network rm localnet_homelab 2>/dev/null || true

# 3. Start everything
docker compose up -d

# 4. Wait for DNS services to stabilize
sleep 10

# 5. Validate
./scripts/validate-dns-ips.sh
```

### Configuration Sync

If configs are out of sync:

```bash
# 1. Check what IPs are actually assigned
<<<<<<< HEAD
docker inspect localnet-coredns localnet-dnscrypt-proxy \
=======
docker inspect localnet-dns-coredns localnet-dns-dnscrypt-proxy \
>>>>>>> 002-claude-code-integration
  --format='{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# 2. Update docker-compose.yml if needed
# Edit: coredns.networks.homelab.ipv4_address
# Edit: dnscrypt-proxy.networks.homelab.ipv4_address

# 3. Update dnsdist.conf if needed
# Edit: newServer({address="172.20.255.51:53", ...})
# Edit: newServer({address="172.20.255.50:5300", ...})

# 4. Recreate services
docker compose down dnsdist coredns dnscrypt-proxy
docker compose up -d dnscrypt-proxy coredns dnsdist

# 5. Validate
./scripts/validate-dns-ips.sh
```

---

## Advanced Troubleshooting

### Check dnsdist Upstream Status

```bash
# Connect to dnsdist console
docker compose exec dnsdist dnsdist -c

# In dnsdist console:
> showServers()
> getServer(0):isUp()
> getServer(1):isUp()
```

### Monitor DNS Queries

```bash
# Watch dnsdist logs in real-time
docker compose logs -f dnsdist

# Watch CoreDNS logs
docker compose logs -f coredns

# Watch dnscrypt-proxy logs
docker compose logs -f dnscrypt-proxy
```

### Test Each Layer

```bash
# Test dnscrypt-proxy directly
docker compose exec dnscrypt-proxy nslookup example.com 127.0.0.1

# Test CoreDNS directly
docker compose exec coredns dig example.com @127.0.0.1 -p 53

# Test dnsdist directly
docker compose exec dnsdist dig example.com @127.0.0.1 -p 53
```

---

## See Also

- [Architecture Decision Record: High IP Range for DNS](../internal-docs/adr/adr-dns-high-ip-range.md)
- [General Troubleshooting Guide](troubleshooting.md)
- [Transparent Proxy Usage](transparent-proxy-usage.md)
- [Service Chains Documentation](service-chains.md)
