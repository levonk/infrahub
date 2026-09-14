# media-coturn

Deploy [coturn](https://github.com/coturn/coturn) — a STUN/TURN server for WebRTC
voice chat relay in Local Watch Party.

## Container

- **Image**: `coturn/coturn:4.17.2-alpine` (upstream, multi-arch)
- **STUN/TURN port**: 3487 (host) → 3478 (container) — 3478 is taken by NetBird
- **Relay port range**: 49000-49050 UDP (50 ports, sufficient for 5-10 users)
- **Config**: `/opt/localnet/config/coturn/turnserver.conf`

## Traefik

coturn is **NOT** routed through Traefik. UDP relay traffic is incompatible with
HTTP/TCP reverse proxies. coturn binds directly to host ports.

## Firewall

The following ports must be opened on the public firewall:
- `3487/tcp` + `3487/udp` — STUN/TURN control
- `49000-49050/udp` — TURN relay range

## Monitoring

- **Health**: Container running (no HTTP health endpoint)
- **Pipeline**: none (standalone relay service)
