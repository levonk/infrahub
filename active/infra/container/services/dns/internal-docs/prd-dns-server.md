---
# Product Requirements Document (PRD)

## Introduction / Overview
- **Feature name:** Enterprise DNS Server for Local Network
- **Summary:** A secure, full-featured DNS server implementation for local network infrastructure supporting zones, DNSSEC, split-horizon DNS, and access control lists.
- **Context:**
  - This feature is for localnet infrastructure operators who need secure DNS services within their development and production environments.
  - Based on NIST SP 800-81r3 (Secure Domain Name System (DNS) Deployment Guide).
  - **Existing implementation:** See dns-service-chain.md, dns-flow-diagram.mmd, dns-sequence-diagram.mmd, and dns-protocols.md in this directory.
  - Current stack: **AdGuard Home** → dnsdist → CoreDNS → dnscrypt-proxy (ODoH) with blocklist filtering
  - **Deployment:** Two clusters - one local homelab, one cloud (exposed via Tailscale); local cluster is primary, cloud cluster syncs data

## Goals
- Deploy a containerized DNS server supporting full enterprise features
- Implement DNSSEC validation and signing for secure DNS resolution
- Support local zone management for internal domain names
- Provide split-horizon DNS for internal vs external query handling
- Enable access control lists for query restrictions
- Support both development and production environments
- Add AdGuard Home as user-facing entrypoint with web UI, DHCP, and ad blocking
- Implement multi-cluster deployment with local and cloud (Tailscale) clusters
- Configure data synchronization from primary (local) to secondary (cloud) cluster
- Expose all DNS services to internal users with proper network configuration

## User Stories
- **As an** infrastructure operator, **I want** to run a DNS server in Docker containers, **so that** I can provide DNS resolution for local network services.
- **As an** infrastructure operator, **I want** to define local DNS zones for internal domains, **so that** internal services can be resolved by name.
- **As an** infrastructure operator, **I want** DNSSEC validation enabled, **so that** DNS responses are verified cryptographically.
- **As an** infrastructure operator, **I want** split-horizon DNS, **so that** internal clients get internal IP addresses while external clients get public IPs.
- **As an** infrastructure operator, **I want** ACL-based query restrictions, **so that** I can control which clients can make certain queries.
- **As a** developer, **I want** to run the same DNS configuration in dev and prod, **so that** behavior is consistent across environments.
- **As an** infrastructure operator, **I want** AdGuard Home as the user entrypoint, **so that** users get ad blocking, web UI, and DHCP services.
- **As an** infrastructure operator, **I want** to expose DNS services to internal users, **so that** all local network clients can use the DNS stack.
- **As an** infrastructure operator, **I want** a cloud DNS cluster accessible via Tailscale, **so that** I have DNS access when away from home.
- **As an** infrastructure operator, **I want** data synchronization from local to cloud cluster, **so that** both clusters have consistent configuration and blocklists.

## Functional Requirements
- **FR-001:** The DNS server shall run as a Docker container service.
- **FR-002:** The DNS server shall provide recursive caching DNS resolution for external domains.
- **FR-003:** The DNS server shall support authoritative zone management for local domains.
- **FR-004:** The DNS server shall implement DNSSEC validation for upstream DNS responses.
- **FR-005:** The DNS server shall support DNSSEC signing for locally managed zones.
- **FR-006:** The DNS server shall implement split-horizon DNS (different responses based on query source).
- **FR-007:** The DNS server shall support access control lists for query source filtering.
- **FR-008:** The DNS server shall support query logging for audit and debugging purposes.
- **FR-009:** The DNS server shall provide metrics endpoint for monitoring (Prometheus format).
- **FR-010:** Configuration shall be managed via configuration files, not environment variables alone.
- **FR-011:** The DNS server shall support health check endpoint for container orchestration.
- **FR-012:** **dnsdist** edge dispatcher shall apply rate limiting and consult compiled blocklists before forwarding queries.
- **FR-013:** **dnsdist** shall perform blocklist lookups against a compiled `.cdb` file and return NXDOMAIN for blocked domains.
- **FR-014:** **CoreDNS** shall cache DNS answers and serve internal zones defined in Corefile configuration.
- **FR-015:** **CoreDNS** shall forward cache misses to dnscrypt-proxy for upstream resolution.
- **FR-016:** **dnscrypt-proxy** shall perform encrypted ODoH (Oblivious DNS over HTTPS) lookups against upstream resolvers.
- **FR-017:** **dnscrypt-proxy** shall validate DNSSEC and enforce resolver policies defined in dnscrypt-proxy.toml.
- **FR-018:** **Blocklist compiler** shall convert curated source lists into the `blocklist.cdb` artifact for dnsdist.
- **FR-019:** All services shall run on the `homelab` Docker network with static IP assignments.
- **FR-020:** Health checks shall cover edge resolution, upstream privacy resolution, and blocklist availability.
- **FR-021:** Metrics shall be exposed for Prometheus/Grafana integration (dnsdist :8083, CoreDNS :9153).
- **FR-022:** **AdGuard Home** shall be the user-facing entrypoint providing DNS resolution, ad blocking, and web management UI.
- **FR-023:** **AdGuard Home** shall expose DNS service on port 53 to internal users on the homelab network.
- **FR-024:** **AdGuard Home** shall provide DHCP service for local network clients (optional, configurable).
- **FR-025:** **AdGuard Home** shall forward queries to dnsdist for the hardened DNS stack.
- **FR-026:** All DNS services shall be exposed to internal users via the homelab Docker network.
- **FR-027:** Local cluster (homelab) shall be the primary deployment, receiving active configuration updates.
- **FR-028:** Cloud cluster shall be exposed via Tailscale VPN for remote access.
- **FR-029:** Cloud cluster shall receive data synchronization from local cluster (configuration, blocklists, zone data).
- **FR-030:** Fallback: If AdGuard Home fails, dnsdist shall be directly accessible as backup entrypoint.
- **FR-031:** Fallback: If dnsdist fails, CoreDNS shall be directly accessible as backup entrypoint.
- **FR-032:** Fallback: If dnscrypt-proxy fails, CoreDNS shall fall back to direct upstream DNS (DoH/DoT).
- **FR-033:** Fallback: If local cluster is unreachable, cloud cluster shall serve cached responses.
- **FR-034:** Fallback: If cloud cluster loses sync, it shall operate with last known configuration.
- **FR-035:** Health checks shall verify each layer's availability and automatic fallback readiness.

