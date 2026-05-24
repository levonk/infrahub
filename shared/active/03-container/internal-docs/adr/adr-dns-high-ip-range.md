# ADR: High IP Range for DNS Infrastructure

**Status:** Accepted  
**Date:** 2025-01-21  
**Deciders:** Development Team  
**Related:** dnsdist 2.1 hostname resolution limitation

## Context

The homelab infrastructure uses a multi-layered DNS stack (dnsdist → CoreDNS → dnscrypt-proxy) running in Docker containers. We encountered a critical issue where DNS services would fail after network recreation due to IP address conflicts.

### Problem Statement

1. **dnsdist 2.1 Limitation**: dnsdist parses its configuration file at startup and cannot resolve Docker hostnames. It requires static IP addresses to reference upstream servers.

2. **DHCP Conflicts**: Docker's DHCP assigns IPs sequentially from the bottom of the subnet range (starting at `172.20.0.2`). When containers start in different orders, they may receive different IPs.

3. **Network Recreation**: Running `docker compose down` destroys the network completely, losing all IP reservations. On `docker compose up`, containers may start in unpredictable order.

4. **Initial Attempts Failed**:
   - **Attempt 1**: Used `priority` field in docker-compose.yml → Rejected by Docker Compose schema validation
   - **Attempt 2**: Used low-range static IPs (`172.20.0.5`, `172.20.0.7`) → Conflicts with other services (tor grabbed `172.20.0.5`)
   - **Attempt 3**: Used mid-range static IPs (`172.20.0.50`, `172.20.0.51`) → Still had occasional conflicts

### Network Configuration

- **Subnet**: `172.20.0.0/16` (65,534 usable IPs: `172.20.0.1` - `172.20.255.254`)
- **Gateway**: `172.20.0.1`
- **Services**: ~20 containers requiring IP addresses

## Decision

**We will reserve the top of the IP range (`172.20.255.x`) for DNS infrastructure with static IP assignments.**

### IP Allocation Strategy

```
Network: 172.20.0.0/16

┌─────────────────────────────────────────────┐
│ 172.20.0.1                                  │
│ Gateway (Docker)                            │
├─────────────────────────────────────────────┤
│ 172.20.0.2 - 172.20.254.254                 │
│ DHCP Range (Dynamic Assignment)             │
│ - Application services                      │
│ - Monitoring services                       │
│ - Proxy services                            │
│ - All other infrastructure                  │
├─────────────────────────────────────────────┤
│ 172.20.255.1 - 172.20.255.49                │
│ Reserved (Future DNS expansion)             │
├─────────────────────────────────────────────┤
│ 172.20.255.50 - dnscrypt-proxy (Static)     │
│ 172.20.255.51 - coredns (Static)            │
│ 172.20.255.52-59 - Reserved for DNS         │
├─────────────────────────────────────────────┤
│ 172.20.255.60 - 172.20.255.254              │
│ Reserved (Future static infrastructure)     │
└─────────────────────────────────────────────┘
```

### Specific Assignments

- **dnscrypt-proxy**: `172.20.255.50` (ODoH provider, foundation of DNS chain)
- **coredns**: `172.20.255.51` (DNSSEC validation and caching)
- **dnsdist**: No static IP needed (references upstreams by their static IPs)

### Configuration Changes

**docker-compose.yml:**
```yaml
coredns:
  networks:
    homelab:
      ipv4_address: 172.20.255.51  # Static IP in high range, reserved for DNS

dnscrypt-proxy:
  networks:
    homelab:
      ipv4_address: 172.20.255.50  # Static IP in high range, reserved for DNS
```

**configs/dns/dnsdist.conf:**
```lua
-- IPs in high range (172.20.255.x) reserved for DNS, DHCP assigns from 172.20.0.2 upward
newServer({address="172.20.255.51:53", name="coredns", ...})
newServer({address="172.20.255.50:5300", name="dnscrypt-proxy", ...})
```

## Rationale

### Why High IP Range?

1. **No DHCP Conflicts**: Docker's DHCP starts from the bottom (`172.20.0.2`) and works upward. DNS services at the top (`172.20.255.x`) will never conflict with DHCP assignments.

2. **Predictable and Stable**: DNS services always get the same IPs, regardless of:
   - Container start order
   - Network recreation (`docker compose down`)
   - Addition of new services

3. **Clear Separation**: Easy to identify DNS infrastructure vs. application services by IP address.

4. **Scalable**: Room for expansion:
   - `172.20.255.50-59`: DNS services (10 IPs)
   - `172.20.255.60-254`: Other static infrastructure (195 IPs)

5. **Self-Documenting**: High IP range immediately signals "reserved infrastructure" to anyone inspecting the network.

### Why Not Other Solutions?

**Priority Field:**
- ❌ Rejected by Docker Compose schema validation
- ❌ Not widely supported across Docker Compose versions
- ❌ Doesn't guarantee IP stability

**depends_on:**
- ❌ Only controls start order, not IP assignment
- ❌ Doesn't prevent DHCP conflicts

