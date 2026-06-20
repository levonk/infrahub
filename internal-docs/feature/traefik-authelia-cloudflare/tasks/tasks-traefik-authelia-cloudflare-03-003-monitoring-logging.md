---
story_id: "03-003"
story_title: "Set up monitoring and logging"
story_name: "monitoring-logging"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 3
parallel_id: 3
branch: "feature/current/traefik-authelia-cloudflare/story-03-003-monitoring-logging"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001", "02-002", "02-003"]
parallel_safe: true
modules: ["docker-logging", "monitoring"]
priority: "SHOULD"
risk_level: "medium"
tags: ["feat", "monitoring", "logging", "observability"]
due: "2026-07-02"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Set up comprehensive monitoring and logging for the Traefik proxy stack components (Traefik, Authelia, CrowdSec). This task will configure JSON logging, log rotation, metrics endpoints, and log aggregation to ensure observability for troubleshooting, security auditing, and performance monitoring of the entire proxy infrastructure.

## Sub-Tasks

- [ ] Configure JSON logging for Traefik container
- [ ] Configure JSON logging for Authelia container
- [ ] Configure JSON logging for CrowdSec containers
- [ ] Set up log rotation for all proxy stack containers
- [ ] Configure Traefik metrics endpoint
- [ ] Configure Authelia metrics endpoint
- [ ] Configure CrowdSec metrics endpoint
- [ ] Set up log aggregation (if centralized logging exists)
- [ ] Create log shipping configuration to central logging system
- [ ] Configure log retention policies
- [ ] Set up monitoring dashboards for proxy stack metrics
- [ ] Configure alerts for critical security events
- [ ] Document log locations and formats
- [ ] Test log aggregation and shipping
- [ ] Verify metrics endpoints are accessible

## Relevant Files

- `shared/active/03-container/services/proxy/traefik/logging.yml` - Traefik logging configuration
- `shared/active/03-container/services/auth/authelia/logging.yml` - Authelia logging configuration
- `shared/active/03-container/services/security/crowdsec/logging.yml` - CrowdSec logging configuration
- `shared/active/03-container/docker-compose.shared.yml` - Shared logging configuration
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/` - Traefik logging templates
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/` - Authelia logging templates
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/` - CrowdSec logging templates

## Acceptance Criteria

- [ ] All proxy stack containers use JSON logging format
- [ ] Log rotation is configured for all containers
- [ ] Traefik metrics endpoint is accessible and functional
- [ ] Authelia metrics endpoint is accessible and functional
- [ ] CrowdSec metrics endpoint is accessible and functional
- [ ] Log aggregation is configured (if central logging exists)
- [ ] Log retention policies are implemented
- [ ] Monitoring dashboards display proxy stack metrics
- [ ] Alerts are configured for critical security events
- [ ] Log locations and formats are documented
- [ ] Log shipping to central system is tested
- [ ] No hardcoded values in logging configuration

## Test Plan

- Unit: Verify JSON logging format for each container
- Integration: Test log aggregation and shipping
- Metrics: Test metrics endpoint accessibility
- Dashboards: Verify monitoring dashboards display data
- Alerts: Test alert configuration with simulated events
- Retention: Verify log rotation and retention policies
- Performance: Monitor logging overhead on system resources

## Observability

- Configure centralized log aggregation for all proxy components
- Set up metrics collection and monitoring dashboards
- Implement alerting for security events and system health
- Document log formats and retention policies
- Track authentication events and security incidents
- Monitor SSL certificate expiration and renewal

## Compliance

- Ensure log retention policies comply with security requirements
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in monitoring documentation
- Implement proper log security and access controls
- Follow security best practices for log management

## Risks & Mitigations

- Risk: High logging overhead — Mitigation: Optimize log levels and sampling
- Risk: Log aggregation failures — Mitigation: Local log persistence and fallback
- Risk: Metrics endpoint exposure — Mitigation: Proper access controls and network isolation
- Risk: Log storage exhaustion — Mitigation: Proper retention policies and monitoring

## Dependencies & Sequencing

- Depends on: Story 02-001 (Traefik deployment), Story 02-002 (Authelia deployment), Story 02-003 (CrowdSec deployment)
- Unblocks: Story 03-004 (End-to-end testing and documentation)
- Must complete before: Production deployment

## Definition of Done

- All proxy stack components have JSON logging configured
- Log rotation is configured and working
- Metrics endpoints are accessible and functional
- Log aggregation is configured (if applicable)
- Monitoring dashboards are displaying data
- Alerts are configured for critical events
- Documentation is complete and accurate
- No hardcoded values in logging configuration

## Commit Conventions

- Use conventional commits: `feat(monitoring): set up comprehensive logging and monitoring for proxy stack`
- Scope commits to specific components (traefik, authelia, crowdsec)
- Reference story ID in commit messages: `Story 03-003`