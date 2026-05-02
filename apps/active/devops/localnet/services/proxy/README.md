# Proxy & Gateway Services

This domain handles web traffic routing, caching, filtering, and anonymization. It implements the "Three-Tier Access Model" (Direct, Transparent, Service-Based).

## Packages

- **traefik** — [Traefik](https://traefik.io/) is the edge router, handling Ingress, TLS termination (Let's Encrypt), and service discovery.
- **envoy** — [Envoy Proxy](https://www.envoyproxy.io/) provides transparent interception for HTTP/HTTPS traffic, routing requests to Squid or direct upstreams.
- **squid** — [Squid](http://www.squid-cache.org/) acts as the caching web proxy.
- **privoxy** — [Privoxy](https://www.privoxy.org/) performs content filtering and privacy enhancement before traffic hits the upstream (or Tor).
- **tor-proxy** — [Tor](https://www.torproject.org/) provides anonymization for specific traffic flows.

## Compose file

`docker-compose.proxy.yml` defines these services.

## Traffic Flow

1. **Client** (Transparent Mode) -> **Envoy** (Port 80/443 intercept)
2. **Envoy** -> **Squid** (Caching)
3. **Squid** -> **Privoxy** (Filtering)
4. **Privoxy** -> **Tor** (if .onion or configured) OR **Direct** (Upstream)
