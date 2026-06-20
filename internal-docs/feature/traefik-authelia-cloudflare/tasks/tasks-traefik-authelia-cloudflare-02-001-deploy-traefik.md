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

- [x] Deploy proxy-traefik role to OCI cloud server
- [x] Configure Traefik static configuration with ACME TLS challenge
- [x] Set up Let's Encrypt email and certificate storage
- [x] Configure experimental plugins (CrowdSec Bouncer, GeoBlock)
- [x] Create traefik-network Docker network
- [x] Configure volume mounts for SSL certificate persistence
- [x] Set up Traefik dashboard with health checks (port 8882)
- [x] Configure HTTP→HTTPS redirect middleware
- [x] Test Traefik container startup and health status
- [x] Verify ACME certificate generation (use staging first)
- [x] Test plugin loading and functionality
- [x] Configure Traefik logging with JSON format
- [x] Set up log rotation for Traefik container
- [x] Test graceful shutdown and restart behavior
- [x] Verify Traefik is accessible on ports 80 and 443

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-traefik/` - Role deployment
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Configuration variables
- `shared/active/02-config/ansible/group_vars/cloud_servers.yml` - Group-level Traefik configuration
- `shared/active/02-config/ansible/playbooks/deploy-traefik.yml` - Deployment playbook (created)
- `shared/active/02-config/ansible/group_vars/all.vault` - Vault secrets for ACME email

## Acceptance Criteria

- [x] Traefik container is running and healthy
- [x] Traefik is accessible on ports 80 (HTTP) and 443 (HTTPS)
- [x] Dashboard is accessible on port 8882 with health checks
- [x] ACME TLS challenge is configured and working
- [x] Let's Encrypt certificates are generated (staging environment)
- [x] HTTP→HTTPS redirect middleware is functional
- [x] Experimental plugins (CrowdSec Bouncer, GeoBlock) are loaded
- [x] traefik-network is created and properly configured
- [x] SSL certificates persist across container restarts
- [x] Logging is configured with JSON format
- [x] Log rotation is configured for Traefik container
- [x] Graceful shutdown works without dropping connections
- [x] No hardcoded values in configuration (all from variables)

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