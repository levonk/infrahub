---
modeline: "vim: set ft=markdown:"
title: "ADR: NetBird Cloud Control Plane with Docker Deployment"
adr-id: "adr-20250524001"
slug: "netbird-cloud-controlplane"
url: "https://github.com/levonk/localnet/blob/main/shared/active/03-container/internal-docs/adr/adr-001-netbird-cloud-controlplane.md"
synopsis: "Decision to use NetBird as the primary zero-trust networking platform with a cloud-hosted control plane running in Docker containers, including management, signal, and TURN/relay services."
author: "https://github.com/levonk"
date-created: "2025-05-24"
date-updated: "2025-05-24"
date-review: "2025-11-24"
date-triggers: ["2025-05-24"]
version: "1.0.0"
status: "accepted"
aliases: []
tags: [doc/architecture/adr, vpn, zero-trust, cloud-infrastructure, docker, homelab, netbird, networking, tailscale, wireguard, cloud, security, routing, nat-traversal]
supersedes: []
superseded-by: []
related-to: []
scope:
  impact-scope: [networking, vpn, zero-trust, cloud-infrastructure, docker, homelab]
  excluded-scope: [application-layer-services, storage, databases]
---

# Decision Record: NetBird Cloud Control Plane

## Context

The homelab infrastructure requires a secure, zero-trust networking solution that:
- Provides secure remote access to homelab services from anywhere
- Supports multi-platform clients (macOS, Windows, Linux, iOS, Android)
- Enables site-to-site networking between homelab, cloud VPS, and mobile devices
- Offers identity-based access control and policy enforcement
- Provides DNS management and routing capabilities
- Maintains high availability and reliability

The environment includes Proxmox hypervisor, OCI cloud VPS, macOS workstation, Windows workloads, OpenWrt/OPNsense routers, and mobile devices.

## Constraints

- Must support self-hosted control plane for data sovereignty
- Must work across all platforms in the homelab (Linux, macOS, Windows, mobile)
- Must provide zero-trust semantics with identity-based access
- Must be containerizable for easy deployment and management
- Must have active development and healthy community
- Must support NAT traversal and relay fallback for challenging network conditions
- Must integrate with existing Docker-based infrastructure

## Decision

Use NetBird as the primary zero-trust networking platform with a cloud-hosted control plane deployed in Docker containers on an OCI VPS. The deployment includes:
- NetBird gateway agent running on the cloud host
- SSH server, mosh, and Tailscale for backup connectivity on the cloud host
- Docker containers for:
  1. NetBird management service (control plane)
  2. NetBird signal service (NAT traversal helper)
  3. NetBird relay/TURN service (fallback transport)
- A VM on the cloud server for AI agent workloads with its own NetBird gateway agent

## Rationale

NetBird was chosen over Headscale and Netmaker based on the following analysis:

### NetBird vs Headscale

**Headscale** is a self-hosted coordination server for Tailscale clients. It provides the Tailscale UX and client ecosystem but only includes the coordination plane. It lacks built-in relay servers, DNS resolver, and policy engine beyond Tailscale ACLs. It also limits to a single OIDC provider.

**NetBird** is a complete self-hosted zero-trust platform with full management service (state, ACLs, routes, DNS, logging), signal service (NAT traversal), relay/TURN service (fallback transport), DNS control with internal DNS patterns, identity and onboarding with multi-IdP support, and multi-network management.

**Decision:** NetBird provides a complete platform rather than just a coordination layer, reducing the need to assemble multiple components.

### NetBird vs Netmaker

**Netmaker** is an SD-WAN engine focused on Linux with strong Linux support (kernel WireGuard), but limited macOS/Windows support (user-space WireGuard), no native mobile clients, and no identity-based zero-trust features. Development velocity is slower (3 weeks between releases) with lower community engagement (11.6k stars, 641 forks) and slower PR merging.

