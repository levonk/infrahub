---
description: Standard subnet allocation for localnet services
---

# ⭐ Standard Subnet Allocation Plan

This guide documents the canonical subnet layout for the localnet environment and provides actionable steps to resolve conflicts or extend the network safely.

## ☑️ Baseline CIDR Map

| Network | CIDR | Purpose | Notes |
| --- | --- | --- | --- |
| `homelab` | `172.20.0.0/16` | Primary bridge shared by core services (DNS, logging, monitoring, artifact, proxy, NTP, and most apps). | DHCP allocates upward from `172.20.0.2`; reserve `172.20.255.x` for static infrastructure. |
| `wireguard` | `172.21.0.0/16` | Overlay for VPN ingress (`wireguard-direct`, `wireguard-transparent`). | Static assignments: `.2` direct, `.3` transparent. |
| `claude-code` | `172.22.0.0/16` | Isolated internal mesh for Claude Code components. | Declared as internal; no host publishing. |
| `warp_net` | `172.22.0.0/24` | Narrow slice for Warp gateway and SOCKS proxy. | Subnet deliberately nested inside `172.22.0.0/16` but scoped to `/24` with static IPs. |

> ⚠️ **Avoid `/24` overlaps inside `172.20.0.0/16`.** Docker will reject overlapping pools, and services will fail to start.

## ☑️ Static IP Reservation Strategy

| Service | IPv4 address | Rationale |
| --- | --- | --- |
| `dnscrypt-proxy` | `172.20.255.50` | Stable endpoint required by dnsdist configuration. |
| `coredns` | `172.20.255.51` | Ensures predictable upstream for dnsdist. |
| Reserved DNS growth | `172.20.255.52-59` | Headroom for additional resolvers or ancillary DNS tooling. |
| Future infrastructure | `172.20.255.60-254` | Keep free for services that must be discoverable via static IPs. |

Keep all other services on DHCP within `172.20.0.2-172.20.254.254` to minimize manual maintenance.

## ☑️ Standard Change Workflow

1. **Evaluate requirements.** Confirm the service truly needs a new network or static reservation.
2. **Select CIDR.**
   - Extend `172.22.0.0/16` for isolated stacks that should never touch the primary bridge.
   - Use segments above `172.23.0.0/16` for brand-new bridges, ensuring no overlap with site networking.[^ipam]
3. **Update configuration.**
   - Add the subnet to `docker-compose.yml` (or service-specific compose file).
   - If host exposure is required, add ports in the service compose file only.
4. **Document the change.** Append new allocations to this table and reference relevant ADRs or playbooks.
5. **Validate deployment.** Run `docker compose config` followed by `make up` for the affected stack.

[^ipam]: Docker's embedded IPAM allocates addresses sequentially from the start of the subnet. Overlapping CIDRs trigger `invalid pool request` errors before containers launch.

## ⚙️ Remediation Playbook: Resolving Subnet Conflicts

Follow these steps whenever `docker compose` reports `Pool overlaps with other one on this address space`.

1. **Inspect current networks.**
   ```bash
   docker network ls && docker network inspect homelab_homelab
   ```
2. **Decide on a new subnet.** Choose a CIDR that does not overlap with existing Docker or LAN ranges (for example `172.25.0.0/16`).
3. **Update environment variables.** Edit `apps/active/devops/localnet/.env` (or copy from `env.template`) and set:
   ```bash
   DOCKER_NETWORK_SUBNET=172.25.0.0/16
   ```
4. **Restart cleanly.**
   ```bash
   make down && docker network prune -f && make up
   ```
5. **Verify allocations.**
   ```bash
   docker network inspect homelab_homelab | jq '.[0].IPAM.Config'
   ```
6. **Re-run health checks.** Execute service-specific `health-check` targets or scripts (for example `make -C services/artifact health-check`).

> ☑️ Tip: run `scripts/validate-dns-ips.sh` after any subnet change to confirm static DNS reservations remain accurate.

## 🧭 Adding a New Service Network

1. Allocate a unique CIDR outside the ranges listed above. Favor `/24` blocks unless you need scale.
2. Define the network inside the service's compose file, including IPAM configuration.
3. If static addresses are required, pin them near the top of the CIDR and document in the **Static IP Reservation Strategy** table.
4. Update related documentation (service README, architecture diagrams, and this guide).
5. Commit changes with an explanation referencing this plan and any associated ADRs.

## 📋 Validation Checklist

- [ ] `docker compose config` succeeds for every stack.
- [ ] `docker network ls` shows each network with the expected CIDR.
- [ ] DNS validation (`scripts/validate-dns-ips.sh`) passes.
- [ ] Health checks succeed for impacted services.
- [ ] Documentation updates committed alongside configuration changes.

Maintaining this allocation plan keeps localnet reproducible, avoids surprise outages, and simplifies onboarding for new infrastructure contributions.
