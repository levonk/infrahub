---
feature_id: "feat-202608222054"
slug: "hister-search-deploy"
title: "Deploy Hister Search Engine on hister.nl.levonk.com"
status: "ready"
created: "2026-08-22"
last-activity: "2026-08-22"
tech_context:
  package_manager: "devbox"
  build_system: "just"
  test_runner: "ansible-playbook --syntax-check / --check"
  linter: "ansible-lint"
  container_runtime: "Docker (Windows Docker Desktop via SSH-tunneled CLI)"
  ci_cd: "none (Ansible deployment)"
  system_tools: "devbox run -- <command>"
  binding_constraint: "Never use npm/npx/yarn. All shell interaction via devbox run -- rtk. Ansible vault edits are agent→user handoff only."
---

# PRD: Deploy Hister Search Engine on hister.nl.levonk.com

## Summary

Deploy Hister (https://github.com/asciimoo/hister), an open-source self-hosted
search engine for browsing history and personal documents, on the levonk
client infrastructure at `hister.nl.levonk.com`, behind Traefik with Authelia
SSO authentication.

## Background

Hister is the successor to SearXNG's personal search concept, built by asciimoo.
It provides a web UI for searching indexed content (browsing history, imported
documents, crawled websites). The service runs as a single Docker container
with SQLite storage and is configured via environment variables.

The levonk `nl` region (dtop202311, Windows Docker Desktop, X86) hosts services
on the `nl.levonk.com` subdomain zone. Existing nl services include
`start.nl.levonk.com` (Homepage), `start2.nl.levonk.com` (TraLa),
`npmjs.nl.levonk.com` (Verdaccio), `nixcache.nl.levonk.com` (Nix Cache),
`ci.nl.levonk.com` (Garnix CI).

## Goals

1. Deploy Hister as a Docker container on dtop202311 (Windows Docker Desktop)
2. Route traffic via Traefik (Windows) at `hister.nl.levonk.com`
3. Protect access with Authelia SSO forward-auth middleware
4. Use upstream Docker image (`ghcr.io/asciimoo/hister:latest`) — no local build
5. Follow all infrahub conventions: `infra_*` variable naming, no hardcoded
   ports/IPs, separate Ansible role, service catalog entry

## Non-Goals

- PostgreSQL backend (SQLite is sufficient for single-user personal search)
- Semantic search / vector embeddings (optional, disabled by default)
- Hister's own access_token auth (Authelia handles auth at the proxy layer)
- Multi-user mode (`user_handling`)
- Deployment to the OCI cloud server (cno region) — nl only for now

## Architecture

```
Internet → Cloudflare DNS (CNAME hister.nl.levonk.com → dtop202311.ts.net)
  → dtop202311 (Tailscale) → Traefik (Windows, port 80/443)
  → Authelia forward-auth (via OCI Tailscale, port 9091)
  → Hister container (port 4433, traefik-windows-network)
```

### Components

| Component | Technology | Location |
|-----------|-----------|----------|
| Hister container | `ghcr.io/asciimoo/hister:latest` | dtop202311 Docker Desktop |
| Traefik reverse proxy | `proxy_traefik_windows` role | dtop202311 |
| Authelia SSO | Authelia on OCI (via Tailscale) | oci-cloud-server |
| DNS | Cloudflare CNAME → Tailscale FQDN | Cloudflare |
| Ansible role | `search-hister` | shared/active/02-config/ansible/roles/ |

### Architecture Diagram

```mermaid
graph TD
    A[Internet] --> B[Cloudflare DNS]
    B -->|CNAME| C[dtop202311.tale-grouper.ts.net]
    C --> D[Traefik Windows :80/:443]
    D -->|Authelia forward-auth| E[Authelia on OCI via Tailscale :9091]
    D -->|authenticated| F[Hister Container :4433]
    F --> G[SQLite DB in data volume]
    F --> H[/hister/data volume]
```

## Requirements

### Functional Requirements

- **FR-1**: Hister web UI accessible at `https://hister.nl.levonk.com`
- **FR-2**: TLS certificate via Let's Encrypt (Cloudflare DNS-01 challenge)
- **FR-3**: Authelia SSO gates access before reaching Hister
- **FR-4**: Hister data persisted in a Docker named volume
- **FR-5**: Hister configured via environment variables (no config file)
- **FR-6**: HTTP→HTTPS redirect enforced by Traefik

### Non-Functional Requirements

- **NFR-1**: All ports defined as `infra_port_*` variables (no hardcoding)
- **NFR-2**: All domains defined as `infra_domain_*` variables
- **NFR-3**: All storage defined as `infra_storage_*` variables
- **NFR-4**: No secrets required (Authelia handles auth)
- **NFR-5**: Container runs as non-root (UID 1000, per upstream image default)
- **NFR-6**: Ansible role follows infrahub conventions (community.docker not
  available on Windows — use SSH-tunneled Docker CLI pattern)
- **NFR-7**: Service catalog entry includes `source_repo` field

### Constraints

- **C-1**: Windows Docker Desktop requires SSH-tunneled Docker CLI pattern
  (community.docker modules can't run on Windows)
- **C-2**: Container must join `traefik-windows-network` for Traefik routing
- **C-3**: Port 4433 must not conflict with existing allocations
- **C-4**: Upstream image supports AMD64 (dtop202311 is X86)

## Implementation Plan

### Phase 1: Infrastructure Schemas (shared defaults)

Add variable schemas to shared infrastructure files:
- `ports.yml`: `infra_port_search_hister_host`, `infra_port_search_hister_container`
- `domains.yml`: `infra_domain_search_hister`
- `storage.yml`: `infra_storage_hister_volume`

### Phase 2: Client Values + Service Catalog

Override shared defaults in levonk client infrastructure:
- `domains.yml`: `infra_domain_search_hister: "hister.nl.levonk.com"`
- Add DNS CNAME to Cloudflare DNS configuration
- Add service catalog entry to `services.yml` with `source_repo`
- Regenerate service catalogs

### Phase 3: Ansible Role

Create `search-hister` role:
- `defaults/main.yml` — reference `infra_*` variables with safe defaults
- `tasks/main.yml` — validate vars, dispatch to deploy-windows.yml
- `tasks/deploy-windows.yml` — SSH-tunneled Docker CLI pattern:
  - Pull image, create volume, deploy container, wait for health
- `handlers/main.yml` — restart handler
- `meta/main.yml` — Galaxy metadata
- `README.md` — role documentation

### Phase 4: Traefik Routing

Add Traefik dynamic config to `proxy_traefik_windows` role:
- Create `templates/dynamic/hister-nl.yml.j2` — HTTP/HTTPS routers with Authelia
- Add render + copy tasks to `proxy_traefik_windows/tasks/main.yml`
- Add network connect task for hister container
- Add hister defaults to `proxy_traefik_windows/defaults/main.yml`

### Phase 5: Playbook Integration

Add `search-hister` role to the Windows Docker deployment playbook.

## Acceptance Criteria

- [ ] `hister.nl.levonk.com` resolves via Cloudflare DNS (CNAME to Tailscale FQDN)
- [ ] Hister container running on dtop202311 with correct image and config
- [ ] Traefik routes HTTPS traffic to Hister with valid Let's Encrypt cert
- [ ] Authelia SSO challenges unauthenticated users before reaching Hister
- [ ] Hister data persisted in Docker named volume
- [ ] No hardcoded ports, IPs, or domains in any configuration file
- [ ] Service catalog entry exists with `source_repo` link
- [ ] Ansible syntax-check passes
- [ ] Ansible check-mode passes against windows-docker inventory

## References

- Research: `internal-docs/research/service/hister/hister-research.md`
- Implementation guide: `.agents/workflows/infrahub-add-new-service.md`
- Hister docs: https://hister.org/docs/docker
- Hister source: https://github.com/asciimoo/hister
- Existing nl service pattern: `proxy_traefik_windows` role
- Existing search role: `search-searxng` (for reference)
