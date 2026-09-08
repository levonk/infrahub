# Upstream DNS Provider Deprecation Tracker

**Date:** 2026-09-04
**Status:** Active — Mullvad DoH shutdown pending (November 2nd, 2026)
**Related:** `complete-dns-chain.md`, `dnssec-gap-and-unbound-fix.md`

## Purpose

Track upstream DNS provider changes that affect our fallback chain.
Each entry documents what changed, when, how it affects our stack, and
what action is needed.

## Active deprecations

### Mullvad Public DoH Servers — Shutting down November 2nd, 2026

**Source:** [Mullvad blog post (2026-09-03)](https://mullvad.net/en/blog/shutting-down-our-public-encrypted-dns-servers-and-sponsoring-quad9-instead)

**What changed:**
Mullvad is shutting down their public encrypted DNS (DoH) servers.
They operated these since 2022. Going forward, they financially sponsor
[Quad9](https://quad9.net/) instead of running their own infrastructure.

**Timeline:**
- **2026-09-03**: Announcement
- **2026-11-02**: Servers shut down

**Impact on our stack:**

| Component | Uses Mullvad DoH? | Action needed |
|-----------|-------------------|---------------|
| dnscrypt-proxy ODoH (Tier 1) | No — auto-selects from DNSCrypt resolver list | None — stale entries auto-dropped within 72h |
| dnscrypt-proxy Anon (Tier 2) | No — auto-selects from public-resolvers list | None |
| dnscrypt-proxy Tor (Tier 3) | No — uses `doh-crypto-sx`, `doh-securedns`, `doh-quad9-nl` | None |
| dnscrypt-proxy STD (Tier 7) | No — auto-selects | None |
| dnscrypt-proxy DoH (Tier 8) | No — auto-selects | None |
| dnscrypt-proxy Plaintext (Tier 12) | No — auto-selects | None |
| AdGuard bootstrap DNS | No — uses `1.1.1.1` (Cloudflare) and `9.9.9.9` (Quad9) | None |
| Windows deploy bootstrap | No — uses `infra_dns_cloudflare_primary` and `infra_dns_quad9_primary` | None |
| CoreDNS internal fallback | No — uses `9.9.9.9` (Quad9) as last resort | None |
| Unbound root (Tier 10) | No — recursive to root NS | None |
| Unbound validator | No — forwards to CoreDNS internal | None |

**Conclusion:** No container configs reference Mullvad DNS servers
directly. The dnscrypt-proxy configs auto-select from public resolver
lists with a 72-hour refresh, so any Mullvad entries in those lists
will be dropped automatically. **No action required.**

**Strategic note:** Mullvad's sponsorship of Quad9 strengthens Quad9's
position as a privacy-focused public DNS provider. Quad9 is referenced
in our stack in **bootstrap-only** roles (resolving DoH/DoT/ODoH endpoint
hostnames before encrypted DNS is available), NOT in the resolution chain:
- `doh-quad9-nl` in dnscrypt-proxy-tor.toml.template (Tor tier upstream)
- `9.9.9.9` (`infra_dns_quad9_primary`) as bootstrap DNS in AdGuard and Windows deployment

The resolution chain itself uses privacy tiers ending with Unbound Root
(direct ICANN recursive resolution, no third party) and Plaintext (last
resort). No third-party resolver like Quad9 or Cloudflare appears in the
CoreDNS forward chain.

### Mullvad Browser DoH — Auto-migrated to Quad9

**Source:** Same Mullvad blog post

**What changed:**
Mullvad Browser's default DoH settings will auto-migrate to Quad9.
Users with customized DoH settings will NOT be auto-migrated.

**Impact on our stack:**
- Our Firefox policy role (`common-firefox-policy`) includes Mullvad
  Browser in its list of managed browsers. If we set a DoH policy via
  enterprise policies, it will override the auto-migration. We currently
  do not set DoH policies via Firefox enterprise policies, so the
  auto-migration will proceed normally for Mullvad Browser.
- **Action:** No change needed. If we later add DoH policy management
  via Firefox enterprise policies, ensure we use Quad9 (not Mullvad)
  as the DoH endpoint.

## Provider status reference

| Provider | Protocol | Status | Used in our stack | Notes |
|----------|----------|--------|-------------------|-------|
| Cloudflare | DoH, ODoH | Active | Bootstrap DNS, ODoH target | `1.1.1.1` (`infra_dns_cloudflare_primary`) — bootstrap only |
| Quad9 | DoH, DoT, DNSCrypt | Active, Mullvad-sponsored | Bootstrap, Tor tier upstream | `9.9.9.9` (`infra_dns_quad9_primary`) — bootstrap only; `doh-quad9-nl` in Tor tier |
| Google | DoH | Active | Not referenced | Not in any config |
| Mullvad | DoH | **Shutting down Nov 2026** | Not referenced | No action needed |
| ICANN Root NS | DNS | Active | Tier 10 (Unbound Root) | Direct recursive resolution, no third party |
| dnsdist resolvers list | DNSCrypt, DoH | Auto-refreshed | Tiers 1, 2, 7, 8, 12 | 72h refresh drops stale providers |

## Monitoring for future deprecations

The dnscrypt-proxy resolver lists (`public-resolvers.md`, `odoh-servers.md`)
are refreshed every 72 hours (`refresh_delay = 72` in source configs).
This means stale providers are automatically dropped within 3 days of
being removed from the upstream list.

For providers we reference explicitly (Quad9, Cloudflare), we should
monitor their status pages or announcement feeds. There is no
automated monitoring for this currently — it's a manual process.

## References

- [Mullvad blog: Shutting down public encrypted DNS servers](https://mullvad.net/en/blog/shutting-down-our-public-encrypted-dns-servers-and-sponsoring-quad9-instead)
- [Quad9](https://quad9.net/)
- [Quad9 setup guides](https://docs.quad9.net/)
- [DNSCrypt public resolvers list](https://github.com/DNSCrypt/dnscrypt-resolvers)
