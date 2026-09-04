---
story_id: "02-003"
story_title: "Role: docker-engine"
story_name: "role-docker"
prd_name: "cloud-server"
prd_file: "shared/active/08-docs/reqs/2026/20260529-cloud-server.md"
phase: 2
parallel_id: 3
branch: "feature/current/cloud-server/story-02-003-role-docker"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["01-001", "01-002"]
parallel_safe: true
modules: ["ansible", "role", "docker"]
priority: "MUST"
risk_level: "medium"
tags: ["ansible", "role", "docker"]
due: "2026-06-12"
created_at: "2026-05-29"
updated_at: "2026-05-29"
---

## Summary

Create the `docker-engine` Ansible role that installs Docker and the Docker Compose plugin, creates a hardened `daemon.json`, and configures the Docker service. This role is critical for all containerized workloads on the cloud server.

## Sub-Tasks

- [ ] Create role directory `shared/active/02-config/ansible/roles/docker-engine/`
- [ ] Create `defaults/main.yml` with Docker version, userns-remap settings, and security flags
- [ ] Create `tasks/main.yml` with tasks for:
  - Install Docker engine and docker-compose plugin (via Nix or OS package manager)
  - Create `/etc/docker/daemon.json` with:
    - `userns-remap` or rootless mode configuration
    - `no-new-privileges: true`
    - `live-restore: true`
  - Add `cuser` to `docker` group
  - Enable and start Docker service
  - Verify Docker CLI works
- [ ] Create `handlers/main.yml` for Docker daemon restart
- [ ] Create `meta/main.yml` with role metadata
- [ ] Create `README.md` documenting role variables
- [ ] Add `tests/` with test playbook
- [ ] Verify `ansible-lint` passes

## Relevant Files

- `shared/active/02-config/ansible/roles/docker-engine/` — role directory
- `shared/active/02-config/ansible/roles/docker-engine/defaults/main.yml`
- `shared/active/02-config/ansible/roles/docker-engine/tasks/main.yml`
- `shared/active/02-config/ansible/roles/docker-engine/handlers/main.yml`
- `levonk/active/02-config/ansible/group_vars/cloud_server.yml` — Docker-related variables

## Acceptance Criteria

- [ ] Docker engine and docker-compose plugin are installed
- [ ] `daemon.json` contains hardened settings (userns-remap, no-new-privileges, live-restore)
- [ ] `cuser` can run `docker ps` without sudo
- [ ] Docker service is enabled and running
- [ ] `ansible-lint` passes

## Test Plan

- Lint: `devbox run ansible-lint shared/active/02-config/ansible/roles/docker-engine/`
- Dry-run: `devbox run ansible-playbook --check --diff -i levonk/active/02-config/ansible/inventories/oci.yml shared/active/02-config/ansible/roles/docker-engine/tests/test.yml`

## Observability

- Log Docker version and daemon configuration after install
- Monitor Docker daemon health

## Compliance

- No hardcoded paths in tasks; all paths via variables
- Hardened daemon configuration per security best practices
- Uses Nix or OS packages consistently

## Risks & Mitigations

- Risk: Docker rootless mode conflicts with existing containers — Mitigation: Default to userns-remap first, document rootless migration
- Risk: Docker Compose plugin version mismatch — Mitigation: Pin versions in variables

## Dependencies & Sequencing

- Depends on: 01-001 (variables), 01-002 (inventory)
- Unblocks: 03-001 (bootstrap playbook), 02-010..02-013 (Docker-based roles)

## Definition of Done

- Role installs and hardens Docker correctly
- CI passes lint and tests
- Story file updated to `done`

## Commit Conventions

- `feat(ansible): add docker-engine role with hardened daemon.json`
- `test(ansible): add docker-engine role tests`

## Changelog

- 2026-05-29: initialized story file
