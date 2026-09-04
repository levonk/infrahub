---
story_id: "03-003"
story_title: "Playbook: cloud-server-infra.yml"
story_name: "pb-infra"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 3
parallel_id: 3
branch: "feature/current/cloud-server/story-03-003-pb-infra"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["02-010", "02-011", "02-012", "02-013"]
parallel_safe: true
modules: ["ansible", "playbook"]
priority: "SHOULD"
risk_level: "medium"
tags: ["ansible", "playbook", "infra"]
due: "2026-06-19"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `cloud-server-infra.yml` playbook that orchestrates the infrastructure services: Netbird control plane, DNS stack, proxy stack, and SSO service. Deployed as Docker containers, these services depend on the Docker engine being ready.

## Sub-Tasks

- [x] Create `shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- [x] Define `hosts: cloud_servers` target group
- [x] Import roles in dependency order:
  - `vpn-netbird-control` (management, signal, TURN)
  - `dns-coredns`
  - `proxy-traefik`
  - `proxy-authelia`
- [x] Add `pre_tasks` to verify Docker is running and accessible
- [x] Add `post_tasks` for service health checks (HTTP probes, DNS queries)
- [x] Document playbook usage in README
- [x] Verify `ansible-playbook --syntax-check` passes
- [x] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/playbooks/cloud-server-infra.yml` — infra playbook
- `shared/active/02-config/ansible/roles/vpn-netbird-control/` — role 02-010
- `shared/active/02-config/ansible/roles/dns-adguard/` or `dns-coredns/` — role 02-011
- `shared/active/02-config/ansible/roles/proxy-traefik/` or `proxy-envoy/` — role 02-012
- `shared/active/02-config/ansible/roles/proxy-authelia/` or `proxy-keycloak/` — role 02-013
- `levonk/active/02-config/ansible/inventories/oci.yml` — inventory

## Acceptance Criteria

- [x] Playbook syntax is valid
- [x] All infrastructure roles are imported
- [x] Pre-tasks verify Docker availability
- [x] Post-tasks verify service health
- [x] `ansible-lint` passes
- [x] Can be executed via `devbox run ansible-playbook ...`

## Test Plan

- Syntax: `devbox run ansible-playbook --syntax-check -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- Lint: `devbox run ansible-lint shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/playbooks/cloud-server-infra.yml`

## Observability

- Log container startup status per role
- Capture HTTP status codes for proxy and SSO endpoints

## Compliance

- All service ports must be variables
- No hardcoded container image tags (use variables)

## Risks & Mitigations

- Risk: Service startup ordering issues — Mitigation: Use Docker Compose `depends_on` within each role
- Risk: Port conflicts between services — Mitigation: Variable-driven ports with validation

## Dependencies & Sequencing

- Depends on: 02-010, 02-011, 02-012, 02-013
- Unblocks: 05-003 (deploy infrastructure to OCI)

## Definition of Done

- Playbook is complete, linted, and validated
- CI passes playbook checks
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add cloud-server-infra playbook`
- `docs(ansible): document infrastructure playbook usage`

## Changelog

- 2026-05-29: initialized story file
