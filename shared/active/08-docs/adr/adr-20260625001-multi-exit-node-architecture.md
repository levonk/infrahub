# Multi-Exit Node Architecture for Levonk VPN Infrastructure

## Status

**Accepted** - 2026-06-25

## Context

The Levonk VPN infrastructure requires flexible exit node options to support different use cases:
- Regular development work (fast, direct connection)
- Privacy-sensitive operations (VPN protection)
- High-anonymity requirements (Tor network)
- Geo-location flexibility (multiple exit regions)

Previously, the infrastructure supported dual exit nodes (Direct Oracle Cloud + NordVPN). This ADR extends the architecture to include Tor as a third exit node option.

## Decision

### Architecture Overview

The Levonk infrastructure now supports **three exit node configurations**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Devices                            │
│              (e.g., laptops, desktops, mobile)               │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │  Direct │ │ NordVPN  │ │    Tor   │
   │  Exit   │ │  Exit    │ │  Exit    │
   │   (oci) │ │(nordvpn) │ │  (tor)   │
   └────┬────┘ └────┬─────┘ └────┬─────┘
        │           │            │
        ▼           ▼            ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │ Oracle  │ │ NordVPN  │ │   Tor    │
   │ Cloud   │ │  Tunnel  │ │ Network  │
   │ 161.153 │ │ 86.62.29 │ │  Varies  │
   │ .91.163  │ │   .205   │ │          │
   └─────────┘ └──────────┘ └──────────┘
```

### Exit Node Characteristics

| Exit Node | Latency | Bandwidth | Privacy | Use Case |
|-----------|---------|-----------|---------|----------|
| **Direct (oci)** | Low | High | Oracle IP visible | Regular browsing, development |
| **NordVPN (nordvpn)** | Moderate | Good | NordVPN IP visible | Privacy-sensitive operations |
| **Tor (tor)** | High | Variable | Tor exit IP visible | High-anonymity requirements |

### Technical Implementation

#### 1. Direct Exit Node (`oci`)
- **Implementation**: Host-level Tailscale service
- **Routing**: Direct Oracle Cloud connection
- **Configuration**: Standard Tailscale daemon
- **Network**: Host network stack
- **Management**: Systemd service

#### 2. NordVPN Exit Node (`oci-vpn-server-nordvpn`)
- **Implementation**: Docker container with NordVPN + Tailscale
- **Routing**: Tailscale → NordVPN container → Internet
- **Network**: Dedicated `vpn-network` (172.28.0.0/16)
- **Configuration**: Custom routing via NordVPN container IP
- **Management**: Docker Compose

#### 3. Tor Exit Node (`oci-vpn-server-tor`)
- **Implementation**: Docker container with Tor + Tailscale
- **Routing**: Tailscale → Tor SOCKS proxy → Tor network → Internet
- **Network**: Dedicated `tor-network` (172.29.0.0/16)
- **Configuration**: Tailscale with `ALL_PROXY=socks5://tor-exit:9050`
- **Management**: Docker Compose with profile support

### Network Configuration

#### Docker Networks

```yaml
# NordVPN Network
vpn-network:
  driver: bridge
  subnet: 172.28.0.0/16
  gateway: 172.28.0.1
  containers:
    - nordvpn: 172.28.0.2
    - tailscale-nordvpn: 172.28.0.3

# Tor Network
tor-network:
  driver: bridge
  subnet: 172.30.0.0/16
  gateway: 172.30.0.1
  containers:
    - tor-exit: 172.30.0.2
    - tailscale-tor: 172.30.0.3
```

#### Routing Tables

**NordVPN Container:**
```
default via 10.100.0.1 dev tun0 (VPN tunnel)
10.100.0.0/20 dev tun0 (VPN subnet)
172.28.0.0/16 dev eth0 (Docker network)
```

**Tailscale NordVPN Container:**
```
default via 172.28.0.2 dev eth0 (NordVPN container)
172.28.0.0/16 dev eth0 (Docker network)
```

**Tor Exit Container:**
```
default via 172.30.0.1 dev eth0 (Docker bridge)
172.30.0.0/16 dev eth0 (Docker network)
```

**Tailscale Tor Container:**
```
default via 172.30.0.2 dev eth0 (Tor container)
172.30.0.0/16 dev eth0 (Docker network)
```

### Configuration Files

#### Tor Configuration (`torrc.template`)
```bash
# SOCKS5 proxy
SocksPort 0.0.0.0:9050

# Exit node configuration (optional)
ORPort 9001
DirPort 9030
Nickname levonk-tor-exit
ExitPolicy reject *:*
RelayBandwidthRate 100 KB
RelayBandwidthBurst 200 KB
```

