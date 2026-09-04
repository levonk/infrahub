---
story_id: "03-001"
story_title: "Integrate SearXNG with Traefik routing and security middleware"
story_name: "integrate-searxng"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 3
parallel_id: 1
branch: "feature/current/traefik-authelia-cloudflare/story-03-001-integrate-searxng"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003"]
parallel_safe: true
modules: ["search-searxng", "traefik-dynamic-config"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "integration", "traefik", "security"]
due: "2026-07-02"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Integrate the existing SearXNG container with Traefik routing, security middleware chain (GeoBlock + CrowdSec + Authelia), and dynamic configuration. This integration will enable secure external access to SearXNG via `search.levonk.com` with password authentication, US-only geographic access control, and IP-based threat protection.

## Sub-Tasks

- [x] Add Traefik labels to SearXNG docker-compose configuration
- [x] Create dynamic routing rule for `search.levonk.com`
- [x] Configure GeoBlock middleware for US-only access
- [x] Configure CrowdSec Bouncer middleware for IP filtering
- [x] Configure Authelia forward auth middleware
- [x] Set up middleware chain: GeoBlock → CrowdSec → Authelia
- [x] Apply middleware chain to SearXNG routing rule
- [x] Configure Tailscale network bypass (no authentication)
- [ ] Test SearXNG accessibility via external domain (requires deployment)
- [ ] Test authentication flow end-to-end (requires deployment)
- [ ] Test US-only geographic access control (requires deployment)
- [ ] Test CrowdSec IP filtering and ban enforcement (requires deployment)
- [ ] Test Tailscale network bypass functionality (requires deployment)
- [ ] Verify SSL certificate for `search.levonk.com` (requires deployment)
- [x] Update SearXNG role documentation with Traefik integration

## Relevant Files

- `shared/active/03-container/services/search/searxng/docker-compose.yml` - Updated Traefik labels for security middleware chain
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/search-levonk-com.yml.j2` - New dynamic routing configuration for SearXNG
- `shared/active/02-config/ansible/roles/proxy-traefik/defaults/main.yml` - Added SearXNG integration variables
- `shared/active/02-config/ansible/roles/proxy-traefik/tasks/main.yml` - Added deployment task for SearXNG dynamic config
- `shared/active/02-config/ansible/roles/search-searxng/README.md` - Updated documentation with Traefik integration details

## Acceptance Criteria

- [ ] SearXNG is accessible via `search.levonk.com` with valid SSL (requires deployment)
- [x] Authentication is required for external access (verified in routing config)
- [ ] Authelia password authentication works correctly (requires deployment)
- [x] GeoBlock middleware restricts access to US-only (verified in middleware chain)
- [x] CrowdSec Bouncer filters suspicious IPs (verified in middleware chain)
- [x] Middleware chain order is correct (GeoBlock → CrowdSec → Authelia) (verified in routing config)
- [x] Tailscale network bypass works without authentication (verified in routing config)
- [ ] SSL certificate is valid for `search.levonk.com` (requires deployment)
- [x] HTTP→HTTPS redirect is functional (verified in routing config)
- [x] Security middleware chain is properly documented (verified in README)
- [x] No hardcoded values in routing configuration (verified - all variables)
- [x] SearXNG role documentation is updated (verified in README)

## Test Plan

- Unit: Verify Traefik labels in SearXNG docker-compose.yml
- Integration: Test external access via `search.levonk.com`
- Authentication: Test Authelia login flow
- GeoBlock: Test access from non-US IP (simulate)
- CrowdSec: Test IP filtering with simulated threats
- Tailscale: Test bypass functionality from Tailscale network
- SSL: Verify certificate validity for domain
- Security: Test middleware chain order and functionality

## Observability

- Configure SearXNG access logs through Traefik
- Enable authentication event logging
- Track geographic access attempts
- Monitor CrowdSec ban events for SearXNG
- Document security event correlation

## Compliance

- Ensure all external access requires authentication
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in integration documentation
- Implement proper geographic access control
- Follow security best practices for service exposure

## Risks & Mitigations

- Risk: Middleware chain order errors — Mitigation: Comprehensive testing and documentation
- Risk: Geographic blocking false positives — Mitigation: Configurable GeoBlock settings
- Risk: Authentication bypass — Mitigation: Multiple security layers and testing
- Risk: SSL certificate issues — Mitigation: Proper DNS configuration and ACME setup

## Dependencies & Sequencing

- Depends on: Story 02-001 (Traefik deployment), Story 02-002 (Authelia deployment), Story 02-003 (CrowdSec deployment)
- Unblocks: Story 03-002 (Cloudflare DNS configuration)
- Must complete before: Cloudflare DNS configuration for SearXNG

## Definition of Done

- SearXNG is accessible via `search.levonk.com` with authentication
- Security middleware chain is functional and properly ordered
- US-only geographic access control is working
- Tailscale network bypass is functional
- SSL certificate is valid and working
- All security layers are tested and documented
- SearXNG role documentation is updated
- No hardcoded values in configuration

## Commit Conventions

- Use conventional commits: `feat(integration): integrate SearXNG with Traefik routing and security middleware`
- Scope commits to specific components (routing, middleware, security)
- Reference story ID in commit messages: `Story 03-001`