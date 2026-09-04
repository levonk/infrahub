---
story_id: "03-001"
story_title: "Deploy Nix Sidecar Container"
story_name: "nix-sidecar"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 1
branch: "feature/current/isolation-vm/story-03-001-nix-sidecar"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: ["02-002", "02-003"]
parallel_safe: true
modules: ["containers"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "containers"]
due: "2026-06-30"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Deploy the nix-sidecar container to provide Nix package management to other agent containers. This implements the Nix sidecar pattern for dependency management.

## Sub-Tasks

- [x] Pull or build nix-sidecar container image
- [x] Create Docker Compose or Ansible deployment for nix-sidecar
- [x] Configure volume mounts: /nix (read-only), /nix-var-profiles (read-only)
- [x] Configure container networking to use Docker bridge
- [x] Set container restart policy
- [x] Configure resource limits (CPU, memory)
- [x] Test Nix functionality from within container
- [x] Document Nix store sharing mechanism

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/main.yml` - Main role entry point
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/nix-sidecar.yml` - Nix sidecar deployment tasks
- `shared/active/02-config/ansible/roles/isolation-vm-containers/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/isolation-vm-containers/handlers/main.yml` - Container handlers
- `shared/active/02-config/ansible/roles/isolation-vm-containers/meta/main.yml` - Role metadata
- `shared/active/02-config/ansible/roles/isolation-vm-containers/README.md` - Role documentation
- `shared/active/02-config/ansible/playbooks/deploy-isolation-vm-containers.yml` - Deployment playbook

## Acceptance Criteria

- [x] nix-sidecar container is running and healthy
- [x] Nix store is accessible via volume mounts
- [x] Container can run Nix commands successfully
- [x] Volume mounts are correctly configured (read-only where appropriate)
- [x] Container restarts automatically on failure
- [x] Resource limits are applied

## Test Plan

- Manual: Run `docker ps` to verify container is running
- Manual: Exec into container and run `nix --version`
- Validate: Test Nix package installation from within container
- Validate: Verify volume mounts with `docker inspect`

## Observability

- Monitor container health and resource usage
- Log Nix operations
- Track volume mount performance

## Compliance

- Follow container guidelines from shared/active/03-container/AGENTS.md
- Use variable-driven configuration
- Ensure no hardcoded values

## Risks & Mitigations

- Risk: Nix store volume may become large — Mitigation: Monitor disk usage and implement cleanup
- Risk: Volume mount permissions may be incorrect — Mitigation: Test thoroughly

## Dependencies

- Story 02-002 (Docker server installation) must be complete
- Story 02-003 (VM networking and users) must be complete
- nix-sidecar container image must be available

## Notes

- Nix sidecar provides Nix to other containers via volume mounts
- This pattern avoids installing Nix directly in each container
- Document the Nix version and channel being used
- Consider Nix garbage collection strategy
