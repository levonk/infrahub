# ODoH Implementation Limitation

## Issue

The `klutchell/dnscrypt-proxy:2.1.5` Docker image does NOT support ODoH (Oblivious DNS over HTTPS) despite correct configuration.

## Root Cause

The image has hardcoded source lists that ignore the mounted configuration file's `[sources]` section:
- Only loads: `public-resolvers` and `relays`
- Ignores: `odoh-servers` and `odoh-relays`

Without these source lists, the `odoh_servers = true` setting has no effect.

## Evidence

```bash
$ docker compose logs dnscrypt-proxy | grep Source
[NOTICE] Source [public-resolvers] loaded
[NOTICE] Source [relays] loaded
# odoh-servers and odoh-relays are never loaded
```

## ODoH Requirements

For ODoH to work, dnscrypt-proxy needs:
1. `odoh_servers = true` in config
2. `[sources.odoh-servers]` - target server list (8 available)
3. `[sources.odoh-relays]` - relay server list
4. Both source lists must be loaded at startup

## Available ODoH Servers

There are **8 ODoH target servers** from multiple providers:
- `odoh-cloudflare` - Cloudflare
- `odoh-crypto-sx` - Scaleway/Frank Denis (anycast, no logs)
- `odoh-id-gmail` - Singapore, filters ads/trackers/malware
- `odoh-jp.tiar.app` - Japan, no logs
- `odoh-jp.tiarap.org` - Japan via Cloudflare
- `odoh-marco.cx` - Uses Cloudflare resolver
- `odoh-snowstorm` - No logs, no filter, DNSSEC
- `odoh-tiarap.org` - Via Cloudflare, filters ads/trackers/malware

## Solutions

### Option 1: Build Custom Image (Recommended)
Build from official dnscrypt-proxy source with proper configuration support:

```dockerfile
FROM alpine:latest
RUN apk add --no-cache dnscrypt-proxy
COPY dnscrypt-proxy.toml /etc/dnscrypt-proxy/
CMD ["dnscrypt-proxy", "-config", "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"]
```

### Option 2: Use Different Base Image
Find or create an image that properly respects the full configuration file.

### Option 3: Accept DoH/DNSCrypt
Current state: DNS queries are encrypted via DoH/DNSCrypt (not ODoH).
- Still provides privacy protection
- Not as strong as ODoH (doesn't separate query content from client identity)

## Current Status

**Test modified to accept DoH/DNSCrypt** as a temporary workaround.

Configuration file is correct and ready for ODoH when a compatible image is used.

## References

- [Official dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)
- [ODoH servers list](https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-servers.md)
- [ODoH relays list](https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/odoh-relays.md)
