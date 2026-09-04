# proxy-web Role

Web Proxy Chain — MITM → Privoxy → Varnish → Gost egress multiplexer.

## Architecture

See `shared/docs/pipelines/web/complete-web-proxy-chain.mmd` for the full architecture diagram.

```
Client
  ↓ (explicit: port 3127/3128, transparent: nftables 80/443)
MITM Proxy (mitmproxy/mitmproxy) — HTTPS decryption, CA management
  ↓
Privoxy (vimagick/privoxy) — content filtering, header sanitization
  ↓
Varnish (varnish) — HTTP cache, stale-while-revalidate, stale-if-error
  ↓ (cache miss)
Gost (locally-built) — egress multiplexer
  ↓                    ↓
Direct              Tor (shared with DNS chain)
  ↓                    ↓
Internet            Internet
```

## Variables

All variables are mapped from `infra_*` infrastructure variables in
`defaults/main.yml`. See:
- `infrastructure/ports.yml` — port allocations
- `infrastructure/networks.yml` — IP allocations
- `infrastructure/domains.yml` — domain names
- `infrastructure/storage.yml` — volume names

## Deployment

### Linux/OCI (community.docker modules)

```bash
just ansible-deploy-proxy-web
```

### Windows (SSH-tunneled Docker CLI)

The same playbook targets Windows hosts automatically. Config templates
are seeded into Docker volumes via temp alpine containers (matching the
DNS chain pattern).

## Requirements

- The Gost image (`localnet-proxy-gost`) must be built and available.
  See `scripts/build-and-push-images.sh`.
- The DNS chain's Tor proxy must be running (shared at 172.26.255.70:9050).
- The localnet-network must exist (created by the DNS chain role).
