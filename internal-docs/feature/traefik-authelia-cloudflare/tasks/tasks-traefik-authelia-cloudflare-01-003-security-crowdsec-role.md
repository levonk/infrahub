---
story_id: "01-003"
story_title: "Create security-crowdsec Ansible role"
story_name: "security-crowdsec-role"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 1
parallel_id: 3
branch: "feature/current/traefik-authelia-cloudflare/story-01-003-security-crowdsec-role"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible/roles/security-crowdsec"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "infra", "security"]
due: "2026-06-27"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Create a complete Ansible role for deploying CrowdSec security engine and CrowdSec Bouncer for Traefik based on the docker-linux boilerplate. This role will handle CrowdSec container deployment, security engine configuration, Traefik log acquisition, bouncer setup, and remediation profile management. The role must implement IP-based threat protection with configurable ban durations and follow variable-driven configuration principles.

## Sub-Tasks

- [x] Create role directory structure following docker-linux boilerplate patterns
- [x] Implement main tasks file with Docker container deployment logic
- [x] Create CrowdSec configuration template (config.yaml) with acquisition sources
- [x] Implement Traefik log acquisition configuration
- [x] Create CrowdSec Bouncer configuration template for Traefik integration
- [x] Implement remediation profiles (default 672h ban, custom profiles)
- [x] Create Docker network configuration for traefik-network integration
- [x] Implement volume management for SQLite database persistence
- [x] Create handlers for CrowdSec restart/reload operations
- [x] Add health check configuration for CrowdSec service
- [x] Implement variable defaults with proper naming conventions
- [x] Create ban duration and remediation policy templates
- [x] Add API token management for bouncer communication
- [x] Create README with role usage documentation
- [x] Add Molecule test skeleton for basic validation

## Relevant Files

- `shared/active/02-config/ansible/roles/security-crowdsec/tasks/main.yml` - Main deployment tasks
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/config.yaml.j2` - CrowdSec configuration
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/acquis.yaml.j2` - Log acquisition configuration
- `shared/active/02-config/ansible/roles/security-crowdsec/templates/bouncer.yaml.j2` - Bouncer configuration
- `shared/active/02-config/ansible/roles/security-crowdsec/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/security-crowdsec/handlers/main.yml` - Restart handlers
- `shared/active/02-config/ansible/roles/security-crowdsec/README.md` - Documentation
- `shared/active/02-config/ansible/roles/security-crowdsec/molecule/` - Test framework

## Acceptance Criteria

- [x] Role follows docker-linux boilerplate structure exactly
- [x] All configuration is variable-driven (no hardcoded values)
- [x] CrowdSec configuration includes Traefik log acquisition
- [x] CrowdSec Bouncer is configured for Traefik integration
- [x] Default remediation profile (672h ban) is implemented
- [x] Custom remediation profiles can be configured via variables
- [x] Docker network integration with traefik-network is established
- [x] Health checks are configured for CrowdSec service
- [x] Volume mounts ensure SQLite database persistence
- [x] API token management is secure (use Ansible vault)
- [x] README documents all required variables and security profiles
- [x] Molecule test skeleton exists and can run basic validation

## Test Plan

- Unit: Run `ansible-lint` against the role directory
- Lint: `yamllint` on all YAML files in the role
- Syntax: `ansible-playbook --syntax-check` on test playbook
- Security: Verify API tokens are properly secured
- Manual: Test role deployment in development environment

## Observability

- Configure CrowdSec security event logs with JSON format
- Enable CrowdSec metrics endpoint for monitoring integration
- Set up log rotation for CrowdSec container logs
- Document ban event logging for security auditing

## Compliance

- Ensure API tokens are stored in Ansible vault
- Follow AGENTS.md guidelines for variable naming
- Reference AGENTS.md files in role documentation
- Implement proper data retention policies for ban database

## Risks & Mitigations

- Risk: Log acquisition failures — Mitigation: Proper error handling and fallback
- Risk: Bouncer communication failures — Mitigation: Retry logic and health checks
- Risk: Database corruption — Mitigation: Volume persistence and backup strategy
- Risk: False positive bans — Mitigation: Configurable remediation profiles

## Dependencies & Sequencing

- Depends on: None (foundational infrastructure)
- Unblocks: Story 02-003 (Deploy CrowdSec security engine and bouncer)
- Must complete before: Any CrowdSec deployment work

## Definition of Done

- Role structure matches docker-linux boilerplate exactly
- All templates use Jinja2 variable substitution
- No hardcoded values in any configuration files
- API tokens are properly managed via vault
- Role can be deployed with minimal variable overrides
- Documentation is complete and includes security guidelines
- Basic validation tests exist and pass

## Commit Conventions

- Use conventional commits: `feat(ansible): create security-crowdsec role from docker-linux boilerplate`
- Scope commits to specific components (tasks, templates, handlers, defaults)
- Reference story ID in commit messages: `Story 01-003`