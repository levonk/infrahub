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

  # Extended DNS Errors (RFC 8914) — without EDE, a SERVFAIL cannot be
  # told apart from a broken delegation. Critical for debugging which
  # tier in the fallback chain returned a bogus response.
  ede: yes

  # Threading — without so-reuseport, threads contend for one listening
  # socket. num-threads should match available cores.
  num-threads: 2
  so-reuseport: yes

  # IPv6 — disabled because the rear networks are IPv4-only. Enabling
  # would only buy a timeout per authoritative server that prefers it.
  do-ip6: no

  # Trust anchor — stored in its own directory because RFC 5011 updates
  # write a temporary file next to the anchor. The entrypoint runs
  # unbound-anchor to refresh it on each container start.
  auto-trust-anchor-file: "/var/lib/unbound/root.key"

forward-zone:
  name: "."
  forward-addr: 172.20.255.51@15354    # CoreDNS internal port (fallback chain)
```

### Trust anchor refresh

The root KSK trust anchor must be kept up to date for DNSSEC validation
to work. The Unbound container entrypoint handles this automatically:

1. If `root.key` is missing, run `unbound-anchor -a /var/lib/unbound/root.key`
2. If `unbound-anchor` fails (no network), fall back to the bundled KSK-2017 key
3. Ensure proper ownership (`unbound:unbound`) and permissions (`644`)

This follows the pattern used by desec-stack's `unbound/entrypoint.sh`,
which runs `unbound-anchor` on every container start with `|| true` (exit
code 1 means the anchor was updated, not an error; if the network is
unavailable, the built-in anchor is used instead).

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

## Reference implementations

### desec-stack (github.com/desec-io/desec-stack)

desec-stack is an authoritative DNS hosting platform, not a recursive
resolver like ours. However, its Unbound configuration demonstrates
several patterns we adopt:

| Setting | desec-stack | Our stack | Why we differ |
|---------|-------------|-----------|---------------|
| `ede: yes` | Yes | Yes | Same — needed to distinguish SERVFAIL causes |
| `so-reuseport: yes` | Yes (with `num-threads: ${NPROC}`) | Yes (with `num-threads: 2`) | We hardcode 2 for smaller hosts; desec-stack uses `nproc` |
| `do-ip6: no` | Yes (rear networks IPv4-only) | Yes | Same rationale |
| `serve-expired` | `no` | `yes` | desec-stack checks live delegation state (stale = wrong). We serve clients (stale > no answer). |
| `prefetch` | `no` | `yes` | Same reason — we optimize for client latency, they optimize for freshness |
| `auto-trust-anchor-file` | In its own writable directory | In `/var/lib/unbound/` | Both follow the RFC 5011 temp-file requirement |
| `unbound-anchor` in entrypoint | `unbound-anchor -a ... \|\| true` | With bundled KSK-2017 fallback | We add a fallback for airgapped starts |
| `control-enable: yes` | Yes (plain TCP, no certs on rear net) | No | We don't use `unbound-control` currently; could add for operational use |
| `hide-identity: yes` / `hide-version: yes` | Yes | Not set | Should add — prevents version fingerprinting |

**Key lesson from desec-stack**: The `serve-expired: no` + `prefetch: no`
choice is deliberate for their use case (delegation checking needs live
state, not cached state). Our use case (serving clients) is the opposite,
so `serve-expired: yes` + `prefetch: yes` is correct. The lesson is to
document *why* the choice was made, not just what the choice is.

### Mullvad DNS shutdown (2026-09-03)

Mullvad shut down their public encrypted DNS (DoH) servers on
**November 2nd, 2026**, sponsoring Quad9 instead. See
`requirements/upstream-provider-deprecation.md` for the full analysis.
This does not affect our dnscrypt-proxy configs (no Mullvad DNS server
references), but it does affect the upstream resolver landscape: Quad9
gains institutional support while Mullvad DoH exits the public DNS space.

## References

- [CoreDNS dnssec plugin](https://coredns.io/plugins/dnssec/) — "on-the-fly DNSSEC signing"
- [Unbound DNSSEC validation](https://unbound.docs.nlnetlabs.nl/en/latest/topics/dnssec.html)
- [RFC 4033](https://www.rfc-editor.org/rfc/rfc4033) — DNS Security Introduction
- [RFC 8914](https://www.rfc-editor.org/rfc/rfc8914) — Extended DNS Errors
- [desec-stack unbound config](https://github.com/desec-io/desec-stack/blob/main/unbound/conf/unbound.conf.var) — reference implementation
- [desec-stack unbound entrypoint](https://github.com/desec-io/desec-stack/blob/main/unbound/entrypoint.sh) — trust anchor refresh pattern
- [coredns-vs-unbound.md](coredns-vs-unbound.md) — original analysis (now corrected in diagrams)
