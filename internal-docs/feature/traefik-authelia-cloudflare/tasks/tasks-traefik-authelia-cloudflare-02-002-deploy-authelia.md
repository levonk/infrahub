---
story_id: "02-002"
story_title: "Deploy Authelia with database and session management"
story_name: "deploy-authelia"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 2
parallel_id: 2
branch: "feature/current/traefik-authelia-cloudflare/story-02-002-deploy-authelia"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: ["01-002", "01-005"]
parallel_safe: true
modules: ["proxy-authelia", "docker-compose"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "deploy", "authelia", "security"]
due: "2026-06-30"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Deploy Authelia authentication service with PostgreSQL database, Redis session storage, and Traefik forward auth integration. This deployment will provide centralized authentication for all protected services, with secure password hashing (Argon2) and session management. The service will integrate with Traefik for seamless authentication middleware.

## Sub-Tasks

- [x] Deploy proxy-authelia role to OCI cloud server
- [x] Deploy PostgreSQL database container for Authelia
- [x] Deploy Redis container for session storage
- [ ] Configure Authelia with PostgreSQL connection
- [ ] Configure Authelia with Redis session storage
- [ ] Set up user database with admin account
- [ ] Configure Argon2 password hashing
- [ ] Create Traefik forward auth middleware configuration
- [ ] Connect Authelia to traefik-network
- [ ] Configure session management and cookie security
- [ ] Set up volume mounts for database and session persistence
- [ ] Test Authelia container startup and health status
- [ ] Test admin user authentication
- [ ] Verify Traefik forward auth integration
- [ ] Configure Authelia logging with JSON format

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-authelia/` - Role deployment
- `shared/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Configuration variables
- `shared/active/03-container/services/auth/authelia/` - Authelia service directory
- `shared/active/03-container/docker-compose.shared.yml` - Shared compose configuration
- `shared/active/02-config/ansible/playbooks/deploy-authelia.yml` - Deployment playbook

## Acceptance Criteria

- [ ] Authelia container is running and healthy
- [ ] PostgreSQL database is running and accessible
- [ ] Redis session storage is running and accessible
- [ ] Admin user can successfully authenticate
- [ ] Passwords are hashed with Argon2 (no plaintext)
- [ ] Traefik forward auth middleware is configured
- [ ] Authelia is connected to traefik-network
- [ ] Session management is properly configured
- [ ] Cookie security settings are implemented
- [ ] Database and sessions persist across container restarts
- [ ] Logging is configured with JSON format
- [ ] No hardcoded credentials in configuration

## Test Plan

- Unit: `docker ps` to verify Authelia, PostgreSQL, and Redis containers
- Integration: Test admin user login via Authelia UI
- Database: Verify PostgreSQL connection and user table
- Session: Test Redis session storage and retrieval
- Forward Auth: Test Traefik forward auth integration
- Persistence: Test database and session persistence after restart
- Security: Verify password hashing with Argon2

## Observability

- Configure Authelia access logs with JSON format
- Enable Authelia metrics endpoint for monitoring
- Set up log aggregation for Authelia container logs
- Document authentication event logging for security auditing
- Track failed authentication attempts for security monitoring

## Compliance

- Ensure passwords are hashed with Argon2 (never plaintext)
- Follow AGENTS.md guidelines for variable-driven configuration
- Reference AGENTS.md files in deployment documentation
- Implement secure session management (proper cookie settings)
- Follow security best practices for authentication

## Risks & Mitigations

- Risk: Database connection failures — Mitigation: Proper retry logic and health checks
- Risk: Session storage failures — Mitigation: Redis persistence configuration
- Risk: Forward auth misconfiguration — Mitigation: Comprehensive testing with Traefik
- Risk: Password hash compatibility — Mitigation: Use standard Argon2 parameters

## Dependencies & Sequencing

- Depends on: Story 01-002 (proxy-authelia role), Story 01-005 (config management)
- Unblocks: Story 02-003 (CrowdSec deployment), Story 03-001 (SearXNG integration)
- Must complete before: Any service integration requiring authentication

## Definition of Done

- Authelia container is deployed and running on OCI server
- PostgreSQL and Redis are deployed and accessible
- Admin user can successfully authenticate
- Traefik forward auth integration is working
- Passwords are properly hashed with Argon2
- Session management is configured and persistent
- Logging and monitoring are configured
- Documentation is updated with deployment notes
- No hardcoded credentials in any configuration

## Commit Conventions

- Use conventional commits: `feat(deploy): deploy Authelia with PostgreSQL and Redis session storage`
- Scope commits to specific components (database, session, forward auth)
- Reference story ID in commit messages: `Story 02-002`