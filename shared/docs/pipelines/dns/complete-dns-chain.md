# Complete DNS Chain — Diagram Notes

**File:** `complete-dns-chain.mmd`
**Last updated:** 2026-08-09

## Fixes from original diagram

1. **Removed false "DNSSEC Validator" from CoreDNS** — CoreDNS's `dnssec` plugin is for authoritative *signing* (on-the-fly zone signing), NOT recursive *validation*. See `requirements/dns/dnssec-gap-and-unbound-fix.md` for the full analysis.

2. **Added Unbound as a validating cache layer** (Layer 3b) between CoreDNS and the fallback tiers. ALL responses from the fallback chain pass through Unbound for local DNSSEC validation before reaching the client. This fills the DNSSEC gap where fallback tiers that don't validate (e.g., plaintext) would otherwise return unvalidated responses.

3. **Fixed IP conflicts** — Tiers 5, 6, and 8 all shared `172.20.255.55:5053` in the original. Now each tier has a unique IP in the `172.20.255.52`–`.63` range. See IP allocation table below.

4. **Fixed Tier 6 label** — was "dnscrypt-proxy DoH" but should be "dnscrypt-proxy DoT/TLS" (it's the TLS-over-Tor tier, not DoH-over-Tor).

5. **Fixed broken `keepalived_unbound_tor` reference** — line 96 of the original referenced `keepalived_unbound_tor` but the node was defined as `keepalived_unbound` (line 40) with `unbound_tor` as the service node. The connection was broken.

6. **Added Tailscale trust boundary** — internal queries (Tailscale MagicDNS, local zones) bypass the fallback chain entirely. WireGuard encrypts the transport, so no encryption stack is needed for internal queries. Only external queries (leaving Tailscale) go through the full security chain.

7. **Added multi-host topology note** — keepalived VIP applies only within the local LAN cluster (Windows host + Raspberry Pi on `nl.<base>`). VRRP needs L2 multicast, which does not cross Tailscale. The cloud host (OCI on `cno.<base>`) is a standalone cluster. See `requirements/dns/cross-cluster-dns-failover.md`.

8. **Marked tiers as ACTIVE or DARK** — active tiers (1, 2, 3, 10) are running containers. Dark tiers (4–9, 11–12) are documented, config-ready, but not running by default. Dark tiers are greyed out in the diagram.

9. **Added DNSSEC trust level annotation per tier** — each tier's node label documents where DNSSEC validation happens (upstream, natively by Unbound, or not at all for plaintext tiers).

10. **Added cross-cluster failover subgraph** — shows the local cluster (nl.<base> LAN with keepalived VIP) and cloud cluster (cno.<base> OCI standalone), with the fallback path via direct Tailscale IPs (not hostname, since you can't use DNS to fix DNS). Documents the constraint that cno has no blanket LAN access — only DNS port exposed via Tailscale.

## IP Allocation

All IPs in the `172.20.255.x` range, all unique:

| IP | Component |
|----|-----------|
| `.49` | dnsdist |
| `.50` | unbound-validator (validating cache) |
| `.51` | coredns |
| `.52` | Tier 1 — ODoH |
| `.53` | Tier 2 — Anon DNSCrypt |
| `.54` | Tier 3 — Unbound/Tor |
| `.55` | Tier 4 — DNSCrypt/Tor |
| `.56` | Tier 5 — DoH/Tor |
| `.57` | Tier 6 — DoT/Tor |
| `.58` | Tier 7 — DNSCrypt |
| `.59` | Tier 8 — DoH |
| `.60` | Tier 9 — DoT/TLS |
| `.61` | Tier 10 — Unbound/Root |
| `.62` | Tier 11 — Plaintext/Tor |
| `.63` | Tier 12 — Plaintext |
| `.70` | Tor SOCKS proxy |

## Active vs Dark tiers

### Active (running containers)

| Tier | Protocol | Why active |
|------|----------|-----------|
| 1 | ODoH (dnscrypt-proxy) | Strongest privacy — splits query/answer paths |
| 2 | Anonymized DNSCrypt (dnscrypt-proxy) | Different protocol, good privacy |
| 3 | Unbound over Tor | Local DNSSEC validation + anonymous transport |
| 10 | Unbound to Root | Local DNSSEC validation, no middleman at all |

### Dark (documented, config ready, not running by default)

| Tier | Protocol | Why dark |
|------|----------|---------|
| 4 | DNSCrypt over Tor | Redundant with Tier 3 (both Tor-based) |
| 5 | DoH over Tor | Redundant with Tier 3 |
| 6 | DoT/TLS over Tor | Redundant with Tier 3 |
| 7 | Standard DNSCrypt | Less private than Tier 2 |
| 8 | DoH | Less private than Tier 1 |
| 9 | DoT/TLS | Less private than above |
| 11 | Plaintext over Tor | No encryption, only anonymity |
| 12 | Plaintext | Last resort — no encryption, no anonymity |

## Diagram conventions

This file follows the practices in the `documentation-diagram-practices` knowledge bundle (`skills-src/src/current/knowledge/documentation-diagram-practices/`):

- **No `%%` comments at file start** — the VS Code Mermaid preview extension concatenates leading comment lines into `%%%%graph TD`, causing a parse error. Comments are kept in this companion `.notes.md` file instead.
- **`<br/>` for line breaks** inside quoted node labels (not `<br>` or `\n`).
- **`color:#1a1a1a` on every `style` directive** — all fills are pastel/light, so dark text is required for WCAG AA 4.5:1 contrast.
- **All node labels with special characters are quoted** (`["..."]`).

## Related files

- `requirements/dns/dnssec-gap-and-unbound-fix.md` — DNSSEC validation gap analysis and Unbound validating cache proposal
- `requirements/dns/cross-cluster-dns-failover.md` — cross-cluster DNS failover options (direct Tailscale IP fallback recommended)
- `requirements/dns/coredns-vs-unbound.md` — original CoreDNS vs Unbound analysis (diagram now corrects the false DNSSEC claim documented here)
