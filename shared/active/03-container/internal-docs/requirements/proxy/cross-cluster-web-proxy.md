# Cross-Cluster Web Proxy Topology

**Date:** 2026-08-10
**Status:** Proposed
**Related:** `diagrams/proxy/complete-web-proxy-chain.mmd`, `requirements/dns/cross-cluster-dns-failover.md`

## The Topology

The web proxy chain runs on two clusters, matching the DNS chain topology:

| Cluster | Location | Host | Chain | Clients |
|---------|----------|------|-------|---------|
| **Local** | nl.<base> (LAN) | dtop202311 (Windows) | Full chain | LAN clients |
| **Cloud** | cno.<base> (OCI) | oci-cloud-server | Full chain | Tailscale clients |

Both clusters run the complete chain independently:
- MITM proxy (HTTPS decryption)
- Privoxy (content filtering)
- Varnish (caching)
- Gost (egress multiplexer)
- Tor SOCKS5 (shared with DNS chain)

## Why No Cross-Cluster Failover (unlike DNS)

The DNS chain has cross-cluster failover via direct Tailscale IPs (see
`requirements/dns/cross-cluster-dns-failover.md`). The web proxy chain
does **not** have cross-cluster failover because:

1. **Stateful sessions**: MITM proxy maintains TLS sessions with clients.
   Failover would break active HTTPS connections, causing certificate
   errors and data corruption.

2. **Cache state**: Varnish maintains an in-memory and on-disk cache.
   Failover would lose the cache, causing a burst of upstream requests.

3. **CA certificate mismatch**: Each cluster has its own MITM CA. If a
   client fails over to the other cluster's proxy, the client's trust
   store won't have the other cluster's CA, causing TLS errors.

4. **Client configuration**: Clients are configured with a specific proxy
   address (explicit proxy mode). Changing the proxy address on failover
   requires client reconfiguration, which isn't automatic.

5. **Different trust domains**: The local cluster serves LAN clients
   (trusted), while the cloud cluster serves Tailscale clients (also
   trusted, but a different network). Mixing them would violate network
   isolation.

## What happens if a cluster's proxy fails?

| Failure | Impact | Recovery |
|---------|--------|----------|
| Local proxy fails | LAN clients lose web proxy | Fix local proxy — no failover to cloud |
| Cloud proxy fails | Tailscale clients lose web proxy | Fix cloud proxy — no failover to local |
| Both fail | All clients lose web proxy | Clients fall back to direct internet access (if configured) |

## Client Configuration

### LAN clients (local cluster)

```
Proxy: 192.168.x.x:3128 (ad-blocking) or 192.168.x.x:3127 (transparent)
CA: Local cluster MITM CA (downloaded from ca.nl.<base>)
```

### Tailscale clients (cloud cluster)

```
Proxy: 100.90.22.85:3128 (ad-blocking) or 100.90.22.85:3127 (transparent)
CA: Cloud cluster MITM CA (downloaded from ca.cno.<base>)
```

### Transparent mode (nftables)

For transparent mode, nftables on each host redirects port 80/443 to the
local MITM proxy. No client configuration needed (except CA trust).

## DNS Integration

Each cluster's web proxy chain uses its own DNS chain for resolution:
- Local cluster → local DNS chain (AdGuard/dnsdist/CoreDNS on dtop202311)
- Cloud cluster → cloud DNS chain (AdGuard/dnsdist/CoreDNS on OCI)

If the local DNS chain fails, the web proxy chain on that cluster will also
fail to resolve domains. The DNS chain has its own cross-cluster failover
(see `requirements/dns/cross-cluster-dns-failover.md`), but the web proxy
chain itself does not fail over.

## Future: Shared CA across clusters

If cross-cluster failover is ever needed, the first step would be to share
the MITM CA across both clusters. This could be done by:
1. Generating the CA once
2. Storing it in a shared vault
3. Deploying the same CA to both clusters' MITM proxies

This would eliminate the CA mismatch problem but not the stateful session
and cache state problems. Full failover would still require a shared cache
backend (e.g., Redis) and session synchronization, which is out of scope.
