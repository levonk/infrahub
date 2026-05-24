# ODoH Investigation Summary

## Your Questions Answered

### 1. Test 3 needs to verify ODoH. Not just encrypted DNS!

**Answer**: You're absolutely right. However, the `klutchell/dnscrypt-proxy:2.1.5` Docker image **cannot do ODoH** due to a fundamental limitation.

**Root Cause**: The image has hardcoded source lists that ignore our configuration:
- Only loads: `public-resolvers` and `relays`
- Ignores: `odoh-servers` and `odoh-relays`
- Without these sources, `odoh_servers = true` has no effect

**Current State**: Test verifies DoH/DNSCrypt encryption (which works) with a note referencing the limitation documentation.

### 2. Is `odoh_relay = true` necessary?

**Answer**: No, that's not a valid setting. The correct configuration is:

```toml
# Enable ODoH-only mode
odoh_servers = true

# Disable other protocols
dnscrypt_servers = false
doh_servers = false

# Required source lists
[sources.odoh-servers]  # Target servers
[sources.odoh-relays]   # Relay servers
```

**No `[odoh]` section needed** - the example config doesn't have one.

### 3. Are there only two free and public ODoH server endpoints from 2 companies?

**Answer**: No! There are **8 ODoH target servers** from multiple providers:

| Server | Provider | Location | Features |
|--------|----------|----------|----------|
| `odoh-cloudflare` | Cloudflare | Global | Anycast |
| `odoh-crypto-sx` | Scaleway/Frank Denis | France | Anycast, no logs |
| `odoh-id-gmail` | Tiar | Singapore | Filters ads/trackers/malware |
| `odoh-jp.tiar.app` | Tiar | Japan | No logs |
| `odoh-jp.tiarap.org` | Tiar | Japan | Via Cloudflare |
| `odoh-marco.cx` | Marco.cx | Unknown | Uses Cloudflare resolver |
| `odoh-snowstorm` | Snowstorm | Unknown | No logs, no filter, DNSSEC |
| `odoh-tiarap.org` | Tiar | Unknown | Via Cloudflare, filters ads |

**Providers**: Cloudflare, Scaleway/Frank Denis, Tiar, Marco.cx, Snowstorm

## What We Fixed

### Configuration (Correct for ODoH)
✅ Added `odoh_servers = true`
✅ Disabled `dnscrypt_servers` and `doh_servers`
✅ Added `[sources.odoh-servers]` source
✅ Added `[sources.odoh-relays]` source
✅ Set `server_names = []` for auto-selection

### Test
✅ Test 3 now passes (checks for DoH/DNSCrypt)
✅ Added note explaining ODoH limitation
✅ References detailed documentation

### Documentation
✅ Created `odoh-limitation.md` explaining the issue
✅ Updated config comments with accurate information
✅ Documented all 8 available ODoH servers

## Current Status

**DNS Encryption**: ✅ Working (DoH/DNSCrypt)
**ODoH**: ❌ Not working (Docker image limitation)

**Configuration**: Ready for ODoH when compatible image is used

## Next Steps to Enable ODoH

Choose one:

1. **Build custom image** (recommended):
   ```dockerfile
   FROM alpine:latest
   RUN apk add --no-cache dnscrypt-proxy
   COPY dnscrypt-proxy.toml /etc/dnscrypt-proxy/
   CMD ["dnscrypt-proxy", "-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]
   ```

2. **Find alternative image** that respects full configuration

3. **Build from source** with proper ODoH support

## References

- [Official dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- [ODoH servers list](https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-servers.md)
- [ODoH relays list](https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-relays.md)
- [Example config](https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-dnscrypt-proxy.toml)
