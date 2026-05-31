---
story_id: "02-013"
story_title: "Role: sso-service"
story_name: "role-sso"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 13
branch: "feature/current/cloud-server/story-02-013-role-sso"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "security"]
priority: "SHOULD"
risk_level: "high"
tags: ["ansible", "role", "security", "sso", "docker"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `sso-service` Ansible role that deploys a redundant Single Sign-On solution (Authelia, Keycloak, or Authentik) as a Docker container. The PRD notes this is a decision point — the role should be flexible to support the chosen solution.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/proxy-authelia/`
- [x] Create `defaults/main.yml` with SSO software choice, image tag, and port variables
- [x] Create `tasks/main.yml` with tasks for:
  - Deploy chosen SSO container with variable-driven host and container ports
  - Configure persistence volume for user database and sessions
  - Set up initial admin user (password via vault variable)
  - Configure OIDC/OAuth endpoints
  - Configure integration with reverse proxy (Traefik/Envoy labels or config)
  - Start container and verify health
- [x] Create configuration template for chosen SSO software
- [x] Create `handlers/main.yml` for container restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables and SSO options
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-authelia/` — Authelia SSO role directory
- `shared/active/02-config/ansible/roles/proxy-authelia/defaults/main.yml` — variable-driven ports and Authelia config defaults
- `shared/active/02-config/ansible/roles/proxy-authelia/tasks/main.yml` — container deployment tasks (Authelia + Redis)
- `shared/active/02-config/ansible/roles/proxy-authelia/handlers/main.yml` — container restart handlers
- `shared/active/02-config/ansible/roles/proxy-authelia/meta/main.yml` — role metadata
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/authelia/configuration.yml.j2` — Authelia configuration template
- `shared/active/02-config/ansible/roles/proxy-authelia/templates/authelia/users_database.yml.j2` — Authelia users database template
- `shared/active/02-config/ansible/roles/proxy-authelia/tests/test.yml` — test playbook
- `shared/active/02-config/ansible/roles/proxy-authelia/README.md` — role documentation
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — SSO port variables

## Acceptance Criteria

- [x] SSO container is running and healthy
- [x] SSO web interface is accessible on variable-driven port
- [x] Initial admin login works
- [x] OIDC endpoints are configured
- [x] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/proxy-*/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/proxy-*/tests/test.yml`
- Functional: Verify SSO login page responds via curl

## Observability

- Log SSO authentication events
- Monitor session count and database health

## Compliance

- Admin password must be in vault, never in plain group_vars
- All ports must be variables
- Document data handling and retention policies

## Risks & Mitigations

- Risk: SSO software decision still open — Mitigation: Default to Authelia for simplicity; document migration path
- Risk: Database persistence across container restarts — Mitigation: Use named volumes with backup strategy

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory), implicitly 02-003 (docker-engine)
- Unblocks: 03-003 (infrastructure playbook), 05-003 (deploy infra)

## Definition of Done

- Role deploys SSO service correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add proxy-authelia role`
- `test(ansible): add proxy-authelia role tests`

## Changelog

- 2026-05-29: initialized story file
