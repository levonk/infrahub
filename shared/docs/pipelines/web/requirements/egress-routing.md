# Egress Routing with Gost

**Date:** 2026-08-10
**Status:** Proposed
**Related:** `shared/docs/pipelines/web/complete-web-proxy-chain.mmd`

## The Problem

The web proxy chain needs to route outgoing traffic to different egress
backends based on rules:
- `.onion` domains → Tor (anonymity required)
- Default traffic → Direct (highest performance)
- Configurable traffic → Cloudflare WARP (balanced, future)

The egress multiplexer sits at Layer 5, receiving cache misses from Varnish
and forwarding them to the appropriate backend.

## Technology Choice: Gost

**Gost** (GO Simple Tunnel) is a versatile proxy and tunneling tool that
supports:
- Multiple forwarding chains with different protocols
- Protocol matchers (route based on host, network type, etc.)
- Virtual nodes (direct connections without upstream proxy)
- Chain groups with selector strategies (round-robin, random, etc.)

The project already has a locally-built Gost image at
`shared/active/03-container/services/proxy/gost/` (based on
`localnet-base-alpine` + Gost 3.0.0-rc8 binary).

## Configuration

Gost needs a YAML configuration file (`gost.yaml`) to define the egress
chains and routing rules. The current implementation only runs
`gost -L socks5://:1080` (basic SOCKS5 listener) — it needs the full config.

### Proposed gost.yaml

```yaml
services:
- name: http-egress
  addr: ":8080"
  handler:
    type: http
    chain: egress-chain
- name: socks5-egress
  addr: ":1080"
  handler:
    type: socks5
    chain: egress-chain

chains:
- name: egress-chain
  hops:
  - name: egress-hop
    selector:
      strategy: round
    nodes:
    # Tier 1: Direct (default — highest performance)
    - name: direct
      connector:
        type: http
      dialer:
        type: virtual
      matcher:
        rule: "Host(`*`)"

    # Tier 2: Tor (for .onion domains + anonymity)
    - name: tor
      addr: "172.26.255.70:9050"
      connector:
        type: socks5
      dialer:
        type: tcp
      matcher:
        rule: "Host(`*.onion`)"

    # Tier 3: WARP (dark — not deployed by default)
    # - name: warp
    #   addr: "warp:40000"
    #   connector:
    #     type: socks5
    #   dialer:
    #     type: tcp
    #   matcher:
    #     rule: "Host(`warp.example.com`)"
```

### Routing Rules

| Rule | Backend | Priority |
|------|---------|----------|
| `Host(*.onion)` | Tor SOCKS5 (172.26.255.70:9050) | 1 (highest) |
| `Host(*)` (default) | Direct (virtual node) | 2 (fallback) |
| Custom (future) | WARP | 3 (dark) |

### Protocol Matchers

Gost uses Traefik-style rule syntax for matchers:
- `Host(`domain`)` — match specific domain
- `Host(`*.onion`)` — wildcard match
- `Network(`tcp`)` — match network type
- Multiple rules can be combined with `&&` and `||`

## Port Allocation

| Port | Purpose |
|------|---------|
| `1080` | SOCKS5 egress (bypass access) |
| `8080` | HTTP egress (from Varnish cache miss) |

## Health Check

The health check should verify that Gost can reach each active backend:

```bash
# Check SOCKS5 listener
curl --socks5 localhost:1080 http://example.com

# Check Tor routing (if .onion test endpoint available)
curl --socks5 localhost:1080 http://example.onion
```

## Integration with DNS Chain

Gost uses the LocalNet DNS chain for DNS resolution. This ensures:
- `.onion` domains resolve correctly (some are in Tor's hidden service DNS)
- Ad/tracker domains are filtered by AdGuard before reaching Gost
- DNSSEC validation happens via Unbound

## Future: WARP Integration

Cloudflare WARP provides a WireGuard-based VPN tunnel. To integrate:
1. Deploy a WARP client container (e.g., `caarlos0/warp`)
2. Add WARP as a node in the Gost chain
3. Configure matcher rules for WARP-routed traffic
4. Health check the WARP tunnel connectivity

This is documented as DARK (not deployed by default) in the architecture.
