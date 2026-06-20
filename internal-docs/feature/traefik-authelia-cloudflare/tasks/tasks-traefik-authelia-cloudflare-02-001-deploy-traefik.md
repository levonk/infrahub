---
story_id: "02-001"
story_title: "Deploy Traefik with ACME and plugins"
story_name: "deploy-traefik"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 2
parallel_id: 1
branch: "feature/current/traefik-authelia-cloudflare/story-02-001-deploy-traefik"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-005"]
parallel_safe: true
modules: ["proxy-traefik", "docker-compose"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "deploy", "traefik", "security"]
due: "2026-06-30"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Deploy Traefik reverse proxy container with ACME/Let's Encrypt configuration, experimental plugins (CrowdSec Bouncer v1.4.4 and GeoBlock v0.3.3), and integration with the existing proxy infrastructure. This deployment will serve as the secure entry point for all services, handling SSL termination, HTTP→HTTPS redirects, and security middleware chain orchestration.

## Sub-Tasks

- [ ] Deploy proxy-traefik role to OCI cloud server
- [ ] Configure Traefik static configuration with ACME TLS challenge
- [ ] Set up Let's Encrypt email and certificate storage
- [ ] Configure experimental plugins (CrowdSec Bouncer, GeoBlock)
- [ ] Create traefik-network Docker network
- [ ] Configure volume mounts for SSL certificate persistence
- [ ] Set up Traefik dashboard with health checks (port 8882)
- [ ] Configure HTTP→HTTPS redirect middleware
- [ ] Test Traefik container startup and health status
- [ ] Verify ACME certificate generation (use staging first)
- [ ] Test plugin loading and functionality
- [ ] Configure Traefik logging with JSON format
- [ ] Set up log rotation for Traefik container
- [ ] Test graceful shutdown and restart behavior
- [ ] Verify Traefik is accessible on ports 80 and 443

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-traefik/` - Role deployment
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Configuration variables
- `shared/active/03-container/services/proxy/traefik/` - Traefik service directory
- `shared/active/03-container/docker-compose.shared.yml` - Shared compose configuration
- `shared/active/02-config/ansible/playbooks/deploy-traefik.yml` - Deployment playbook

## Acceptance Criteria

- [ ] Traefik container is running and healthy
- [ ] Traefik is accessible on ports 80 (HTTP) and 443 (HTTPS)
- [ ] Dashboard is accessible on port 8882 with health checks
- [ ] ACME TLS challenge is configured and working
- [ ] Let's Encrypt certificates are generated (staging environment)
- [ ] HTTP→HTTPS redirect middleware is functional
- [ ] Experimental plugins (CrowdSec Bouncer, GeoBlock) are loaded
- [ ] traefik-network is created and properly configured
- [ ] SSL certificates persist across container restarts
- [ ] Logging is configured with JSON format
- [ ] Log rotation is configured for Traefik container
- [ ] Graceful shutdown works without dropping connections
- [ ] No hardcoded values in configuration (all from variables)

## Test Plan

- Unit: `docker ps` to verify Traefik container status
- Integration: Test HTTP→HTTPS redirect with curl
- SSL: Verify ACME certificate generation with staging environment
- Plugin: Test plugin loading via Traefik dashboard
- Health: Check Traefik health endpoint on port 8882
- Restart: Test graceful shutdown and container restart
- Logs: Verify JSON logging format and log rotation

## Observability

- Configure Traefik access logs with JSON format
- Enable Traefik metrics endpoint for monitoring
- Set up log aggregation for Traefik container logs
- Document certificate expiration monitoring
- Track plugin health and performance metrics

## Compliance

- Ensure SSL certificates are managed via Let's Encrypt
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in deployment documentation
- Implement proper certificate renewal monitoring
- Follow security best practices for SSL configuration

## Risks & Mitigations

- Risk: ACME rate limiting — Mitigation: Use staging environment for testing
- Risk: Plugin version conflicts — Mitigation: Pin specific versions in configuration
- Risk: Certificate generation failures — Mitigation: Proper DNS configuration and testing
- Risk: Port conflicts — Mitigation: Variable-driven port configuration

## Dependencies & Sequencing

- Depends on: Story 01-001 (proxy-traefik role), Story 01-005 (config management)
- Unblocks: Story 02-002 (Authelia deployment), Story 03-001 (SearXNG integration)
- Must complete before: Any service integration work

## Definition of Done

- Traefik container is deployed and running on OCI server
- ACME configuration is working with staging environment
- Experimental plugins are loaded and functional
- HTTP→HTTPS redirect is working
- SSL certificates persist across container restarts
- Logging and monitoring are configured
- Documentation is updated with deployment notes
- No hardcoded values in any configuration

## Commit Conventions

- Use conventional commits: `feat(deploy): deploy Traefik with ACME and experimental plugins`
- Scope commits to specific components (ACME, plugins, networking)
- Reference story ID in commit messages: `Story 02-001`