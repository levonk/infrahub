# Issue: DNS Services Fail After Network Recreation

**Status:** Resolved  
**Priority:** High  
**Date Reported:** 2025-01-21  
**Date Resolved:** 2025-01-21  
**Affected Services:** dnsdist, coredns, dnscrypt-proxy

## Summary

DNS services would fail intermittently after running `docker compose down && docker compose up` due to IP address conflicts between statically-assigned DNS services and DHCP-assigned application services.

## Symptoms

1. **Error Message:**
   ```
   Error response from daemon: failed to set up container networking: Address already in use
   ```

2. **DNS Resolution Failures:**
   - dnsdist logs: "Marking downstream coredns (172.20.X.X:53) as 'down'"
   - Queries timeout or return SERVFAIL
   - Validation script reports IP mismatches

3. **Inconsistent Behavior:**
   - Works fine on initial `docker compose up`
   - Fails after `docker compose down && docker compose up`
   - Different containers grab different IPs on each restart

## Root Cause

### Primary Issue: dnsdist 2.1 Limitation

dnsdist 2.1 parses its configuration file at startup and cannot resolve Docker hostnames. It requires static IP addresses to reference upstream servers (coredns and dnscrypt-proxy).

### Secondary Issue: DHCP Conflicts

Docker's DHCP assigns IPs sequentially from the bottom of the subnet:
1. Network: `172.20.0.0/16`
2. Gateway: `172.20.0.1`
3. DHCP starts at: `172.20.0.2` and increments

When containers start in different orders:
- Sometimes `tor` gets `172.20.0.5` before `dnscrypt-proxy` can claim it
- Sometimes `chronyd` gets `172.20.0.7` before `coredns` can claim it
- Static IP assignments conflict with DHCP assignments

### Tertiary Issue: Network Recreation

`docker compose down` completely destroys the network:
- All IP reservations lost
- Container start order becomes unpredictable
- Static IPs may be claimed by DHCP before DNS services start

## Failed Solutions

### Attempt 1: Use `priority` Field

**Approach:**
```yaml
dnscrypt-proxy:
  priority: 1  # Start first
coredns:
  priority: 2  # Start second
dnsdist:
  priority: 3  # Start last
```

**Result:** ❌ Failed
- Docker Compose schema validation rejected the `priority` field
- Error: `services.dnsdist additional properties 'priority' not allowed`

### Attempt 2: Low-Range Static IPs

**Approach:**
```yaml
dnscrypt-proxy:
  ipv4_address: 172.20.0.5
coredns:
  ipv4_address: 172.20.0.7
```

**Result:** ❌ Failed
- `tor` grabbed `172.20.0.5` before `dnscrypt-proxy`
- `chronyd` grabbed `172.20.0.7` before `coredns`
- Conflicts persisted after network recreation

### Attempt 3: Mid-Range Static IPs

**Approach:**
```yaml
dnscrypt-proxy:
  ipv4_address: 172.20.0.50
coredns:
  ipv4_address: 172.20.0.51
```

**Result:** ❌ Failed
- Still had occasional conflicts
- DHCP could still reach these IPs
- Not a permanent solution

## Solution: High IP Range Strategy

### Implementation

Reserve the **top of the IP range** for DNS infrastructure:

```yaml
# docker-compose.yml
dnscrypt-proxy:
  networks:
    homelab:
      ipv4_address: 172.20.255.50  # Top of range, reserved for DNS

coredns:
  networks:
    homelab:
      ipv4_address: 172.20.255.51  # Top of range, reserved for DNS
```

```lua
-- configs/dns/dnsdist.conf
newServer({address="172.20.255.51:53", name="coredns", ...})
newServer({address="172.20.255.50:5300", name="dnscrypt-proxy", ...})
```

### IP Allocation

```
Network: 172.20.0.0/16 (65,534 usable IPs)

172.20.0.1              - Gateway
172.20.0.2-254.254      - DHCP Range (all other services)
172.20.255.1-49         - Reserved (future DNS expansion)
172.20.255.50           - dnscrypt-proxy (static)
172.20.255.51           - coredns (static)
172.20.255.52-59        - Reserved (DNS services)
172.20.255.60-254       - Reserved (other static infrastructure)
```

### Why This Works

1. **No DHCP Conflicts**: Docker DHCP starts from `172.20.0.2` and works upward, never reaching `172.20.255.x`
2. **Predictable**: DNS services always get the same IPs
3. **Survives Restarts**: Works even after `docker compose down`
4. **Scalable**: Room for 10 DNS services + 195 other static services

## Validation

### Testing Performed

1. ✅ Fresh `docker compose up` - Success
2. ✅ `docker compose restart` - Success
3. ✅ `docker compose down && docker compose up` - Success (10 iterations)
4. ✅ Adding new services - Success
5. ✅ Removing and re-adding DNS services - Success

### Validation Script

Created `scripts/validate-dns-ips.sh` to verify configuration:

```bash
./scripts/validate-dns-ips.sh

# Output:
# ✅ All DNS IP addresses are correctly configured
```

Script checks:
- docker-compose.yml static IP assignments
- dnsdist.conf upstream server IPs
- Actual running container IPs
- Provides remediation steps if mismatches detected

## Files Modified

1. **docker-compose.yml**
   - Updated DNS service IP assignments to `172.20.255.x`
   - Added inline documentation

2. **configs/dns/dnsdist.conf**
   - Updated upstream server IPs to `172.20.255.x`
   - Added comments explaining strategy

3. **scripts/validate-dns-ips.sh**
   - Created validation script
   - Checks all three sources of truth
   - Provides actionable remediation steps

4. **docs/troubleshooting-dns.md**
   - Created comprehensive DNS troubleshooting guide
   - Documents IP allocation strategy
   - Explains root cause and solution

5. **docs/troubleshooting.md**
   - Added IP conflict section
   - References DNS-specific guide

6. **internal-docs/adr/adr-dns-high-ip-range.md**
   - Created Architecture Decision Record
   - Documents rationale and alternatives considered

## Lessons Learned

1. **Docker DHCP Behavior**: DHCP starts from the bottom of the range and works upward - use top of range for static IPs

2. **Static IP Placement Matters**: Low/mid-range static IPs will conflict with DHCP; high-range IPs won't

3. **Validation is Critical**: Automated validation catches configuration drift early

4. **Documentation is Essential**: Complex workarounds need comprehensive documentation

5. **Test Network Recreation**: Always test `docker compose down && up` cycles

## Prevention

To prevent similar issues in the future:

1. **Reserve IP Ranges**: Document reserved IP ranges clearly
2. **Use High Range**: Always use top of range for static infrastructure IPs
3. **Validate Configuration**: Run validation scripts after changes
4. **Document Decisions**: Create ADRs for non-obvious architectural choices
5. **Test Thoroughly**: Test network recreation scenarios

## Related Documentation

- [ADR: High IP Range for DNS](../adr/adr-dns-high-ip-range.md)
- [DNS Troubleshooting Guide](../../docs/troubleshooting-dns.md)
- [Validation Script](../../scripts/validate-dns-ips.sh)
- [General Troubleshooting](../../docs/troubleshooting.md)

## Resolution

**Status:** ✅ Resolved  
**Resolution Date:** 2025-01-21  
**Resolution:** Implemented high IP range strategy for DNS services  
**Verified By:** Multiple test cycles with network recreation

## Follow-Up

- [ ] Monitor for any edge cases over next 30 days
- [ ] Consider applying same strategy to other static infrastructure if needed
- [ ] Update architecture diagrams with IP allocation
- [ ] Add IP allocation to README.md
