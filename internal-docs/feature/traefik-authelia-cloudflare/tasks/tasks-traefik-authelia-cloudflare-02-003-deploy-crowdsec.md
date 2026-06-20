---
story_id: "02-003"
story_title: "Deploy CrowdSec security engine and bouncer"
story_name: "deploy-crowdsec"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 2
parallel_id: 3
branch: "feature/current/traefik-authelia-cloudflare/story-02-003-deploy-crowdsec"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-003", "01-005"]
parallel_safe: true
modules: ["security-crowdsec", "docker-compose"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "deploy", "crowdsec", "security"]
due: "2026-06-30"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Deploy CrowdSec security engine and CrowdSec Bouncer for Traefik integration. This deployment will provide IP-based threat protection, automated remediation, and security monitoring for the proxy stack. The system will acquire logs from Traefik, analyze them for threats, and enforce bans through the Traefik bouncer plugin.

## Sub-Tasks

- [ ] Deploy security-crowdsec role to OCI cloud server
- [ ] Deploy CrowdSec security engine container
- [ ] Deploy CrowdSec Bouncer container for Traefik
- [ ] Configure Traefik log acquisition sources
- [ ] Set up CrowdSec to Traefik log integration
- [ ] Configure default remediation profile (672h ban)
- [ ] Create custom remediation profiles for different threat levels
- [ ] Set up API token for bouncer communication
- [ ] Connect CrowdSec to traefik-network
- [ ] Configure volume mounts for SQLite database persistence
- [ ] Test CrowdSec container startup and health status
- [ ] Test bouncer communication with security engine
- [ ] Verify log acquisition from Traefik
- [ ] Test ban enforcement through Traefik
- [ ] Configure CrowdSec logging with JSON format

## Relevant Files

- `shared/active/02-config/ansible/roles/security-crowdsec/` - Role deployment
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Configuration variables
- `shared/active/03-container/services/security/crowdsec/` - CrowdSec service directory
- `shared/active/03-container/docker-compose.shared.yml` - Shared compose configuration
- `shared/active/02-config/ansible/playbooks/deploy-crowdsec.yml` - Deployment playbook

## Acceptance Criteria

- [ ] CrowdSec security engine container is running and healthy
- [ ] CrowdSec Bouncer container is running and healthy
- [ ] Traefik log acquisition is configured and working
- [ ] Default remediation profile (672h ban) is active
- [ ] Custom remediation profiles can be configured
- [ ] API token for bouncer communication is secure
- [ ] CrowdSec is connected to traefik-network
- [ ] SQLite database persists across container restarts
- [ ] Bouncer successfully communicates with security engine
- [ ] Log acquisition from Traefik is functional
- [ ] Ban enforcement through Traefik is working
- [ ] Logging is configured with JSON format
- [ ] No hardcoded API tokens in configuration

## Test Plan

- Unit: `docker ps` to verify CrowdSec and Bouncer containers
- Integration: Test log acquisition from Traefik
- Communication: Test bouncer to security engine communication
- Remediation: Test ban enforcement with simulated threats
- Persistence: Test database persistence after container restart
- Security: Verify API token is properly secured

## Observability

- Configure CrowdSec security event logs with JSON format
- Enable CrowdSec metrics endpoint for monitoring
- Set up log aggregation for CrowdSec container logs
- Document ban event logging for security auditing
- Track security engine performance and resource usage

## Compliance

- Ensure API tokens are stored in Ansible vault
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in deployment documentation
- Implement proper data retention policies for ban database
- Follow security best practices for threat detection

## Risks & Mitigations

- Risk: Log acquisition failures — Mitigation: Proper error handling and fallback
- Risk: Bouncer communication failures — Mitigation: Retry logic and health checks
- Risk: Database corruption — Mitigation: Volume persistence and backup strategy
- Risk: False positive bans — Mitigation: Configurable remediation profiles
- Risk: API token exposure — Mitigation: Vault storage and access controls

## Dependencies & Sequencing

- Depends on: Story 01-003 (security-crowdsec role), Story 01-005 (config management)
- Unblocks: Story 03-001 (SearXNG integration)
- Must complete before: Any service integration requiring IP security

## Definition of Done

- CrowdSec security engine is deployed and running on OCI server
- CrowdSec Bouncer is deployed and communicating with security engine
- Traefik log acquisition is functional
- Remediation profiles are configured and active
- API token is properly secured in vault
- Database persistence is configured
- Logging and monitoring are configured
- Documentation is updated with deployment notes
- No hardcoded API tokens in any configuration

## Commit Conventions

- Use conventional commits: `feat(deploy): deploy CrowdSec security engine and Traefik bouncer`
- Scope commits to specific components (security engine, bouncer, log acquisition)
- Reference story ID in commit messages: `Story 02-003`