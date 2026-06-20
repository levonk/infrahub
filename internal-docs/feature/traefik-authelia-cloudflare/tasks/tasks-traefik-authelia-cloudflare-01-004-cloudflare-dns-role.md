---
story_id: "01-004"
story_title: "Create cloudflare-dns Ansible role"
story_name: "cloudflare-dns-role"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 1
parallel_id: 4
branch: "feature/current/traefik-authelia-cloudflare/story-01-004-cloudflare-dns-role"
status: "todo"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible/roles/cloudflare-dns"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "ansible", "infra", "security"]
due: "2026-06-27"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Create a complete Ansible role for managing Cloudflare DNS records using the Cloudflare API v4. This role will handle automated DNS record creation, updates, and deletion for services deployed on the OCI cloud server. The role must implement secure API credential management using Ansible vault and support variable-driven configuration for multiple domains and record types.

## Sub-Tasks

- [ ] Create role directory structure following Ansible best practices
- [ ] Implement main tasks file with Cloudflare API integration
- [ ] Create DNS record management tasks (create, update, delete, list)
- [ ] Implement A record creation with IP address validation
- [ ] Add DNS record existence checks to prevent duplicates
- [ ] Create variable defaults for Cloudflare API configuration
- [ ] Implement proper error handling for API failures
- [ ] Add idempotency checks to avoid unnecessary API calls
- [ ] Create handlers for DNS record change notifications
- [ ] Implement support for multiple domains and subdomains
- [ ] Add DNS record verification tasks
- [ ] Create README with role usage documentation
- [ ] Add Molecule test skeleton with mocked Cloudflare API
- [ ] Implement vault integration for API token security

## Relevant Files

- `shared/active/02-config/ansible/roles/cloudflare-dns/tasks/main.yml` - Main DNS management tasks
- `shared/active/02-config/ansible/roles/cloudflare-dns/tasks/create_record.yml` - DNS record creation
- `shared/active/02-config/ansible/roles/cloudflare-dns/tasks/update_record.yml` - DNS record updates
- `shared/active/02-config/ansible/roles/cloudflare-dns/tasks/delete_record.yml` - DNS record deletion
- `shared/active/02/config/ansible/roles/cloudflare-dns/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/cloudflare-dns/handlers/main.yml` - Change notification handlers
- `shared/active/02-config/ansible/roles/cloudflare-dns/README.md` - Documentation
- `shared/active/02-config/ansible/roles/cloudflare-dns/molecule/` - Test framework

## Acceptance Criteria

- [ ] Role uses Cloudflare API v4 for all DNS operations
- [ ] API credentials are stored in Ansible vault (never in plain text)
- [ ] DNS record creation is idempotent (no duplicates)
- [ ] A record creation includes IP address validation
- [ ] Role supports multiple domains and subdomains via variables
- [ ] Proper error handling for API failures and rate limits
- [ ] DNS record verification tasks confirm successful changes
- [ ] Role follows variable-driven configuration principles
- [ ] README documents all required variables and vault setup
- [ ] Molecule tests exist with mocked Cloudflare API
- [ ] Role can create, update, and delete DNS records
- [ ] Security best practices are followed (token encryption)

## Test Plan

- Unit: Run `ansible-lint` against the role directory
- Lint: `yamllint` on all YAML files in the role
- Syntax: `ansible-playbook --syntax-check` on test playbook
- Security: Verify API tokens are properly vaulted
- Integration: Test with Cloudflare API staging environment
- Manual: Test role deployment in development environment

## Observability

- Log all DNS API operations with success/failure status
- Track DNS record changes for audit purposes
- Document DNS propagation timing considerations
- Add monitoring for API rate limit usage

## Compliance

- Ensure Cloudflare API tokens are stored in Ansible vault
- Follow AGENTS.md guidelines for variable naming
- Reference AGENTS.md files in role documentation
- Implement proper API token rotation procedures
- Follow Cloudflare API rate limiting guidelines

## Risks & Mitigations

- Risk: API token exposure — Mitigation: Mandatory vault usage and access controls
- Risk: DNS propagation delays — Mitigation: Document timing and verification steps
- Risk: API rate limiting — Mitigation: Implement proper backoff and idempotency
- Risk: Accidental record deletion — Mitigation: Confirmation checks and dry-run mode

## Dependencies & Sequencing

- Depends on: None (foundational infrastructure)
- Unblocks: Story 03-002 (Configure Cloudflare DNS records)
- Must complete before: Any Cloudflare DNS operations

## Definition of Done

- Role structure follows Ansible best practices
- All API operations use Cloudflare API v4
- API tokens are properly secured in vault
- DNS operations are idempotent and safe
- Role can be deployed with minimal variable overrides
- Documentation is complete and includes security guidelines
- Basic validation tests exist and pass

## Commit Conventions

- Use conventional commits: `feat(ansible): create cloudflare-dns role for automated DNS management`
- Scope commits to specific operations (create, update, delete)
- Reference story ID in commit messages: `Story 01-004`