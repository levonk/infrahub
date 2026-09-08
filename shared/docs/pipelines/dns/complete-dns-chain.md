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

## Network isolation policy

Each container in the DNS stack should only have network access to the
containers it needs to communicate with. This follows the desec-stack
pattern where services are "deliberately not on any other network" —
e.g., their unbound is only on the recursion network, their gatekeeper
is only on the api-gatekeeper network.

### Current isolation rules

| Container | Can talk to | Cannot talk to | Rationale |
|-----------|-------------|----------------|-----------|
| AdGuard | dnsdist only | All other DNS tiers | AdGuard is the entry point; it forwards to dnsdist and nothing else |
| dnsdist | CoreDNS (external port) only | All other DNS tiers, Tor proxy | dnsdist is a load balancer, not a resolver |
| CoreDNS (external) | Unbound validator only | All dnscrypt tiers, Tor proxy | External port handles cache + local zones, delegates to validator |
| CoreDNS (internal) | All dnscrypt/unbound tiers | AdGuard, dnsdist, client network | Internal port runs the fallback chain only |
| Unbound validator | CoreDNS (internal port) only | All dnscrypt tiers directly, Tor proxy | Validator forwards to CoreDNS internal, which does the tier fallback |
| dnscrypt tiers | External resolvers via their protocol | Other dnscrypt tiers, internal services | Each tier is independent; they don't chain to each other |
| Tor proxy | External Tor network only | Internal services, DNS tiers directly | Tor proxy is a SOCKS proxy for dnscrypt/unbound-tor tiers only |
| Unbound root | Root NS via recursion only | Internal services, other tiers | Direct recursion, no forwarding |

### Principles

1. **No tier-to-tier communication** — Each tier resolves independently.
   Tiers do not chain to each other; CoreDNS's `forward` plugin handles
   the ordered fallback.
2. **Tor proxy is egress-only** — The Tor SOCKS proxy accepts connections
   from dnscrypt-tor and unbound-tor tiers only. It should not be
   reachable from AdGuard, dnsdist, or CoreDNS.
3. **Validator is a middlebox** — Unbound validator sits between CoreDNS
   external and CoreDNS internal. It should not have direct access to
   any dnscrypt tier.
4. **Plaintext tiers have no special access** — Despite being "last resort",
   plaintext tiers have the same network access as encrypted tiers. The
   difference is the protocol, not the network policy.

### Lesson from desec-stack

desec-stack's compose file documents network isolation with inline
comments explaining *why* a service is deliberately excluded from a
network. For example:

> "Recursion needs egress to port 53, which this bridge network's NAT
> provides. The resolver is deliberately not on any other network."

> "The arbiter is deliberately not on any other network: it answers api's
> questions, and has no business talking to the rest of the stack."

Our Docker Compose and Ansible `community.docker` network definitions
should include similar comments documenting the isolation rationale.

## Upstream provider landscape (2026-09)

The resolution chain ends with **Unbound Root (Tier 10)** — direct
recursive resolution to ICANN root servers, no third party — and
**Plaintext (Tier 12)** as last resort. Third-party resolvers
(Cloudflare, Quad9) are **bootstrap-only**: they resolve DoH/DoT/ODoH
endpoint hostnames before encrypted DNS is available. They do NOT
appear in the CoreDNS forward chain.

Provider availability changes:

- **Mullvad DoH**: Shut down November 2nd, 2026. Mullvad now sponsors
  Quad9 instead. See `requirements/upstream-provider-deprecation.md`.
  No impact on our stack — no configs reference Mullvad DNS.
- **Quad9**: Gaining institutional support (Mullvad sponsorship).
  Referenced as `doh-quad9-nl` in dnscrypt-proxy-tor and as bootstrap
  DNS in AdGuard and Windows deployment. Not in the resolution chain.
- **Cloudflare**: Still operational for DoH/ODoH. Used as bootstrap DNS
  and as an ODoH target via the dnscrypt-proxy auto-selection lists.
- **ICANN Root NS**: The terminal resolver for Tier 10. Always available
  as long as the internet's root DNS infrastructure is operational.

The dnscrypt-proxy configs auto-select from the DNSCrypt public resolver
lists, so individual provider shutdowns are handled gracefully as long
as the list is refreshed. The `refresh_delay = 72` (hours) in the
source configs ensures stale providers are dropped within 3 days.

## Related files

- `requirements/dns/dnssec-gap-and-unbound-fix.md` — DNSSEC validation gap analysis and Unbound validating cache proposal
- `requirements/dns/cross-cluster-dns-failover.md` — cross-cluster DNS failover options (direct Tailscale IP fallback recommended)
- `requirements/dns/coredns-vs-unbound.md` — original CoreDNS vs Unbound analysis (diagram now corrects the false DNSSEC claim documented here)
- `requirements/dns-testing-strategy.md` — e2e test strategy for the 12-tier chain (pytest + Docker compose overlay)
- `requirements/upstream-provider-deprecation.md` — upstream DNS provider changes (Mullvad DoH shutdown, Quad9 sponsorship)
