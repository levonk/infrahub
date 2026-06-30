# dashboard-homepage

Deploys [Homepage](https://github.com/gethomepage/homepage) — a rich startpage with Docker label discovery and 100+ service widgets.

## Variables

| Variable | Default | Description |
|---|---|---|
| `dashboard_homepage_enabled` | `true` | Enable the role |
| `dashboard_homepage_domain` | `start.levonk.com` | Traefik domain |
| `dashboard_homepage_host_port` | `8084` | Host port |
| `dashboard_homepage_container_port` | `3000` | Container port |
| `dashboard_homepage_network_name` | `traefik-network` | Docker network |

## Traefik

Routes `start.levonk.com` through the `geoblock,crowdsec-bouncer,authelia` middleware chain (HTTPS via Let's Encrypt).

## Docker Discovery

Homepage reads the Docker socket (mounted read-only) and discovers containers with `homepage.*` labels. Add labels to any container you want surfaced:

```yaml
labels:
  homepage.group: "Media"
  homepage.name: "Jellyfin"
  homepage.icon: "jellyfin.png"
  homepage.href: "https://jellyfin.levonk.com"
  homepage.widget.type: "jellyfin"
  homepage.widget.url: "http://jellyfin:8096"
```

## See Also

- [ADR-20260629001](../../../08-docs/adr/adr-20260629001-start-launch-page-dashboards.md) — decision rationale
- [Homepage docs](https://gethomepage.dev/)
