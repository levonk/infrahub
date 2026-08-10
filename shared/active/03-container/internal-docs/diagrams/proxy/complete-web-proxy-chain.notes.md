# Complete Web Proxy Chain — Diagram Notes

**File:** `complete-web-proxy-chain.mmd`
**Last updated:** 2026-08-10

## Design lineage

This diagram supersedes the original V2 design (`web-proxy-flow-v2.mmd` and
`04-web-proxy-flow.md`). It follows the same documentation quality bar as the
DNS chain (`diagrams/dns/complete-dns-chain.mmd` + `complete-dns-chain.notes.md`).

## Fixes from the V2 design

1. **Removed separate "PolicyEnforcer / ExtAuth Hub" layer** — The V2 diagram
   had an L2 "Identity Router / ExtAuth Hub" that mapped source IP to Policy ID.
   This added complexity without clear value for a home/small-business proxy.
   Policy selection is now done via entrypoint port (3127 vs 3128), which is
   simpler and requires no identity infrastructure. The ExtAuth concept may be
   revisited if per-user egress routing is needed in the future.

2. **Clarified MITM as L2, not L1** — The V2 diagram labeled MITM as "L1" but
   it's really the second layer (after entrypoint/policy selection). The
   entrypoints (ports 3127/3128) are L1 — they select the policy. MITM is L2
   — it decrypts HTTPS. This matches the DNS chain's layer numbering where
   the interception host is Layer 0 and the first service is Layer 1.

3. **Added Layer 0: nftables TPROXY** — The V2 design didn't document how
   transparent mode works. Like the DNS chain (which uses nftables to redirect
   port 53 to AdGuard), the web proxy chain uses nftables to redirect host
   port 80/443 to the MITM proxy for transparent interception.

4. **Added Tailscale trust boundary** — Internal traffic (Tailscale) bypasses
   the proxy chain entirely. WireGuard encrypts transport, so no MITM
   decryption is needed for internal services. Only external traffic (leaving
   Tailscale) enters the chain. This mirrors the DNS chain's Tailscale trust
   boundary.

5. **Reuses DNS chain's Tor proxy** — The V2 design implied a separate Tor
   instance for the web proxy. The revised design reuses the Tor SOCKS5 proxy
   at `172.26.255.70:9050` from the DNS chain. No need for a second Tor
   instance — both chains share the same Tor proxy for .onion routing.

6. **Added cross-cluster topology** — Both the local cluster (nl.<base> LAN,
   Windows host dtop202311) and cloud cluster (cno.<base> OCI) run the full
   web proxy chain independently. Unlike DNS, there is no cross-cluster
   failover for web proxy — the proxy is stateful (MITM sessions, cache state)
   and failover would break active connections. See
   `requirements/proxy/cross-cluster-web-proxy.md`.

7. **Marked WARP as DARK** — Cloudflare WARP egress is documented and
   config-ready but not deployed by default. Direct and Tor are the active
   egress backends.

8. **Added bypass paths** — Direct access to MITM (port 3129), Varnish
   (port 6081), and Gost (port 1080) for debugging, matching the V2 design's
   bypass flow.

9. **Added DNS integration** — All proxy services use the LocalNet DNS chain
   for DNS resolution, benefiting from the same filtering, caching, and
   security policies. This was mentioned in the V2 doc but not in the diagram.

10. **Added management plane** — Traefik provides TLS termination for
    dashboards (mitmweb, Varnish admin) and serves the MITM CA certificate
    for download. This was mentioned in the V2 doc but not in the diagram.

## IP Allocation

All IPs in the `172.26.255.x` range (same network as DNS chain —
`localnet-network` / `172.26.0.0/16`), all unique:

| IP | Component |
|----|-----------|
| `.49` | dnsdist (DNS chain) |
| `.50` | unbound-validator (DNS chain) |
| `.51` | coredns (DNS chain) |
| `.52`–`.68` | dnscrypt tiers (DNS chain) |
| `.70` | Tor SOCKS5 proxy (DNS chain — shared) |
| `.80` | MITM proxy (mitmweb) |
| `.81` | Privoxy (content filtering) |
| `.82` | Varnish (caching) |
| `.83` | Gost (egress multiplexer) |

## Port Allocation

| Port | Component | Purpose |
|------|-----------|---------|
| `3127` | MITM proxy | Transparent policy entrypoint (malware only) |
| `3128` | MITM proxy | Ad-blocking policy entrypoint (malware + ads) |
| `8081` | MITM proxy | mitmweb web UI (via Traefik) |
| `8118` | Privoxy | HTTP proxy (internal — not exposed to host) |
| `6081` | Varnish | HTTP cache (bypass access) |
| `1080` | Gost | SOCKS5 proxy (bypass access) |
| `80/443` | nftables → MITM | Transparent interception (host level) |

## Active vs Dark tiers

### Active (running containers)

| Layer | Component | Why active |
|-------|-----------|-----------|
| L2 | MITM Proxy (mitmproxy) | Required for HTTPS decryption |
| L3 | Privoxy | Content filtering — core feature |
| L4 | Varnish | Caching — performance + resilience |
| L5 | Gost | Egress multiplexer — routes to backends |
| L6 Direct | Virtual node | Default egress — highest performance |
| L6 Tor | Tor SOCKS5 (shared) | For .onion + anonymity |

### Dark (documented, config ready, not running by default)

| Layer | Component | Why dark |
|-------|-----------|---------|
| L6 WARP | Cloudflare WARP | Future — balanced performance + security |

## Chain flow summary

```
Client
  ↓ (explicit proxy: port 3127 or 3128)
  ↓ (transparent: nftables redirects 80/443)
MITM Proxy (decrypt HTTPS → plaintext HTTP)
  ↓
Privoxy (filter ads/trackers/malware based on policy)
  ↓
Varnish (cache lookup — serve stale if cached)
  ↓ (cache miss)
Gost (egress multiplexer — route to backend)
  ↓                    ↓                ↓
Direct              Tor              WARP (dark)
  ↓                    ↓                ↓
Internet            Internet         Internet
```

## Diagram conventions

This file follows the practices in the `documentation-diagram-practices`
knowledge bundle:

- **No `%%` comments at file start** — the VS Code Mermaid preview extension
  concatenates leading comment lines into `%%%%graph TD`, causing a parse
  error. Comments are kept in this companion `.notes.md` file instead.
- **`<br/>` for line breaks** inside quoted node labels (not `<br>` or `\n`).
- **`color:#1a1a1a` on every `style` directive** — all fills are
  pastel/light, so dark text is required for WCAG AA 4.5:1 contrast.
- **All node labels with special characters are quoted** (`["..."]`).

## Related files

- `requirements/proxy/mitm-ca-distribution.md` — MITM CA certificate
  generation, distribution, and trust strategy
- `requirements/proxy/caching-strategy.md` — Varnish vs Squid decision,
  stale-while-revalidate, stale-if-error VCL configuration
- `requirements/proxy/egress-routing.md` — Gost egress multiplexer
  configuration, chain definitions, protocol matchers
- `requirements/proxy/cross-cluster-web-proxy.md` — cross-cluster topology,
  why no failover for web proxy (unlike DNS)
- `diagrams/proxy/web-proxy-flow-v2.mmd` — original V2 design (superseded)
- `diagrams/04-web-proxy-flow.md` — original V2 design doc (superseded)
- `diagrams/dns/complete-dns-chain.mmd` — DNS chain (parallel architecture)
