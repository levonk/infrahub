# Three-Tier Access Model

**Feature**: Home Lab In-a-Box  
**Date**: 2025-01-21  
**Status**: Design Documentation

## Overview

The homelab infrastructure implements a three-tier access model to provide flexible network access while maintaining security and observability. This model separates access into three distinct tiers based on trust level and enforcement requirements.

---

## Tier 1: Host Access (Unmanaged)

**Description**: The Docker host machine has direct access to all services and the internet.

### Characteristics
- **Trust Level**: Highest (administrator-controlled)
- **Enforcement**: None (no transparent proxying)
- **Internet Access**: Direct, unfiltered
- **Service Access**: Via explicit localhost ports

### Access Methods
- Direct port access to all services on `localhost`
- Example: `curl http://localhost:3000` (Grafana)
- Example: `dig @localhost -p 5353 example.com` (DNS direct mode)

### Use Cases
- System administration and debugging
- Direct service configuration
- Emergency access when services are down
- Development and testing

### Security Considerations
- ⚠️ **No filtering or observation** - Host bypasses all homelab services
- ⚠️ **No DNS filtering** - Malicious domains not blocked
- ⚠️ **No web caching** - No bandwidth optimization
- ✅ **Full control** - Administrator can troubleshoot issues
- ✅ **No dependencies** - Works even if homelab services fail

### Port Mapping
See [port-mapping.md](./port-mapping.md) for complete list of exposed ports.

---

## Tier 2: Services (Upstream Access)

**Description**: Infrastructure services (DNS, NTP, proxies) have direct internet access for upstream queries.

### Characteristics
- **Trust Level**: Medium (containerized, isolated)
- **Enforcement**: None (services need direct upstream access)
- **Internet Access**: Direct to upstream providers
- **Service Access**: Internal Docker network

### Services in Tier 2
- **DNS Services**: dnsdist, CoreDNS, dnscrypt-proxy
- **NTP Service**: chronyd
- **Web Proxies**: Envoy, Squid, Privoxy, Tor
- **Monitoring**: Prometheus, Grafana, Jaeger
- **Logging**: Vector, Elasticsearch, Loki
- **Artifact Repos**: Nexus, Verdaccio

### Network Configuration
```yaml
# Services connect to homelab network
networks:
  homelab:
    # No gateway specified - direct internet access
```

### Upstream Connectivity
- **DNS**: Queries to 1.1.1.1, 8.8.8.8, ODoH relays
- **NTP**: Sync with time.google.com, time.nist.gov
- **Web**: Fetch from upstream registries, CDNs
- **Monitoring**: Optional remote log shipping (BetterStack)

### Security Considerations
- ✅ **Container isolation** - Services run in isolated containers
- ✅ **Minimal attack surface** - Only required ports exposed
- ✅ **Resource limits** - CPU/memory constraints enforced
- ⚠️ **Direct internet** - Services can reach any IP (required for function)
- ⚠️ **No egress filtering** - Services not restricted (by design)

---

## Tier 3: Apps (Enforced Transparent Proxying)

**Description**: Application containers MUST use the transparent gateway for all network access.

### Characteristics
- **Trust Level**: Lowest (user applications, untrusted)
- **Enforcement**: **MANDATORY** via iptables DNAT rules
- **Internet Access**: Only through homelab proxy chain
- **Service Access**: Via transparent gateway

### Enforcement Mechanism
```yaml
# App containers configure DNS to use gateway
services:
  my-app:
    networks:
      homelab:
    dns:
      - 172.20.0.254  # Transparent gateway IP
```

### Traffic Flow
1. App makes DNS query to any IP → Intercepted by gateway
2. Gateway DNAT redirects to dnsdist:5353
3. DNS query flows through: dnsdist → CoreDNS → dnscrypt-proxy → ODoH
4. App makes HTTP request → Intercepted by gateway
5. Gateway DNAT redirects to Envoy → Squid → Privoxy → (optional Tor)

### Blocked Direct Access
- ❌ **Cannot** bypass transparent gateway
- ❌ **Cannot** access internet directly
- ❌ **Cannot** use custom DNS servers
- ❌ **Cannot** disable filtering/caching

### Use Cases
- **Development containers**: Node.js, Python, Go apps
- **Testing environments**: Integration test suites
- **User applications**: Personal projects, experiments
- **Managed devices** (via VPN): Kids' devices, guest access

### Security Considerations
- ✅ **Full observation** - All traffic logged and monitored
- ✅ **DNS filtering** - Malware/ad domains blocked
- ✅ **Content filtering** - Privoxy rules applied
- ✅ **Caching** - Bandwidth optimization
- ✅ **Privacy** - Optional Tor routing
- ⚠️ **Performance overhead** - Multi-layer proxy adds latency (~200ms)

---

## Access Mode Detection

All services log whether traffic arrived via transparent or direct access:

### Log Format
```json
{
  "timestamp": "2025-01-21T12:34:56.789Z",
  "service": "dnsdist",
  "mode": "transparent",  // or "direct"
  "client_ip": "172.20.0.10",
  "query": "example.com"
}
```

### Detection Methods
- **Transparent mode**: Traffic arrives at internal port (5353, 1123, 3129)
- **Direct mode**: Traffic arrives at exposed port (53, 123, 3128)
- **Packet marking**: iptables marks packets with `meta mark 1` for transparent

---

## Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Host (Unmanaged)                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Docker Host Machine                                     │ │
│ │ - Direct internet access (no filtering)                 │ │
│ │ - localhost:* access to all services                    │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          │
                          ├─────────────────────────────┐
                          │                             │
┌─────────────────────────▼─────────┐   ┌───────────────▼──────────────┐
│ Tier 2: Services (Upstream)       │   │ Tier 3: Apps (Enforced)      │
│ ┌───────────────────────────────┐ │   │ ┌──────────────────────────┐ │
│ │ DNS: dnsdist → CoreDNS →     │ │   │ │ App Containers           │ │
│ │      dnscrypt-proxy → ODoH   │ │   │ │ - MUST use gateway       │ │
│ │                               │ │   │ │ - dns: [172.20.0.254]    │ │
│ │ NTP: chronyd → NTS providers │ │   │ │ - All traffic logged     │ │
│ │                               │ │   │ └──────────────────────────┘ │
│ │ Web: Envoy → Squid →         │ │   │              │                │
│ │      Privoxy → Tor           │ │   │              ▼                │
│ │                               │ │   │ ┌──────────────────────────┐ │
│ │ Monitoring: Prometheus,      │ │   │ │ Transparent Gateway      │ │
│ │            Grafana, Jaeger   │ │   │ │ - iptables DNAT rules    │ │
│ │                               │ │   │ │ - DNS: 53 → 5353         │ │
│ │ Logging: Vector, ES, Loki    │ │   │ │ - NTP: 123 → 123         │ │
│ │                               │ │   │ │ - HTTP: 80 → 3128        │ │
│ │ Artifacts: Nexus, Verdaccio  │ │   │ │ - HTTPS: 443 → 3128      │ │
│ └───────────────────────────────┘ │   │ └──────────────────────────┘ │
│              │                     │   └──────────────────────────────┘
│              ▼                     │                │
│    Direct Internet Access          │                │
│    (upstream queries only)         │                ▼
└────────────────────────────────────┘    Routes to Tier 2 Services
```

---

## Configuration Examples

### Tier 1: Host Access
```bash
# Direct DNS query (bypasses filtering)
dig @localhost -p 5353 example.com

# Direct web access (bypasses caching)
curl http://localhost:3128 --proxy http://localhost:3128 http://example.com

# Grafana dashboard
curl http://localhost:3000
```

### Tier 2: Service Configuration
```yaml
# docker-compose.yml
services:
  dnsdist:
    networks:
      homelab:  # No gateway - direct internet
    ports:
      - "53:53/udp"      # Transparent mode
      - "5353:5353/udp"  # Direct mode
```

### Tier 3: App Configuration
```yaml
# docker-compose.yml
services:
  my-app:
    networks:
      homelab:
    dns:
      - 172.20.0.254  # REQUIRED: Transparent gateway
    # No direct internet access
```

---

## Troubleshooting

### App Cannot Resolve DNS
**Symptom**: `getaddrinfo: Name or service not known`

**Diagnosis**:
```bash
# Check app DNS configuration
docker inspect my-app | jq '.[0].HostConfig.Dns'

# Should show: ["172.20.0.254"]
```

**Fix**: Add `dns: [172.20.0.254]` to app service in docker-compose.yml

### App Bypassing Transparent Gateway
**Symptom**: Traffic not appearing in logs with `mode=transparent`

**Diagnosis**:
```bash
# Check iptables rules in gateway
<<<<<<< HEAD
docker exec homelab-transparent-gateway iptables -t nat -L -n -v
=======
docker exec homelab-proxy-transparent-gateway iptables -t nat -L -n -v
>>>>>>> 002-claude-code-integration

# Verify DNAT rules exist for DNS (53→5353), HTTP (80→3128), HTTPS (443→3128)
```

**Fix**: Restart transparent-gateway service

### Host Cannot Access Services
**Symptom**: `Connection refused` when accessing localhost ports

**Diagnosis**:
```bash
# Check service is running
docker compose ps

# Check port is exposed
docker compose port dnsdist 5353
```

**Fix**: Ensure service has `ports:` section in docker-compose.yml

---

## Security Implications

### Tier 1 (Host) Risks
- **No protection**: Host can access malicious sites
- **No observation**: Host traffic not logged
- **Mitigation**: Rely on host-level security (firewall, antivirus)

### Tier 2 (Services) Risks
- **Upstream compromise**: If upstream DNS/NTP compromised, services affected
- **Mitigation**: Use multiple upstream providers, enable DNSSEC/NTS

### Tier 3 (Apps) Risks
- **Gateway SPOF**: If gateway fails, apps lose connectivity
- **Mitigation**: Implement gateway failure modes (T013a-e)
- **Performance**: Multi-layer proxy adds latency
- **Mitigation**: Aggressive caching, connection pooling

---

## Future Enhancements

### Planned (from tasks.md)
- **T013a-e**: Gateway failure modes with traffic queuing and fallback
- **T016**: This document (✅ completed)
- **T017**: Transparent proxy usage guide

### Potential
- **Tier 2.5**: Semi-trusted apps with selective filtering
- **Dynamic tier assignment**: Apps can request tier changes
- **Per-app policies**: Custom filtering rules per container
- **Egress firewall**: Restrict Tier 2 services to known IPs

---

## References

- [Transparent Gateway Configuration](../configs/transparent-gateway/)
- [Port Mapping](./port-mapping.md)
- [Service Chains](./service-chains.md)
- [Troubleshooting Guide](./troubleshooting.md)
