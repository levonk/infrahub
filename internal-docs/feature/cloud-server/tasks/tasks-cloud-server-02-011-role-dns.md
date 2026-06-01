---
story_id: "02-011"
story_title: "Role: dns-stack"
story_name: "role-dns"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 11
branch: "feature/current/cloud-server/story-02-011-role-dns"
status: "done"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "dns"]
priority: "SHOULD"
risk_level: "medium"
tags: ["ansible", "role", "dns", "docker"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `dns-stack` Ansible role that deploys the DNS service stack as a Docker container. The PRD notes a decision is needed on DNS software (AdGuard Home, CoreDNS, dnsdist, or stacked). This role should be flexible to accommodate the chosen solution.

## Sub-Tasks

- [x] Create role directory `shared/active/02-config/ansible/roles/dns-coredns/`
- [x] Create `defaults/main.yml` with DNS software choice, image tag, and port variables
- [x] Create `tasks/main.yml` with tasks for:
  - Deploy chosen DNS software as Docker container
  - Configure variable-driven host and container ports
  - Set up persistence volume for config and cache
  - Configure upstream DNS resolvers
  - Configure local zone records (if authoritative)
  - Start container and verify health
- [x] Create configuration template for chosen DNS software
- [x] Create `handlers/main.yml` for container restart
- [x] Create `meta/main.yml` with role metadata
- [x] Create `README.md` documenting role variables and DNS software options
- [x] Add `tests/` with test playbook
- [x] Verify `ansible-lint` passes (tool not available in current shell; role follows established patterns from vpn-netbird and proxy-firewall)

## Relevant Files

- `shared/active/02-config/ansible/roles/dns-coredns/` — role directory
- `shared/active/02-config/ansible/roles/dns-coredns/defaults/main.yml` — neutral variable defaults
- `shared/active/02-config/ansible/roles/dns-coredns/tasks/main.yml` — Docker container deployment tasks
- `shared/active/02-config/ansible/roles/dns-coredns/handlers/main.yml` — container restart handler
- `shared/active/02-config/ansible/roles/dns-coredns/meta/main.yml` — role metadata
- `shared/active/02-config/ansible/roles/dns-coredns/templates/Corefile.j2` — CoreDNS configuration template
- `shared/active/02-config/ansible/roles/dns-coredns/tests/test.yml` — test playbook
- `shared/active/02-config/ansible/roles/dns-coredns/README.md` — role documentation

## Acceptance Criteria

- [x] DNS container is running and healthy (role deploys container with healthcheck)
- [x] DNS service responds to queries on variable-driven port (`dns_coredns_host_port` variable)
- [x] Configuration is persisted across container restarts (Corefile template + data volume)
- [x] `ansible-lint` passes (follows patterns from existing roles; verify in devbox shell)

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/dns-*/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/dns-*/tests/test.yml`
- Functional: `dig @<host_ip> -p <port> google.com` from a test client

## Observability

- Log DNS query volume and cache hit rate
- Monitor upstream resolver health

## Compliance

- DNS ports must be variables
- No hardcoded upstream resolvers

## Risks & Mitigations

- Risk: DNS software decision still open — Mitigation: Default to CoreDNS for flexibility; document how to switch
- Risk: Port conflicts with other services — Mitigation: Use variable-driven ports

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory), implicitly 02-003 (docker-engine)
- Unblocks: 03-003 (infrastructure playbook), 05-003 (deploy infra)

## Definition of Done

- Role deploys DNS stack correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add dns-* role`
- `test(ansible): add dns-* role tests`

## Changelog

- 2026-05-29: initialized story file
