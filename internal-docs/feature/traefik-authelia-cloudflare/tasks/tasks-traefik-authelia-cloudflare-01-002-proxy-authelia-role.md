---
story_id: "01-002"
story_title: "Create proxy-authelia Ansible role"
story_name: "proxy-authelia-role"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 1
parallel_id: 2
branch: "feature/current/traefik-authelia-cloudflare/story-01-002-proxy-authelia-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible/roles/proxy-authelia"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "ansible", "infra", "security"]
due: "2026-06-27"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Create a complete Ansible role for deploying Authelia authentication service based on the docker-linux boilerplate. This role will handle Authelia container deployment, PostgreSQL database setup, Redis session storage configuration, user management, and Traefik forward auth integration. The role must implement secure password hashing (Argon2) and follow variable-driven configuration principles.

## Sub-Tasks

- [ ] Create role directory structure following docker-linux boilerplate patterns
- [ ] Implement main tasks file with Docker container deployment logic
- [ ] Create Authelia configuration template (configuration.yml) with environment variable substitution
- [ ] Implement PostgreSQL database initialization and migration tasks
- [ ] Create Redis session storage configuration
- [ ] Implement user database template with admin account setup
- [ ] Create Docker network configuration for traefik-network integration
- [ ] Implement volume management for database and session persistence
- [ ] Create handlers for Authelia restart/reload operations
- [ ] Add health check configuration for Authelia service
- [ ] Implement variable defaults with proper naming conventions
- [ ] Create secure password generation utilities (Argon2 hashing)
- [ ] Add Traefik forward auth middleware configuration template
- [ ] Create README with role usage documentation
- [ ] Add Molecule test skeleton for basic validation

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-authelia/tasks/main.yml` - Main deployment tasks
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/configuration.yml.j2` - Authelia configuration
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/users_database.yml.j2` - User database template
- `shared/active/02-config/ansible/roles/proxy-authelia/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/proxy-authelia/handlers/main.yml` - Restart handlers
- `shared/active/02-config/ansible/roles/proxy-authelia/README.md` - Documentation
- `shared/active/02-config/ansible/roles/proxy-authelia/molecule/` - Test framework

## Acceptance Criteria

- [ ] Role follows docker-linux boilerplate structure exactly
- [ ] All configuration is variable-driven (no hardcoded credentials)
- [ ] Authelia configuration includes PostgreSQL database setup
- [ ] Redis session storage is properly configured
- [ ] User database template supports admin account creation
- [ ] Password hashing uses Argon2 (never plaintext storage)
- [ ] Traefik forward auth middleware is configured
- [ ] Docker network integration with traefik-network is established
- [ ] Health checks are configured for Authelia service
- [ ] Volume mounts ensure database and session persistence
- [ ] README documents all required variables and security considerations
- [ ] Molecule test skeleton exists and can run basic validation

## Test Plan

- Unit: Run `ansible-lint` against the role directory
- Lint: `yamllint` on all YAML files in the role
- Syntax: `ansible-playbook --syntax-check` on test playbook
- Security: Verify no plaintext passwords in templates
- Manual: Test role deployment in development environment

## Observability

- Configure Authelia access logs with JSON format
- Enable Authelia metrics endpoint for monitoring integration
- Set up log rotation for Authelia container logs
- Document authentication event logging for security auditing

## Compliance

- Ensure passwords are never stored in plaintext (Argon2 hashing only)
- Use Ansible vault for all sensitive configuration
- Follow AGENTS.md guidelines for variable naming
- Reference AGENTS.md files in role documentation
- Implement secure session management (proper cookie settings)

## Risks & Mitigations

- Risk: Database connection failures — Mitigation: Proper retry logic and health checks
- Risk: Session storage failures — Mitigation: Redis persistence configuration
- Risk: Password hash compatibility — Mitigation: Use standard Argon2 parameters
- Risk: Forward auth misconfiguration — Mitigation: Comprehensive testing with Traefik

## Dependencies & Sequencing

- Depends on: None (foundational infrastructure)
- Unblocks: Story 02-002 (Deploy Authelia with database and session management)
- Must complete before: Any Authelia deployment work

## Definition of Done

- Role structure matches docker-linux boilerplate exactly
- All templates use Jinja2 variable substitution
- No hardcoded credentials in any configuration files
- Password hashing uses Argon2 (no plaintext storage)
- Role can be deployed with minimal variable overrides
- Documentation is complete and includes security guidelines
- Basic validation tests exist and pass

## Commit Conventions

- Use conventional commits: `feat(ansible): create proxy-authelia role from docker-linux boilerplate`
- Scope commits to specific components (tasks, templates, handlers, defaults)
- Reference story ID in commit messages: `Story 01-002`