## Non-Functional Requirements
- **NFR-001:** DNS queries shall be resolved within 100ms for cached entries.
- **NFR-002:** The DNS server shall handle at least 1000 queries per second.
- **NFR-003:** DNSSEC validation shall not increase query latency by more than 50ms.
- **NFR-004:** All configuration shall be validated on startup with clear error messages.
- **NFR-005:** The container shall run as non-root user (security best practice).
- **NFR-006:** TLS shall be supported for DNS over TLS (DoT) queries.
- **NFR-007:** The DNS server shall support graceful reload of configuration without dropping queries.
- **NFR-008:** Logs shall be structured JSON format for log aggregation compatibility.

## Technical Considerations (Optional)
- **DNS Stack Architecture:** Multi-component design with AdGuard Home as user entrypoint:
  - **AdGuard Home** (user entrypoint): DNS resolution, ad blocking, web UI, DHCP - port 53
  - **dnsdist** (edge dispatcher): Rate limiting, blocklist lookup, query forwarding - port 53
  - **CoreDNS**: Caching, internal zones, DNSSEC validation - port 53, metrics :9153
  - **dnscrypt-proxy**: ODoH encrypted upstream resolution - port 5053
  - **Blocklist compiler**: Generates blocklist.cdb from source lists
- **Multi-Cluster Deployment:**
  - **Local Cluster (Primary):** Homelab-based, receives active configuration updates
  - **Cloud Cluster (Secondary):** Hosted in cloud, exposed via Tailscale VPN, syncs from local
  - **Data Sync:** Configuration, blocklists, and zone data synchronized from local to cloud
- **Network Exposure:**
  - All services exposed to internal users on homelab Docker network
  - AdGuard Home listens on homelab network for local clients
  - Cloud cluster accessible via Tailscale tunnel
- **DNSSEC Keys:** Stored in mounted volumes for persistence across container restarts
- **Zones Database:** File-based zone definitions in Corefile for simplicity and version control
- **ACL Implementation:** Network-based ACLs (CIDR ranges) for query source filtering via dnsdist
- **Split-Horizon:** View-based configuration matching internal vs external client networks
- **Monitoring:** Prometheus metrics on dnsdist :8083, CoreDNS :9153, AdGuard Home :3000
- **Health:** HTTP health check endpoints per service
- **Protocol Support:** Current implementation uses ODoH (Oblivious DNS over HTTPS) for maximum privacy (score 24 in dns-protocols.md matrix)
- **Blocklist:** Compiled .cdb format queried synchronously during request evaluation

## Success Metrics
- DNS query success rate > 99.9%
- Average query resolution time < 100ms (cached)
- DNSSEC validation success rate for signed zones = 100%
- Container restart count = 0 (graceful operation)
- Configuration reload success rate = 100%

## Open Questions
- ~~Which specific DNS server software (CoreDNS vs BIND9) should be used?~~ **RESOLVED:** Stack uses dnsdist + CoreDNS + dnscrypt-proxy based on existing implementation.
- What is the expected query volume to properly size caching?
- Should DNS over HTTPS (DoH) be supported in addition to ODoH?
- What is the strategy for upstream DNS servers (ISP, Google 8.8.8.8, Cloudflare 1.1.1.1)?
- Should Tor transport be added as an additional privacy layer (see dns-protocols.md matrix)?
- Should additional protocol support (DoT, DNSCrypt v2 with relay) be implemented for compatibility?
- What is the preferred mechanism for syncing data from local to cloud cluster (rsync, API, database replication)?
- Should cloud cluster be active-active or active-passive with local cluster?
- What Tailscale ACLs are needed to expose cloud DNS to remote users?

## Dependencies
- Docker runtime environment
- Docker Compose or container orchestration (Kubernetes future)
- Upstream DNS servers for recursive resolution
- Certificate infrastructure for DNSSEC (or auto-generated keys)
- Tailscale VPN for cloud cluster access
- Data synchronization mechanism (rsync, custom sync service, or database replication)
- Shared storage or API for configuration sync between clusters

## Timeline / Milestones
- **M1 (Week 1):** Research and select DNS server software, create architecture diagram
- **M2 (Week 2):** Implement basic DNS server with caching and forwarding
- **M3 (Week 3):** Add local zone management functionality
- **M4 (Week 4):** Implement DNSSEC validation and signing
- **M5 (Week 5):** Add split-horizon and ACL features
- **M6 (Week 6):** Add monitoring, logging, and health checks
- **M7 (Week 7):** Add AdGuard Home as user entrypoint with web UI and ad blocking
- **M8 (Week 8):** Configure service exposure to internal users on homelab network
- **M9 (Week 9):** Set up cloud cluster deployment with Tailscale exposure
- **M10 (Week 10):** Implement data synchronization from local to cloud cluster
- **M11 (Week 11):** Testing in both dev and prod environments
- **M12 (Week 12):** Documentation and deployment automation

---
*Generated from PRD template*
