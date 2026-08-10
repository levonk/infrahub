---
slug: web-proxy-chain
title: "Web Proxy Chain — MITM → Privoxy → Varnish → Gost Egress"
date:
  created: "2026-08-10"
  status: "approved"
  priority: "high"
tech_context:
  package_manager: "devbox"
  build_system: "just"
  test_runner: "ansible-lint + ansible-playbook --syntax-check"
  linter: "ansible-lint"
  container_runtime: "docker"
  system_tools: "devbox run -- <command>"
  notes: "Ansible infrastructure project — no npm/pnpm/cargo. All container management via community.docker modules."
---

# PRD: Web Proxy Chain

## Problem

The infrahub project has a DNS proxy chain (AdGuard → dnsdist → CoreDNS →
Unbound → dnscrypt tiers) but no equivalent web proxy chain. The existing
`forward-proxy` role is a legacy docker-compose-era implementation with
hardcoded values, no `defaults/main.yml`, and no `infra_*` variable
references. The V2 design (`diagrams/proxy/web-proxy-flow-v2.mmd`) documented
a 4-layer chain (MITM → Privoxy → Varnish → Gost) but was never implemented
as Ansible roles.

## Solution

Implement the web proxy chain as a single `proxy-web` Ansible role with
multiple task files (matching the `dns` role pattern), deployed to both
Windows (dtop202311) and OCI (oci-cloud-server) via a `proxy-web-stack.yml`
playbook. The chain follows the revised design in
`diagrams/proxy/complete-web-proxy-chain.mmd`.

## Architecture

```
Client
  ↓ (explicit: port 3127/3128, transparent: nftables 80/443)
MITM Proxy (mitmproxy/mitmproxy) — HTTPS decryption, CA management
  ↓
Privoxy (vimagick/privoxy) — content filtering, header sanitization
  ↓
Varnish (varnish:latest) — HTTP cache, stale-while-revalidate, stale-if-error
  ↓ (cache miss)
Gost (locally-built) — egress multiplexer
  ↓                    ↓
Direct              Tor (shared with DNS chain)
  ↓                    ↓
Internet            Internet
```

See `diagrams/proxy/complete-web-proxy-chain.mmd` for the full diagram.

## Requirements

### Functional Requirements

**FR-1: MITM Proxy (L2)**
- Deploy mitmproxy/mitmproxy upstream image
- Run in mitmweb mode (web UI on port 8081)
- Listen on port 3127 (transparent policy) and 3128 (ad-blocking policy)
- Persistent CA certificate volume
- CA cert downloadable via Traefik at ca.<base>
- Healthcheck: HTTP probe to mitmweb UI

**FR-2: Privoxy (L3)**
- Deploy vimagick/privoxy upstream image
- Receive plaintext HTTP from MITM
- Apply content filtering based on entrypoint policy
- Header sanitization (referrer, user-agent, cookies)
- Internal port 8118 (not exposed to host)
- Healthcheck: TCP probe to port 8118

**FR-3: Varnish Cache (L4)**
- Deploy varnish:latest upstream image
- Custom VCL for forward proxy caching
- stale-while-revalidate via beresp.grace
- stale-if-error via VCL grace workaround
- tmpfs for /var/lib/varnish
- Port 6081 (bypass access)
- Healthcheck: HTTP probe

**FR-4: Gost Egress Multiplexer (L5)**
- Deploy locally-built image (localnet-base-alpine + gost 3.0.0-rc8)
- YAML config for egress chain routing
- Route .onion → Tor SOCKS5 (172.26.255.70:9050, shared with DNS chain)
- Route default → Direct (virtual node)
- Port 1080 (SOCKS5 bypass access)
- Healthcheck: SOCKS5 connectivity test

**FR-5: Dual-Platform Deployment**
- Linux/OCI: community.docker modules (deploy-linux.yml)
- Windows: SSH-tunneled Docker CLI (deploy-windows.yml)
- Both platforms deploy the full chain
- Config seeding via docker cp on Windows (matching DNS chain pattern)

**FR-6: Traefik Integration**
- Route mitmweb UI through Traefik with Authelia auth
- Route Varnish admin through Traefik
- Serve MITM CA cert for download at ca.<base>
- Dynamic config templates for proxy-web services

**FR-7: DNS Integration**
- All proxy services use the LocalNet DNS chain for resolution
- Services reference DNS chain service IPs (172.26.255.x)

### Non-Functional Requirements

**NFR-1: All ports and IPs must be infra_* variables**
- No hardcoded ports in task files
- No hardcoded IPs in task files
- All values in ports.yml and networks.yml

**NFR-2: Healthcheck string format**
- interval, timeout, start_period must be strings with unit suffix
- retries must be integer

**NFR-3: Community.docker modules only**
- No docker compose, no ansible.builtin.shell for container management
- Windows exception: SSH-tunneled Docker CLI (matching DNS chain)

**NFR-4: Service catalog**
- All services added to services.yml with source_repo
- Regenerate SERVICES.md after adding entries

**NFR-5: Build pipeline**
- Gost image registered in build-and-push-images.sh
- Built and pushed to local registry

## Implementation Scope

### Phase 1: Shared Infrastructure Schemas
- Add port variables to ports.yml (MITM, Privoxy, Varnish, Gost)
- Add network/IP variables to networks.yml (172.26.255.80-83)
- Add domain variables to domains.yml (ca.<base>, proxy dashboards)
- Add storage variables to storage.yml (CA volume, Varnish cache)

### Phase 2: Client Infrastructure Values
- Add levonk-specific overrides if needed
- Add DNS CNAME records for proxy domains
- Update services.yml with proxy-web service entries
- Regenerate SERVICES.md

### Phase 3: Build Pipeline (Gost only)
- Register Gost in build-and-push-images.sh
- Build and push localnet-proxy-gost image

### Phase 4: Vault Secrets
- No secrets needed for the proxy chain itself
- MITM CA is generated at runtime, not a vault secret

### Phase 5: Ansible Role
- Create proxy-web role (defaults, tasks, handlers, templates)
- Task files: mitm.yml, privoxy.yml, varnish.yml, gost.yml
- deploy-linux.yml and deploy-windows.yml
- Config templates: gost.yaml.j2, varnish-default.vcl.j2, privoxy-config.j2

### Phase 6: Traefik Routing
- Add dynamic config templates for proxy-web dashboards
- Route ca.<base> → MITM CA cert download
- Route proxy dashboards through Authelia

### Phase 7: Playbook + Inventory
- Create proxy-web-stack.yml playbook
- Wire to windows_docker_hosts and cloud_servers inventories
- Add just recipes

### Phase 8: Documentation
- Update AGENTS.md with proxy-web chain learnings
- Update SERVICES.md
- Reference complete-web-proxy-chain.mmd in role README

## Out of Scope

- Cloudflare WARP egress (DARK tier — documented, not deployed)
- nftables TPROXY configuration (host-level, separate playbook)
- Certificate pinning bypass logic
- Per-user egress routing (ExtAuth/identity router)
- Cross-cluster failover (web proxy is stateful — no failover)
