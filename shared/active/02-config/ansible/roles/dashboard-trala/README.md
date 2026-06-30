# dashboard-trala

Deploys [TraLa](https://github.com/dannybouwers/trala) — a Traefik-native dashboard that auto-discovers HTTP routers from the Traefik API.

## Variables

| Variable | Default | Description |
|---|---|---|
| `dashboard_trala_enabled` | `true` | Enable the role |
| `dashboard_trala_domain` | `start2.levonk.com` | Traefik domain |
| `dashboard_trala_host_port` | `8085` | Host port |
| `dashboard_trala_container_port` | `8080` | Container port |
| `dashboard_trala_traefik_api_host` | `http://traefik:8080` | Traefik API URL (container-internal) |
| `dashboard_trala_network_name` | `traefik-network` | Docker network (must match Traefik's network) |

## Traefik

Routes `start2.levonk.com` through the `geoblock,crowdsec-bouncer,authelia` middleware chain (HTTPS via Let's Encrypt).

## Auto-Discovery

TraLa reads the Traefik API at `TRAEFIK_API_HOST` and fetches all HTTP routers. Services appear/disappear as Traefik routes them — zero per-service config.

## See Also

- [ADR-20260629001](../../../08-docs/adr/adr-20260629001-start-launch-page-dashboards.md) — decision rationale
- [TraLa docs](https://www.trala.fyi)