#### Tailscale Tor Integration
```yaml
environment:
  - TS_AUTHKEY=${TS_AUTHKEY}
  - TS_HOSTNAME=oci-vpn-server-tor
  - TS_EXTRA_ARGS=--advertise-exit-node --accept-routes
  - ALL_PROXY=socks5://tor-exit:9050
  - all_proxy=socks5://tor-exit:9050
```

### Ansible Integration

#### New Variables

**proxy-tor role:**
```yaml
proxy_tor_exit_node_enabled: false
proxy_tor_orport_container: "9001"
proxy_tor_dirport_container: "9030"
proxy_tor_nickname: "levonk-tor-exit"
proxy_tor_exit_policy: "reject *:*"
proxy_tor_bandwidth_rate: "100 KB"
proxy_tor_bandwidth_burst: "200 KB"
```

**vpn-tailscale role:**
```yaml
vpn_tailscale_tor_enabled: false
vpn_tailscale_tor_hostname: "oci-vpn-server-tor"
vpn_tailscale_tor_network_name: "tor-network"
```

#### Deployment Tasks

The Ansible role now includes:
1. Tor network creation
2. Tor exit node container deployment
3. Tailscale-over-Tor container deployment
4. Network routing configuration
5. Health checks and verification

## Consequences

### Benefits

1. **Flexibility**: Three exit node options for different use cases
2. **Privacy**: Tor integration for maximum anonymity
3. **Performance**: Direct exit node for speed-critical tasks
4. **Compliance**: VPN options for privacy requirements
5. **Isolation**: Each exit node in separate network
6. **Scalability**: Easy to add more exit node types

### Drawbacks

1. **Complexity**: Additional configuration and management
2. **Resource Usage**: Multiple containers and networks
3. **Tor Performance**: Significantly higher latency
4. **Legal Considerations**: Tor exit node implications
5. **Maintenance**: More services to monitor and update

### Risks

1. **Tor Abuse**: Exit node could be used for malicious activities
2. **Resource Exhaustion**: Tor can consume significant bandwidth
3. **Legal Issues**: Exit node operation may violate terms of service
4. **Network Conflicts**: Multiple VPN configurations may conflict
5. **Security**: Additional attack surface with more services

### Mitigations

1. **Conservative Exit Policies**: Default `reject *:*` policy
2. **Bandwidth Limits**: Configurable rate limiting
3. **Monitoring**: Enhanced logging and health checks
4. **Legal Review**: Consult hosting provider before enabling exit
5. **Network Isolation**: Separate Docker networks for each service
6. **Documentation**: Clear usage guidelines and warnings

## Alternatives Considered

### Alternative 1: Single Multi-Purpose Exit Node
- **Description**: One Tailscale instance with dynamic routing
- **Rejected**: Too complex, harder to manage, single point of failure

### Alternative 2: Tor as Only Exit Option
- **Description**: Use Tor for all exit traffic
- **Rejected**: Poor performance, overkill for regular use cases

### Alternative 3: Netbird Integration
- **Description**: Add Netbird as fourth exit node option
- **Rejected**: Netbird has known compatibility issues with Tor

## Implementation Status

- ✅ Tor Docker configuration updated with exit node support
- ✅ Tailscale-over-Tor docker-compose configuration created
- ✅ Ansible roles updated with Tor integration
- ✅ Documentation updated with multi-exit architecture
- ✅ Netbird limitations documented
- ⏳ Testing and validation pending
- ⏳ Production deployment pending

## Usage Guidelines

### When to Use Each Exit Node

**Direct Exit Node (`oci`):**
- Regular web browsing
- Development work
- Non-sensitive operations
- When performance is critical

**NordVPN Exit Node (`oci-vpn-server-nordvpn`):**
- Privacy-sensitive browsing
- Geo-location requirements
- Content unblocking
- When VPN protection is needed

**Tor Exit Node (`oci-vpn-server-tor`):**
- High-anonymity requirements
- Whistleblowing/journalism
- Circumventing censorship
- When maximum privacy is needed

### Client Configuration

```bash
# Direct exit (default)
sudo tailscale up --exit-node=oci

# NordVPN exit
sudo tailscale up --exit-node=oci-vpn-server-nordvpn

# Tor exit
sudo tailscale up --exit-node=oci-vpn-server-tor

# No exit node
sudo tailscale up
```

### Verification

```bash
# Check current exit node
tailscale status

# Verify public IP
curl https://ipinfo.io/

# Test Tor connectivity
curl --socks5 127.0.0.1:9050 https://check.torproject.org
```

## References

- [Dual Exit Node Architecture](../levonk/docs/requirements/dual-exit-node-architecture.md)
- [Tor Project Documentation](https://www.torproject.org/docs/)
- [Tailscale Exit Nodes](https://tailscale.com/kb/1199/tailscale-exit-nodes/)
- [Netbird Tor Limitations](../../services/vpn/netbird/NETBIRD_TOR_LIMITATIONS.md)