**Low/Mid Range Static IPs:**
- ❌ Conflicts with DHCP-assigned IPs
- ❌ Unpredictable which service gets which IP first
- ❌ Breaks after network recreation

**Custom IPAM Driver:**
- ❌ Overly complex for the problem
- ❌ Harder to maintain
- ❌ Portability issues

## Consequences

### Positive

1. ✅ **Zero IP Conflicts**: Tested with multiple `docker compose down && up` cycles - no conflicts
2. ✅ **Survives Network Recreation**: Works reliably even after full network teardown
3. ✅ **Simple and Maintainable**: Easy to understand and document
4. ✅ **No Special Tools**: Uses standard Docker Compose features
5. ✅ **Scalable**: Can add more DNS services without conflicts
6. ✅ **Self-Validating**: Created `validate-dns-ips.sh` script to verify configuration

### Negative

1. ⚠️ **Manual IP Management**: Must manually assign IPs for DNS services
2. ⚠️ **Documentation Burden**: Must document the IP allocation strategy
3. ⚠️ **Coordination Required**: Team must know not to use `172.20.255.x` range

### Neutral

1. 📝 **Requires Validation Script**: Created `scripts/validate-dns-ips.sh` to catch misconfigurations
2. 📝 **Documentation Updates**: Updated docker-compose.yml, dnsdist.conf, and troubleshooting guides

## Implementation

### Files Modified

1. **docker-compose.yml**
   - Updated `coredns.networks.homelab.ipv4_address` to `172.20.255.51`
   - Updated `dnscrypt-proxy.networks.homelab.ipv4_address` to `172.20.255.50`
   - Added inline comments explaining the strategy

2. **configs/dns/dnsdist.conf**
   - Updated `newServer()` calls to use `172.20.255.51` and `172.20.255.50`
   - Added comments explaining high IP range strategy

3. **scripts/validate-dns-ips.sh**
   - Created validation script to verify IP configuration
   - Checks docker-compose.yml, dnsdist.conf, and running containers
   - Provides remediation steps if mismatches detected

4. **docs/troubleshooting-dns.md**
   - Created comprehensive DNS troubleshooting guide
   - Documents IP allocation strategy
   - Explains why high IP range is used

### Validation

```bash
# Verify configuration
./scripts/validate-dns-ips.sh

# Expected output:
# ✅ All DNS IP addresses are correctly configured
```

### Testing

Tested scenarios:
1. ✅ Fresh `docker compose up`
2. ✅ `docker compose restart`
3. ✅ `docker compose down && docker compose up` (full recreation)
4. ✅ Adding new services to the stack
5. ✅ Removing and re-adding DNS services

All scenarios resulted in correct IP assignments with zero conflicts.

## Alternatives Considered

### 1. Use Hostnames (Rejected)

**Approach**: Keep using hostnames in dnsdist.conf, wait for dnsdist to support runtime resolution.

**Pros:**
- No static IPs needed
- More flexible

**Cons:**
- ❌ dnsdist 2.1 doesn't support this
- ❌ No timeline for when/if this will be fixed
- ❌ Blocks current implementation

**Decision**: Rejected - not viable with current dnsdist version

### 2. Custom DNS Resolution (Rejected)

**Approach**: Run a separate DNS resolver for dnsdist to use during startup.

**Pros:**
- Could resolve hostnames

**Cons:**
- ❌ Chicken-and-egg problem (DNS needs DNS)
- ❌ Overly complex
- ❌ Fragile and hard to maintain

**Decision**: Rejected - too complex for the benefit

### 3. Static IPs for All Services (Rejected)

**Approach**: Assign static IPs to every service in the stack.

**Pros:**
- Predictable IP assignments
- No DHCP conflicts

**Cons:**
- ❌ High maintenance burden (20+ services)
- ❌ Inflexible when adding/removing services
- ❌ Unnecessary for services that don't need static IPs

**Decision**: Rejected - only DNS services need static IPs

### 4. Separate Docker Network for DNS (Rejected)

**Approach**: Create a dedicated network for DNS services.

**Pros:**
- Isolated DNS infrastructure
- No conflicts with other services

**Cons:**
- ❌ Complicates inter-service communication
- ❌ Requires routing between networks
- ❌ Harder to troubleshoot

**Decision**: Rejected - unnecessary complexity

## Follow-Up Actions

- [X] Update docker-compose.yml with high IP range
- [X] Update dnsdist.conf with new IPs
- [X] Create validation script
- [X] Create DNS troubleshooting guide
- [X] Create this ADR
- [ ] Update general troubleshooting.md with IP conflict section
- [ ] Update README.md to mention IP allocation strategy
- [ ] Add IP allocation diagram to architecture.md

## References

- [dnsdist Documentation](https://dnsdist.org/reference/config.html)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Issue: DNS Services Fail After Network Recreation](../issues/dns-ip-conflicts.md)
- [Troubleshooting Guide: DNS](../../docs/troubleshooting-dns.md)
- [Validation Script](../../scripts/validate-dns-ips.sh)

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2025-01-21 | Development Team | Initial ADR created |
| 2025-01-21 | Development Team | Implemented and validated solution |
