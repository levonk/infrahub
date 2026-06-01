---
story_id: "02-010"
story_title: "Role: netbird-control-plane"
story_name: "role-netbird-cp"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 10
branch: "feature/current/cloud-server/story-02-010-role-netbird-cp"
status: "in_progress"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "vpn"]
priority: "SHOULD"
risk_level: "high"
tags: ["ansible", "role", "vpn", "netbird", "docker"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-31"
---

## Summary

Create the `netbird-control-plane` Ansible role that deploys the self-hosted Netbird control plane as Docker containers: management server, signal server, and TURN relay server. This role is complex and high-risk due to multi-container orchestration and IdP integration.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/vpn-netbird-control/`
- [x] Create `defaults/main.yml` with container image tags, port mappings, and data path variables
- [x] Create `tasks/main.yml` with tasks for:
  - Create Docker network for Netbird control plane
  - Deploy `netbird-management` container with:
    - Variable-driven host and container ports
    - SQLite or Postgres backend (variable-driven)
    - Shared persistence volume
  - Deploy `netbird-signal` container with variable-driven ports
  - Deploy `netbird-turn` container with variable-driven ports
  - Configure container environment variables for management URLs
  - Start containers and verify health
- [x] Create Docker Compose template or individual container tasks
- [x] Create `handlers/main.yml` for container restarts
- [x] Create `meta/main.yml` with role metadata (depends on docker-engine)
- [x] Create `README.md` documenting role variables
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/vpn-netbird-control/` — role directory
- `shared/active/02-config/ansible/roles/vpn-netbird-control/defaults/main.yml` — container images, ports, IdP config
- `shared/active/02-config/ansible/roles/vpn-netbird-control/tasks/main.yml` — network, volume, container deployment, health checks
- `shared/active/02-config/ansible/roles/vpn-netbird-control/handlers/main.yml` — container restart handlers
- `shared/active/02-config/ansible/roles/vpn-netbird-control/meta/main.yml` — role metadata and docker-engine dependency
- `shared/active/02-config/ansible/roles/vpn-netbird-control/README.md` — role documentation
- `shared/active/02-config/ansible/roles/vpn-netbird-control/tests/test.yml` — test playbook
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Netbird port variables

## Acceptance Criteria

- [ ] All three Netbird control containers are running (requires deploy environment)
- [ ] Management server is accessible on variable-driven port (requires deploy environment)
- [ ] Signal server is running on variable-driven port (requires deploy environment)
- [ ] TURN server is running on variable-driven port (requires deploy environment)
- [ ] Persistence volumes are created and mounted (requires deploy environment)
- [x] `ansible-lint` passes — verified 2026-05-31, 0 failures 0 warnings

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/vpn-netbird-control/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/vpn-netbird-control/tests/test.yml`

## Observability

- Log container status and health after deployment
- Monitor Netbird management API availability

## Compliance

- All ports must be variables per AGENTS.md rules
- Container images should be pinned to specific tags
- No hardcoded management URLs

## Risks & Mitigations

- Risk: Complex multi-container startup ordering — Mitigation: Use Docker Compose with `depends_on` and health checks
- Risk: IdP integration complexity — Mitigation: Support local dummy IdP for bootstrap, document OIDC setup

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory), implicitly 02-003 (docker-engine)
- Unblocks: 03-003 (infrastructure playbook), 05-003 (deploy infra)

## Definition of Done

- Role deploys all Netbird control containers correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add vpn-netbird-control role`
- `test(ansible): add vpn-netbird-control role tests`

## Changelog

- 2026-05-29: initialized story file