**NetBird** is a modern zero-trust platform with excellent cross-platform support (Linux, macOS, Windows, iOS, Android), native clients for all platforms, full identity model with multi-IdP support, device posture checks and per-device ACLs, active development (5 days between releases), strong community engagement (25.4k stars, 1.4k forks), and healthy PR lifecycle with fast merges. Popularity is explosive (+168.8% stars in past year).

**Decision:** NetBird's cross-platform support, zero-trust features, and active development make it superior for a multi-OS homelab environment.

### Strategic Considerations

NetBird's missing features (advanced routing modes, multi-network topologies) are incremental engineering enhancements, while Netmaker's missing features (identity system, policy engine, zero-trust model) require architectural reinvention. NetBird has a smaller gap to close to match Netmaker's networking features than Netmaker has to close to reach NetBird's zero-trust capabilities.

## Technical Approach

### Cloud Host Architecture

**Host-Level Services:**
- NetBird gateway agent (connects homelab to NetBird mesh)
- SSH server for direct administrative access
- mosh for reliable remote shell sessions
- Tailscale agent as backup connectivity option

**Docker Containers:**
1. **NetBird Management Service** - Handles peer registration, state management, ACLs, routes, DNS
2. **NetBird Signal Service** - Facilitates NAT traversal between peers, coordinates WebRTC signaling
3. **NetBird Relay/TURN Service** - Provides fallback relay when direct connections fail

**Virtual Machine:**
- Dedicated VM for AI agent workloads
- Separate NetBird gateway agent instance
- Isolated from host-level services

### Network Topology

```
Homelab (Proxmox)
├── NetBird Gateway Agent
├── Multiple VMs (services, GPU nodes, etc.)
└── Router (OpenWrt/OPNsense)

Cloud VPS (OCI)
├── Host: NetBird Gateway Agent
├── Host: SSH Server
├── Host: mosh
├── Host: Tailscale (backup)
├── Docker: NetBird Management Service
├── Docker: NetBird Signal Service
├── Docker: NetBird Relay/TURN Service
└── VM: AI Agent with NetBird Gateway Agent

Client Devices
├── macOS Workstation - NetBird Client
├── Windows Gaming/VM - NetBird Client
├── iOS Mobile - NetBird Client
└── Android Mobile - NetBird Client
```

### Configuration Management

All IP addresses and port numbers will be defined as variables in group_vars/all.yml or .env files, following localnet project configuration rules. No hardcoded IPs or ports in Docker Compose or Ansible configurations.

## Affected Components

- **Network Infrastructure**: VPN, routing, DNS configuration
- **Cloud VPS**: OCI instance configuration and Docker deployment
- **Homelab**: Proxmox VMs, router configuration
- **Client Devices**: NetBird client installation on macOS, Windows, mobile
- **Configuration Management**: Ansible playbooks, Docker Compose files
- **Monitoring**: Logging and metrics for NetBird services
- **Backup Strategy**: Tailscale as backup connectivity option

## Consequences

### Positive

- **Unified Identity**: Single identity model across all platforms and devices
- **Zero-Trust Security**: Identity-based access control with per-device ACLs
- **Cross-Platform Support**: Native clients for Linux, macOS, Windows, iOS, Android
- **Self-Hosted Control**: Full control over control plane and data
- **Active Development**: Frequent updates and active community (25.4k stars)
- **Built-in DNS**: Internal DNS resolution without additional services
- **NAT Traversal**: Signal and TURN services ensure connectivity in challenging networks
- **Backup Connectivity**: Tailscale provides fallback if NetBird has issues
- **Scalability**: Docker-based deployment allows easy scaling and updates
- **Policy Engine**: Built-in ACL and policy management

### Negative

- **Complexity**: Multiple Docker services to manage (management, signal, relay)
- **Resource Usage**: Control plane services consume cloud VPS resources
- **Learning Curve**: New platform to learn and maintain
- **Single Point of Failure**: Cloud VPS becomes critical infrastructure (mitigated by Tailscale backup)
- **Migration Effort**: Need to migrate from existing VPN solution (if any)

### Neutral

