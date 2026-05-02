## Completed
- ✅ **ODoH Implementation** (2025-10-22)
  - Built custom Dockerfile for dnscrypt-proxy v2.1.5 from official binary
  - Configured ODoH with anonymized DNS routing
  - Fixed TOML configuration structure issues
  - Verified DNS resolution working through ODoH
  - See: `odoh-implementation-summary.md`

## In Progress
- ⏳ DNS Metrics Collection - needs dnsdist restart
- ⏳ DNS Blocklist Integration - needs dnsdist restart

## Backlog
- Wireguard keys shared between wireguard networks
- Cloudflare Free WARP VPN network exposed through wireguard
- Separate docker-compose for each protocol (DNS, HTTP, VPN, NTP, etc) that can stand on its own for a minimal setup, is there a way we maintain DRY with this setup? Leverage composable docker hub files https://docs.docker.com/reference/compose-file/include/ come up with better design but maybe we can layer core dns, vpn layer 1 + transparent layer, vpn layer 2, full set of services. Also ntp, transparent, full set, be cognizing of dependencies like logging, metrics, dns, web proxy,

## Service Structure Migration

### Completed
- [x] Base infrastructure
- [x] VPN: cloudflare-warp
- [x] Proxy: gost

### Pending Migration
#### Core Services
- [ ] DNS: dnsdist, coredns, dnscrypt-proxy
- [ ] NTP: chrony
- [ ] Proxy: squid, privoxy, envoy

#### Observability
- [ ] Logging: vector, loki, promtail
- [ ] Monitoring: prometheus, grafana
- [ ] Tracing: jaeger

#### Artifacts
- [ ] nexus
- [ ] verdaccio

### Migration Steps
1. Create service directories
2. Move Dockerfiles to docker/
3. Create healthcheck scripts
4. Move configs to assets/
5. Update docker-compose paths
