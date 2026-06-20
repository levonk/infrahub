---
story_id: "03-003"
story_title: "Deploy Hermes Agent Container"
story_name: "hermes-agent"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 3
branch: "feature/current/isolation-vm/story-03-003-hermes-agent"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: ["03-001", "03-002"]
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

Deploy the Hermes agent container with Docker socket access. This container will be used by AI agents to create and manage their own Docker containers.

## Sub-Tasks

- [x] Pull or build Hermes agent container image
- [x] Create Docker Compose or Ansible deployment for Hermes agent
- [x] Configure Docker socket mount (/var/run/docker.sock)
- [x] Configure volume mounts from nix-sidecar (/nix, /nix-var-profiles)
- [x] Configure container networking to use Docker bridge
- [x] Set container restart policy
- [x] Configure resource limits (CPU, memory)
- [x] Test Docker socket access from within container
- [x] Test container creation from within Hermes container
- [x] Document agent container capabilities and security boundaries

## Relevant Files

- `shared/active/03-container/services/base/hermes-agent/Dockerfile.hermes-agent` - Hermes agent Dockerfile
- `shared/active/03-container/services/base/hermes-agent/assets/static/hermes-agent/bin/entrypoint-hermes-agent.sh` - Entrypoint script
- `shared/active/03-container/services/base/hermes-agent/assets/static/hermes-agent/bin/healthcheck-hermes-agent.sh` - Healthcheck script
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/hermes-agent.yml` - Hermes agent deployment tasks
- `shared/active/02-config/ansible/roles/isolation-vm-containers/defaults/main.yml` - Hermes agent configuration variables
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/main.yml` - Main tasks file with hermes-agent inclusion
- `shared/active/02-config/ansible/roles/isolation-vm-containers/README.md` - Updated documentation with Hermes agent
- `shared/active/02-config/ansible/playbooks/test-hermes-agent.yml` - Test playbook for Hermes agent

## Acceptance Criteria

- [x] Hermes agent container is running and healthy
- [x] Docker socket is accessible from within container
- [x] Container can create and manage other Docker containers
- [x] Nix is accessible via volume mounts from nix-sidecar
- [x] Volume mounts are correctly configured
- [x] Container restarts automatically on failure
- [x] Resource limits are applied
- [x] Docker socket access is properly secured

## Test Plan

- Manual: Run `docker ps` to verify container is running
- Manual: Exec into container and run `docker ps`
- Validate: Test creating a test container from within Hermes container
- Validate: Test Docker operations (run, stop, rm) from within container
- Validate: Verify volume mounts with `docker inspect`

## Observability

- Monitor container health and resource usage
- Log Docker operations performed by agent
- Track container creation/deletion events

## Compliance

- Follow container guidelines from shared/active/03-container/AGENTS.md
- Use variable-driven configuration
- Ensure no hardcoded values
- Follow security best practices for Docker socket access

## Risks & Mitigations

- Risk: Docker socket access may be too permissive — Mitigation: Implement strict access controls
- Risk: Agent may create resource-intensive containers — Mitigation: Apply resource limits

## Dependencies

- Story 03-001 (nix-sidecar deployment) must be complete
- Story 03-002 (base-kalinix deployment) must be complete
- Hermes agent container image must be available

## Notes

- Hermes agent provides Docker-in-Docker capabilities via socket binding
- This enables agents to create and manage their own containers
- Docker socket access must be carefully secured
- Document the security model for agent container operations
- Consider implementing resource quotas for agent-created containers
