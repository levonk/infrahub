---
story: 01-005
name: traefik-routing
status: "Todo"
depends: ["01-002", "01-004"]
branch: feature/current/verdaccio-dual-deployment/story-01-005-traefik-routing
---

# Story 01-005: Traefik Dynamic Config Templates

## Goal

Create Traefik dynamic config templates for routing both verdaccio domains with Authelia SSO for web UI and bypass for npm CLI endpoints.

## Tasks

1. **Template for cno** — `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/npmjs-cno-levonk-com.yml.j2`
   - Router: `Host(`{{ verdaccio_domain_cno }}`)` on websecure entrypoint
   - Middleware: authelia (for web UI)
   - Service: loadBalancer → `http://{{ verdaccio_container_name }}:{{ verdaccio_container_port }}` (same machine, container network)
   - HTTP → HTTPS redirect on web entrypoint
   - TLS: certResolver letsencrypt
   - **npm CLI bypass**: Add a separate router for npm API endpoints that skips Authelia:
     - Rule: `Host(`{{ verdaccio_domain_cno }}`) && PathPrefix(`/-/`)` — npm CLI endpoints
     - No authelia middleware (npm CLI uses htpasswd tokens directly)

2. **Template for nl** — `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/npmjs-nl-levonk-com.yml.j2`
   - Same as cno but cross-machine routing (QM pattern):
   - Service: loadBalancer → `http://{{ infra_tailscale_fqdn_windows_docker | default('dtop202311.tale-grouper.ts.net') }}:{{ verdaccio_host_port }}`
   - Same Authelia + npm CLI bypass pattern

3. **Wire templates into traefik role** — ensure the templates are included in the traefik role's tasks/main.yml template loop

## Acceptance Criteria

- [ ] Both template files created in proxy-traefik/templates/dynamic/
- [ ] cno template routes to container on same machine
- [ ] nl template routes to Windows host via Tailscale FQDN (cross-machine)
- [ ] Web UI behind Authelia middleware
- [ ] npm CLI endpoints (`/-/`) bypass Authelia
- [ ] HTTP → HTTPS redirect configured
- [ ] TLS with letsencrypt certResolver
- [ ] No hardcoded IPs or domains — all use infra_* / verdaccio_* variables

## Implementation Guide

See `.agents/workflows/infrahub-add-new-service.md` Phase 6 (Traefik Routing).
Reference template: `proxy-traefik/templates/dynamic/qm-levonk-com.yml.j2` (cross-machine routing pattern).
