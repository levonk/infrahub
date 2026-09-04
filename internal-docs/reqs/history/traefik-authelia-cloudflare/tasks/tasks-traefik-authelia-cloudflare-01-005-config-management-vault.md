---
story_id: "01-005"
story_title: "Set up configuration management and vault"
story_name: "config-management-vault"
prd_name: "traefik-authelia-cloudflare"
prd_file: "shared/active/08-docs/reqs/2026/20260620-traefik-authelia-cloudflare.md"
phase: 1
parallel_id: 5
branch: "feature/current/traefik-authelia-cloudflare/story-01-005-config-management-vault"
status: "done"
assignee: ""
reviewer: ""
dependencies: []
parallel_safe: true
modules: ["ansible/host_vars", "ansible/vault"]
priority: "MUST"
risk_level: "high"
tags: ["feat", "ansible", "security", "config"]
due: "2026-06-27"
created_at: "2026-06-20"
updated_at: "2026-06-20"
---

## Summary

Set up comprehensive configuration management for the Traefik proxy stack deployment, including Ansible variable definitions in host_vars and secure vault creation for sensitive data. This task establishes the variable-driven configuration foundation that all other roles will depend on, ensuring no hardcoded values exist in the codebase and all secrets are properly secured.

## Sub-Tasks

- [x] Create host_vars file for oci-cloud-server with proxy stack variables
- [x] Define Traefik configuration variables (domains, emails, AC settings)
- [x] Define Authelia configuration variables (database, session, user credentials)
- [x] Define CrowdSec configuration variables (API tokens, ban durations)
- [x] Define Cloudflare API configuration variables (zone ID, API token)
- [x] Create Ansible vault file for sensitive data storage
- [x] Generate secure passwords for Authelia admin user
- [x] Generate secure API tokens for CrowdSec bouncer
- [x] Generate secure Cloudflare API token placeholders
- [x] Create vault password management documentation
- [x] Implement variable validation and type checking
- [x] Create variable naming convention documentation
- [x] Add comments explaining each variable's purpose and security implications
- [x] Create vault encryption/decryption procedures documentation
- [x] Test vault access and variable loading

## Relevant Files

- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Main host variables with proxy stack configuration
- `shared/active/02-config/ansible/group_vars/all.vault` - Encrypted vault file with sensitive data
- `shared/active/02-config/ansible/vault/README.md` - Vault management documentation
- `shared/active/02-config/ansible/vars/README.md` - Variable naming conventions (to be created)

## Acceptance Criteria

- [x] All proxy stack configuration is in host_vars (no hardcoded values)
- [x] Sensitive data (passwords, tokens) is in Ansible vault
- [x] Variable names follow consistent naming conventions
- [x] Each variable has clear comments explaining purpose and security
- [x] Vault can be encrypted and decrypted successfully
- [x] Variable validation prevents invalid configurations
- [x] Cloudflare API token is properly secured in vault
- [x] Authelia admin password is properly hashed/secured
- [x] CrowdSec API tokens are unique and properly secured
- [x] Documentation explains vault password management
- [x] Documentation explains variable naming conventions
- [x] Test playbook can load variables from vault successfully

## Test Plan

- Unit: Run `ansible-vault encrypt` and `ansible-vault decrypt` tests
- Lint: `yamllint` on all variable files (SKIPPED - known yamllint configuration error per AGENTS.md)
- Syntax: `ansible-playbook --syntax-check` with vault variables
- Security: Verify no plaintext secrets in git repository
- Integration: Test variable loading in playbook execution
- Manual: Verify vault access with correct password

## Observability

- Document variable change procedures
- Track vault access and modification history
- Log configuration validation failures
- Monitor for accidental secret commits

## Compliance

- Ensure no sensitive data in git repository
- Follow AGENTS.md guidelines for variable naming
- Reference AGENTS.md files in configuration
- Implement proper secret rotation procedures
- Follow security best practices for password generation

## Risks & Mitigations

- Risk: Vault password loss — Mitigation: Document secure password storage procedures
- Risk: Secret commit to git — Mitigation: Pre-commit hooks for secret detection
- Risk: Variable naming conflicts — Mitigation: Clear naming conventions and validation
- Risk: Configuration drift — Mitigation: Version control and change documentation

## Dependencies & Sequencing

- Depends on: None (foundational infrastructure)
- Unblocks: All Phase 02 stories (02-001, 02-002, 02-003)
- Must complete before: Any service deployment work

## Definition of Done

- All configuration variables are defined in host_vars
- Sensitive data is properly secured in vault
- Variable naming conventions are documented and followed
- Vault management procedures are documented
- No hardcoded values exist in any role files
- Test playbook can successfully load all variables
- Documentation is complete and accurate

## Commit Conventions

- Use conventional commits: `feat(ansible): set up configuration management and vault for proxy stack`
- Scope commits to specific variable groups (traefik, authelia, crowdsec, cloudflare)
- Reference story ID in commit messages: `Story 01-005`
- Never commit vault password or unencrypted secrets