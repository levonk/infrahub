---
story_id: "01-001"
story_title: "Create proxy-traefik Ansible role"
story_name: "proxy-traefik-role"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 1
parallel_id: 1
branch: "feature/current/traefik-authelia-cloudflare/story-01-001-proxy-traefik-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible/roles/proxy-traefik"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "infra"]
due: "2026-06-27"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Create a complete Ansible role for deploying Traefik reverse proxy based on the docker-linux boilerplate. This role will handle Traefik container deployment, ACME/Let's Encrypt configuration, plugin setup (CrowdSec Bouncer and GeoBlock), and integration with the existing proxy infrastructure. The role must follow variable-driven configuration principles with no hardcoded values.

## Sub-Tasks

- [x] Create role directory structure following docker-linux boilerplate patterns
- [x] Implement main tasks file with Docker container deployment logic
- [x] Create Traefik static configuration template (traefik.yml) with ACME setup
- [x] Create dynamic configuration template directory structure
- [x] Implement experimental plugins configuration (CrowdSec Bouncer v1.4.4, GeoBlock v0.3.3)
- [x] Create Docker network configuration for traefik-network
- [x] Implement volume management for SSL certificates and configuration
- [x] Create handlers for Traefik restart/reload operations
- [x] Add health check configuration for Traefik dashboard
- [x] Implement variable defaults with proper naming conventions
- [x] Create README with role usage documentation
- [x] Add Molecule test skeleton for basic validation

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-traefik/tasks/main.yml` - Main deployment tasks
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/traefik.yml.j2` - Static configuration template
- `shared/active/02-config/ansible/roles/proxy-traefik/templates/dynamic/middlewares.yml.j2` - Dynamic middleware configuration
- `shared/active/02-config/ansible/roles/proxy-traefik/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/proxy-traefik/handlers/main.yml` - Restart handlers
- `shared/active/02-config/ansible/roles/proxy-traefik/meta/main.yml` - Role metadata and dependencies
- `shared/active/02-config/ansible/roles/proxy-traefik/README.md` - Documentation
- `shared/active/02-config/ansible/roles/proxy-traefik/.molecule/default/` - Test framework

## Acceptance Criteria

- [x] Role follows docker-linux boilerplate structure exactly
- [x] All configuration is variable-driven (no hardcoded IPs/ports/domains)
- [x] Traefik static configuration includes ACME TLS challenge setup
- [x] Experimental plugins (CrowdSec Bouncer, GeoBlock) are pre-configured
- [x] Docker network traefik-network is created and properly configured
- [x] Health checks are configured for Traefik dashboard (port 8882)
- [x] Handlers properly restart Traefik on configuration changes
- [x] Volume mounts are configured for SSL certificate persistence
- [x] README documents all required variables and usage examples
- [x] Molecule test skeleton exists and can run basic validation

## Test Plan

- Unit: Run `ansible-lint` against the role directory
- Lint: `yamllint` on all YAML files in the role
- Syntax: `ansible-playbook --syntax-check` on test playbook
- Manual: Test role deployment in development environment

## Observability

- Configure Traefik access logs with JSON format
- Enable Traefik metrics endpoint for monitoring integration
- Set up log rotation for Traefik container logs
- Document log locations and formats for central logging

## Compliance

- Ensure no sensitive data (API keys, passwords) in role files
- Use Ansible vault for any secrets in variables
- Follow AGENTS.md guidelines for variable naming
- Reference AGENTS.md files in role documentation

## Risks & Mitigations

- Risk: Plugin version conflicts — Mitigation: Pin specific versions in configuration
- Risk: ACME rate limiting — Mitigation: Use staging environment for testing
- Risk: Network conflicts — Mitigation: Variable-driven network configuration
- Risk: SSL certificate persistence — Mitigation: Proper volume mounting strategy

## Dependencies & Sequencing

- Depends on: None (foundational infrastructure)
- Unblocks: Story 02-001 (Deploy Traefik with ACME and plugins)
- Must complete before: Any Traefik deployment work

## Definition of Done

- Role structure matches docker-linux boilerplate exactly
- All templates use Jinja2 variable substitution
- No hardcoded values in any configuration files
- Role can be deployed with minimal variable overrides
- Documentation is complete and accurate
- Basic validation tests exist and pass

## Commit Conventions

- Use conventional commits: `feat(ansible): create proxy-traefik role from docker-linux boilerplate`
- Scope commits to specific components (tasks, templates, handlers, defaults)
- Reference story ID in commit messages: `Story 01-001`