- **Docker Dependency**: Requires Docker runtime on cloud VPS (already part of infrastructure)
- **Cloud Cost**: Additional OCI VPS cost for control plane services
- **Maintenance Responsibility**: Self-hosted means responsible for updates and security

## Alternatives Considered

### Option A: Headscale with Tailscale Clients

**Pros:** Familiar Tailscale UX and client ecosystem, proven technology, coordination plane only (simpler deployment)

**Cons:** No built-in relay servers (would need separate DERP deployment), no built-in DNS resolver, limited to single OIDC provider, no built-in policy engine, less comprehensive platform than NetBird

**Decision:** Rejected due to incomplete feature set and need for additional components.

### Option B: Netmaker

**Pros:** Strong Linux support with kernel WireGuard, mature SD-WAN features, multi-network topologies

**Cons:** Limited macOS/Windows support (user-space WireGuard), no native mobile clients, no identity-based zero-trust features, slower development velocity (3 weeks between releases), lower community engagement (11.6k stars vs 25.4k for NetBird), slower PR merging and review process, would require architectural reinvention to add zero-trust features

**Decision:** Rejected due to poor cross-platform support, lack of zero-trust features, and slower development.

### Option C: Tailscale SaaS

**Pros:** No control plane management, excellent UX and client ecosystem, professional support available

**Cons:** Not self-hosted (violates data sovereignty requirement), monthly cost for control plane, less control over infrastructure, vendor lock-in

**Decision:** Rejected due to self-hosting requirement.

## Rollout / Migration

1. **Phase 1: Cloud VPS Setup** - Provision OCI VPS, install Docker and Docker Compose, configure firewall, set up SSH/mosh/Tailscale
2. **Phase 2: NetBird Control Plane Deployment** - Deploy management, signal, and relay containers, configure SSL certificates, set up DNS
3. **Phase 3: Gateway Agent Installation** - Install gateway agents on cloud host and homelab Proxmox host, configure peering
4. **Phase 4: Client Rollout** - Install NetBird clients on all platforms, configure identity provider
5. **Phase 5: AI Agent VM Setup** - Create VM on cloud VPS with separate NetBird gateway agent
6. **Phase 6: Migration and Cutover** - Migrate existing services, update DNS/routing, decommission old VPN

## To Investigate

- Optimal resource allocation for Docker containers (CPU, RAM, storage)
- SSL/TLS certificate management for control plane services
- Backup and restore procedures for NetBird management database
- Monitoring and alerting setup for NetBird services
- High availability configuration (multiple control plane instances?)
- Integration with existing authentication providers (OIDC setup)
- Performance testing with expected peer count
- Network throughput testing between homelab and cloud

## Validation

The decision will be evaluated based on:
- Successful deployment of all three Docker services
- Successful peering between homelab and cloud gateways
- Successful client connections from all platforms (macOS, Windows, iOS, Android)
- Reliable NAT traversal in various network conditions
- Performance benchmarks meeting or exceeding current VPN solution
- Uptime and reliability metrics over 90-day period
- Ease of management and configuration

## Review Schedule

This decision should be reviewed in 6 months (November 2025) or earlier if:
- Major NetBird release introduces breaking changes
- Significant issues arise with deployment or reliability
- Better alternatives emerge in the zero-trust networking space
- Infrastructure requirements change significantly

## Notes

- Current state: This is the initial ADR for NetBird adoption
- Implementation details will be documented in project-specific documentation
- Docker Compose configurations will follow localnet variable rules (no hardcoded IPs/ports)
- Ansible playbooks will be created for automated deployment
- Monitoring and logging will be integrated with existing infrastructure

## References

- NetBird GitHub: https://github.com/netbirdio/netbird
- NetBird Documentation: https://docs.netbird.io
- NetBird vs Headscale Comparison: https://routeharden.com/blog/netbird-vs-headscale-for-teams
- Headscale GitHub: https://github.com/juanfont/headscale
- Netmaker GitHub: https://github.com/gravitl/netmaker
- Localnet Project: https://github.com/levonk/localnet

<!-- vim: set ft=markdown: -->
