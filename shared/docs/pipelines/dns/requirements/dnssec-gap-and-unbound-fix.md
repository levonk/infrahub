# DNSSEC Validation Gap & Unbound Fix

**Date:** 2026-08-09
**Status:** Proposed — not yet deployed
**Related:** `shared/docs/pipelines/dns/complete-dns-chain.mmd`, `shared/docs/pipelines/dns/requirements/coredns-vs-unbound.md`

## The Problem

The original DNS chain diagram and `coredns-vs-unbound.md` both imply that
CoreDNS provides DNSSEC validation via its `dnssec` plugin. **This is false.**

### What each tool actually does with DNSSEC

| Tool | DNSSEC support | What it really does |
|------|---------------|---------------------|
| **CoreDNS** | No validation | The `dnssec` plugin is for **authoritative signing** (on-the-fly zone signing), NOT recursive validation. [CoreDNS docs](https://coredns.io/plugins/dnssec/) confirm this. |
| **dnscrypt-proxy** | No validation | Forwards the DO (DNSSEC OK) bit to upstream. The **upstream provider** validates, not dnscrypt-proxy. You are trusting the upstream. |
| **AdGuard Home** | No validation | Sets the DO bit on outgoing queries (`enable_dnssec: true`), but does **not** validate responses. Passes through whatever the upstream returns. |
| **dnsdist** | No validation | Pure pass-through. No validation logic. |
| **Unbound** | **Full validation** | Validating recursive resolver. Validates DNSSEC locally using root trust anchors, NSEC/NSEC3, aggressive NSEC. Works in both recursive mode AND forwarding mode. |

### The gap in the current architecture

For the threat model "I don't trust upstream providers":

1. **Tiers using dnscrypt-proxy** (ODoH, Anon DNSCrypt, DoH, DoT, DNSCrypt, plaintext):
   DNSSEC validation is delegated to the upstream provider. If the upstream is
   compromised, lying, or doesn't validate, the client receives an unvalidated
   response. This contradicts the zero-trust-upstream requirement.

2. **Plaintext tiers** (Tier 11, 12): No encryption AND no DNSSEC validation.
   A response can be tampered with in transit, and nothing catches it.

3. **CoreDNS's `forward` plugin** does ordered fallback through tiers, but
   does not validate responses. It passes whatever the tier returns back to
   the client.

### Why Unbound is the right fix

Unbound is the only tool in the stack that performs **local DNSSEC validation**.
Other validating resolvers exist (BIND, Knot Resolver, PowerDNS Recursor), but
Unbound is the best fit because:

- Lightweight and container-friendly
- Validates DNSSEC in **both recursive mode and forwarding mode** — it validates
  responses from forward-zones, not just responses from root recursion
- Can sit as a validating cache layer between CoreDNS and the fallback tiers
- Already present in the architecture as Tier 3 (Unbound over Tor) and
  Tier 10 (Unbound to Root)

## Proposed Fix: Unbound Validating Cache Layer

Add a **Unbound validating cache** instance between CoreDNS and the fallback
chain. All responses from the fallback tiers pass through Unbound for local
DNSSEC validation before returning to the client.

### Architecture

```
Client → AdGuard → dnsdist → CoreDNS → Unbound (validating cache) → [fallback tiers]
                                      ↑                              ↓
                                      └── DNSSEC-validated response ──┘
```

**Flow:**
1. CoreDNS receives external query from dnsdist
2. CoreDNS forwards to Unbound validating cache
3. Unbound forwards to the fallback chain (via its own forward-zone config,
   or CoreDNS retains the `forward` plugin and Unbound forwards back through
   CoreDNS — see "Implementation options" below)
4. Response comes back from the fallback tier
5. **Unbound validates DNSSEC locally** on the response
6. Unbound caches the validated response
7. Validated response returns to CoreDNS → dnsdist → AdGuard → client

### Implementation options

**Option A: Unbound as forwarder to CoreDNS's fallback chain**

```
CoreDNS → Unbound → CoreDNS (fallback plugin) → tiers
```

- CoreDNS forwards external queries to Unbound
- Unbound forwards them back to CoreDNS on a different port
- CoreDNS's `forward` plugin does the ordered fallback through tiers
- Response comes back through CoreDNS → Unbound (validates DNSSEC) → CoreDNS → client

**Pros:** Preserves CoreDNS's `forward` plugin ordered fallback exactly as-is.
**Cons:** Extra hop (CoreDNS → Unbound → CoreDNS). Slightly more complex routing.

**Option B: Unbound replaces CoreDNS as the forwarding orchestrator**

```
CoreDNS → Unbound (forward-zones + validation) → tiers
```

- CoreDNS forwards external queries to Unbound
- Unbound has multiple `forward-zone` blocks, one per tier
- Unbound does the fallback and validates DNSSEC
- CoreDNS retains local zones and serve-stale cache only

**Pros:** Simpler — one fewer hop. Unbound handles both forwarding and validation.
**Cons:** Unbound's forward-zone fallback is not as explicitly ordered as CoreDNS's
`forward` plugin. Unbound tries forward-zones in config order, but the behavior
is less predictable than CoreDNS's `force_tcp` + `fail_timeout` + ordered list.

**Option C (recommended): Unbound as validating forwarder, CoreDNS retains orchestration**

```
dnsdist → CoreDNS (orchestrator + cache + local zones)
              ↓ external query
         Unbound (validating cache)
              ↓
         [fallback tiers via CoreDNS forward plugin on internal port]
```

- CoreDNS listens on two ports:
  - **External port** (from dnsdist): receives queries, checks local zones + cache
  - **Internal port** (from Unbound): runs the `forward` plugin fallback chain
- CoreDNS forwards external queries to Unbound
- Unbound forwards to CoreDNS's internal port
- CoreDNS's `forward` plugin does ordered fallback through tiers
- Response comes back to CoreDNS internal → Unbound (validates DNSSEC) → CoreDNS external → client

**Pros:** Preserves CoreDNS's ordered fallback. Unbound validates all responses.
**Cons:** CoreDNS needs two listener configurations (two Corefile blocks).

### Unbound configuration (key settings)

```yaml
# unbound.conf — validating cache layer
server:
  module-config: "validator iterator"  # Enable DNSSEC validation
  val-permissive-mode: no              # Strict validation (drop bogus responses)
  val-clean-additional: yes            # Remove bogus data from additional section
  cache-min-ttl: 60                    # Don't cache for less than 60s
  cache-max-ttl: 86400                 # Cache up to 24h
  serve-expired: yes                   # Serve stale cache on failure
  serve-expired-ttl: 86400             # Serve stale for up to 24h
  prefetch: yes                        # Prefetch popular domains before expiry
  qname-minimisation: yes              # QNAME minimization (privacy)
  edns-buffer-size: 1232               # Avoid IP fragmentation

forward-zone:
  name: "."
  forward-addr: 172.20.255.51@15354    # CoreDNS internal port (fallback chain)
```

### DNSSEC trust levels per tier (with Unbound fix)

With the Unbound validating cache in place, ALL tiers get local DNSSEC validation:

| Tier | Protocol | Upstream DNSSEC | Unbound re-validates | Net result |
|------|----------|----------------|---------------------|------------|
| 1 | ODoH | Upstream validates | Yes | **Validated locally** |
| 2 | Anon DNSCrypt | Upstream validates | Yes | **Validated locally** |
| 3 | Unbound over Tor | Validated natively | N/A (is Unbound) | **Validated natively** |
| 4 | DNSCrypt over Tor | Upstream validates | Yes | **Validated locally** |
| 5 | DoH over Tor | Upstream validates | Yes | **Validated locally** |
| 6 | DoT/TLS over Tor | Upstream validates | Yes | **Validated locally** |
| 7 | Standard DNSCrypt | Upstream validates | Yes | **Validated locally** |
| 8 | DoH | Upstream validates | Yes | **Validated locally** |
| 9 | DoT/TLS | Upstream validates | Yes | **Validated locally** |
| 10 | Unbound to Root | Validated natively | N/A (is Unbound) | **Validated natively** |
| 11 | Plaintext over Tor | No upstream validation | Yes (response only) | **Validated locally** |
| 12 | Plaintext | No upstream validation | Yes (response only) | **Validated locally** |

**Key insight:** Even plaintext tiers get DNSSEC validation on the response,
because Unbound validates the response regardless of how the upstream behaved.
This means a tampered plaintext response would be caught by Unbound's validator.

### What this does NOT fix

- **Plaintext tier query privacy:** The query itself is still visible on the
  wire (Tier 12) or on the Tor exit path (Tier 11). DNSSEC validates the
  *response*, it does not encrypt the *query*.
- **Bootstrap DNS:** The initial DNS resolution to find DoH/DoT server
  hostnames still needs a plaintext bootstrap resolver. This is a known
  limitation of all encrypted DNS protocols.
- **Trust anchor rollover:** Unbound's root trust anchors must be kept
  up to date. The `unbound-anchor` tool handles this automatically.

## Deployment plan (future — not part of this documentation change)

1. Add Unbound container to `services/dns/` with the validating cache config
2. Add `unbound-validator.yml` task to `roles/dns/tasks/`
3. Update CoreDNS Corefile to forward external queries to Unbound
4. Add Unbound to the `depends_on` chain in the compose file
5. Add infrastructure variables for Unbound IP/port to `infrastructure/ports.yml`
6. Test: `dig +dnssec example.com @<unbound-ip>` should return `ad` flag
7. Test: feed a deliberately bogus DNSSEC response, confirm Unbound drops it

## References

- [CoreDNS dnssec plugin](https://coredns.io/plugins/dnssec/) — "on-the-fly DNSSEC signing"
- [Unbound DNSSEC validation](https://unbound.docs.nlnetlabs.nl/en/latest/topics/dnssec.html)
- [RFC 4033](https://www.rfc-editor.org/rfc/rfc4033) — DNS Security Introduction
- [coredns-vs-unbound.md](coredns-vs-unbound.md) — original analysis (now corrected in diagrams)
