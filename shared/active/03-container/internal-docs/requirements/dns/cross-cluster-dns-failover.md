# Cross-Cluster DNS Failover

**Date:** 2026-08-09
**Status:** Proposed — not yet deployed
**Related:** `diagrams/dns/complete-dns-chain.mmd`, `dnssec-gap-and-unbound-fix.md`

## The Problem

The DNS stack runs on two clusters:

| Cluster | Location | Hosts | keepalived | Access |
|---------|----------|-------|------------|--------|
| **Local** | nl.levonk.com (LAN) | Windows host + Raspberry Pi | Yes — VIP floats between them | LAN clients use VIP |
| **Cloud** | cno.levonk.com (OCI) | OCI machine (single host) | No — single host | Tailscale clients use OCI Tailscale IP |

If the **cloud cluster's DNS stack fails**, Oracle nodes on OCI need a
fallback DNS resolver. They cannot use `dns.levonk.com` to find one —
**you can't use DNS to fix DNS.** The fallback must be configured as
hardcoded IP addresses.

## Constraint

**cno.levonk.com (OCI) must NOT have blanket access to the nl.levonk.com LAN.**
nl.levonk.com advertises specific services to cno.levonk.com — it does not
expose the entire LAN subnet. This rules out full Tailscale subnet routing
(`--advertise-routes=192.168.x.0/24`).

## Options

### Option 1: Direct Tailscale IP fallback (recommended)

Oracle nodes are configured with the Tailscale IPs of the local cluster's
DNS containers as fallback DNS servers, using literal IP addresses in
`/etc/resolv.conf` or systemd-resolved.

```
# Oracle node /etc/resolv.conf
nameserver 100.x.x.50    # OCI local DNS (primary)
nameserver 100.x.x.10    # Windows host DNS (fallback 1)
nameserver 100.x.x.11    # Raspberry Pi DNS (fallback 2)
```

**How it works:**
- OS resolver tries servers in order with a timeout (typically 1-5s)
- If OCI DNS is down, resolver falls back to Windows host Tailscale IP
- If Windows host is down, resolver falls back to Pi Tailscale IP
- No DNS lookup needed to find the fallback servers — they're literal IPs
- Only DNS port (53 or 5353) needs to be reachable via Tailscale

**What nl.levonk.com exposes to cno.levonk.com:**
- Nothing new. Tailscale already allows node-to-node connectivity.
- The Windows host and Pi must run the DNS stack and listen on their
  Tailscale IPs (or on all interfaces, with the DNS port reachable
  via Tailscale's node-to-node firewall).

**Pros:**
- No subnet routing — respects the no-blanket-LAN-access constraint
- No keepalived changes — uses existing Tailscale IPs
- Simple to configure (just resolv.conf entries)
- Works with existing Tailscale connectivity

**Cons:**
- Failover is not instant (OS resolver timeout, 1-5s)
- No transparent VIP — each node is a separate DNS server
- Both Windows host and Pi must run the DNS stack independently
- If Tailscale itself is down, no cross-cluster failover works
  (but if Tailscale is down, the clusters can't reach each other anyway)

### Option 2: Scoped /32 subnet routing (documented, not recommended)

Instead of advertising the entire LAN subnet, advertise only the DNS VIP
as a `/32` route:

```yaml
# In localnet.yml for the Windows host (or Pi):
vpn_tailscale_advertise_routes:
  - "192.168.x.100/32"  # DNS VIP only, not the whole LAN
```

Oracle nodes (with `accept_routes: true`, which they already have) can
then reach the LAN VIP. keepalived failover between Windows/Pi works
transparently — Oracle nodes just point to the VIP.

**What nl.levonk.com exposes to cno.levonk.com:**
- Only the DNS VIP IP — not the rest of the LAN
- More surgical than full subnet routing, but still a route into the LAN

**Pros:**
- Transparent VIP failover (Oracle nodes see one IP, keepalived handles the rest)
- Only one IP exposed, not the whole subnet

**Cons:**
- **keepalived VIP + /32 route conflict:** If keepalived moves the VIP from
  Windows to Pi, the Tailscale subnet route must also move. Tailscale
  subnet routes are per-node — only the node that advertises the route
  can serve it. Both Windows and Pi would need to advertise the same /32,
  and Tailscale would need to handle the failover. This is not how
  Tailscale subnet routing is designed to work — it expects stable
  route ownership, not floating IPs.
- Requires Tailscale admin approval of the /32 route
- Still exposes a route into the LAN (even if scoped to one IP)
- Complex to operationalize correctly

**Why not recommended:** The /32 + keepalived VIP interaction is fragile.
Tailscale subnet routing was designed for stable subnet ownership, not
for VRRP floating IPs. Option 1 (direct Tailscale IPs) is simpler and
more reliable for this use case.

### Option 3: Full subnet routing (rejected)

Advertising the entire LAN subnet (`192.168.x.0/24`) via Tailscale would
give Oracle nodes access to every device on the nl.levonk.com LAN.

**Rejected because:** violates the constraint that cno.levonk.com must not
have blanket access to nl.levonk.com outside of advertised services.

## Recommendation

**Option 1 (direct Tailscale IP fallback).** It respects the no-blanket-access
constraint, requires no subnet routing, and uses existing Tailscale
connectivity. The only requirement is that the Windows host and Pi run the
DNS stack and listen on their Tailscale IPs.

### Configuration steps (future — not part of this documentation change)

1. Ensure the DNS stack (AdGuard/dnsdist/CoreDNS) on the Windows host and Pi
   listens on the Tailscale interface (or on `0.0.0.0` with Tailscale
   firewall rules allowing DNS port from Oracle nodes)
2. Configure Oracle nodes' `/etc/resolv.conf` or systemd-resolved with:
   - Primary: OCI local DNS Tailscale IP
   - Fallback 1: Windows host Tailscale IP
   - Fallback 2: Pi Tailscale IP
3. Test: stop OCI DNS stack, verify Oracle nodes fall back to local cluster
4. Test: stop Windows host DNS, verify Oracle nodes fall back to Pi

## What this does NOT solve

- **Tailscale failure:** If Tailscale itself is down, the clusters can't
  reach each other. No cross-cluster failover is possible. Each cluster
  must be self-sufficient in this scenario.
- **Split-brain DNS:** If both clusters are up but can't reach each other,
  they serve independently. This is acceptable — DNS is eventually
  consistent and both clusters resolve the same external domains.
- **Config sync:** This doc covers failover only. Config synchronization
  (blocklists, local zones) between clusters is a separate problem
  addressed in the PRD (`prd-dns-server.md` FR-029).
