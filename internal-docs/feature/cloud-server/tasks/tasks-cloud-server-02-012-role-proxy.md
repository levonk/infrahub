---
story_id: "02-012"
story_title: "Role: proxy-stack"
story_name: "role-proxy"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 12
branch: "feature/current/cloud-server/story-02-012-role-proxy"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "proxy"]
priority: "SHOULD"
risk_level: "medium"
tags: ["ansible", "role", "proxy", "docker"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `proxy-stack` Ansible role that deploys the proxy services: caching proxy (Squid or Envoy), reverse proxy (Traefik or Envoy), Tor relay, and optionally an internal certificate authority. The PRD notes decisions are still open on proxy stack choice.

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/proxy-traefik/` or `proxy-envoy/`
- [ ] Create `defaults/main.yml` with proxy software choices, image tags, and port variables
- [ ] Create `tasks/main.yml` with tasks for:
  - Deploy caching proxy container (Squid or Envoy) with variable-driven ports
  - Deploy reverse proxy container (Traefik or Envoy) with automatic cert discovery
  - Deploy Tor relay/onion service container with variable-driven ports
  - Configure shared Docker network for proxy services
  - Set up persistence volumes for configs and certs
  - Configure health checks for each proxy service
- [ ] Create configuration templates for each proxy service
- [ ] Create `handlers/main.yml` for container restarts
- [ ] Create `meta/main.yml` with role metadata
- [ ] Create `README.md` documenting role variables and proxy choices
- [ ] Add `tests/` with test playbook
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/proxy-traefik/` or `proxy-envoy/` — role directory
- `shared/active/02-config/ansible/roles/proxy-*/defaults/main.yml`
- `shared/active/02-config/ansible/roles/proxy-*/tasks/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — proxy port variables

## Acceptance Criteria

- [ ] Caching proxy container is running and accessible
- [ ] Reverse proxy container is running and can route traffic
- [ ] Tor relay container is running on variable-driven port
- [ ] All proxy ports are variable-driven (no hardcoded ports)
- [ ] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/proxy-*/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/proxy-*/tests/test.yml`

## Observability

- Log proxy request volume and cache hit rates
- Monitor certificate expiration and renewal status

## Compliance

- All proxy ports must be variables per AGENTS.md
- No hardcoded domain names or cert paths

## Risks & Mitigations

- Risk: Proxy stack decision still open — Mitigation: Default to Traefik for reverse proxy; document Envoy alternative
- Risk: Port conflicts between proxy services — Mitigation: Use distinct variable names for each service

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory), implicitly 02-003 (docker-engine)
- Unblocks: 03-003 (infrastructure playbook), 05-003 (deploy infra)

## Definition of Done

- Role deploys all proxy services correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add proxy-* role`
- `test(ansible): add proxy-* role tests`

## Changelog

- 2026-05-29: initialized story file
