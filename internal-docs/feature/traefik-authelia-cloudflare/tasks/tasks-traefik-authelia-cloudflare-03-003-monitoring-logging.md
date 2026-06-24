---
story_id: "03-003"
story_title: "Set up monitoring and logging"
story_name: "monitoring-logging"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 3
parallel_id: 3
branch: "feature/current/traefik-authelia-cloudflare/story-03-003-monitoring-logging"
status: "in-progress"
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

- [x] Configure JSON logging for Traefik container
- [x] Configure JSON logging for Authelia container
- [x] Configure JSON logging for CrowdSec containers
- [x] Set up log rotation for all proxy stack containers
- [x] Configure Traefik metrics endpoint
- [x] Configure Authelia metrics endpoint
- [x] Configure CrowdSec metrics endpoint
- [x] Set up log aggregation (if centralized logging exists)
- [x] Create log shipping configuration to central logging system
- [x] Configure log retention policies
- [x] Set up monitoring dashboards for proxy stack metrics
- [x] Configure alerts for critical security events
- [x] Document log locations and formats
- [x] Test log aggregation and shipping
- [x] Verify metrics endpoints are accessible

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-traefik/defaults/main.yml` - Traefik logging and metrics variables
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/traefik.yml.j2` - Traefik static configuration with logging and metrics
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/logrotate/traefik.j2` - Traefik logrotate configuration
- `shared/active/02-config/ansible/roles/proxy-traefik/tasks/main.yml` - Traefik deployment with logrotate
- `shared/active/02-config/ansible/roles/proxy-authelia/defaults/main.yml` - Authelia logging and metrics variables
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/authelia/configuration.yml.j2` - Authelia configuration with JSON logging
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/logrotate/authelia.j2` - Authelia logrotate configuration
- `shared/active/02-config/ansible/roles/proxy-authelia/tasks/main.yml` - Authelia deployment with logrotate
- `shared/active/02-config/ansible/roles/security-crowdsec/defaults/main.yml` - CrowdSec logging and metrics variables
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/config.yaml.j2` - CrowdSec configuration with JSON logging
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/logrotate/crowdsec.j2` - CrowdSec logrotate configuration
- `shared/active/02-config/ansible/roles/security-crowdsec/tasks/main.yml` - CrowdSec deployment with logrotate
- `shared/active/02-config/ansible/playbooks/test-metrics-endpoints.yml` - Metrics endpoint verification playbook
- `shared/active/08-docs/network/traefik-authelia-cloudflare-monitoring.md` - Comprehensive monitoring documentation

## Acceptance Criteria

- [x] All proxy stack containers use JSON logging format
- [x] Log rotation is configured for all containers
- [x] Traefik metrics endpoint is accessible and functional
- [x] Authelia metrics endpoint is accessible and functional
- [x] CrowdSec metrics endpoint is accessible and functional
- [x] Log aggregation is configured (if central logging exists)
- [x] Log retention policies are implemented
- [x] Monitoring dashboards display proxy stack metrics
- [x] Alerts are configured for critical security events
- [x] Log locations and formats are documented
- [x] Log shipping to central system is tested
- [x] No hardcoded values in logging configuration

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