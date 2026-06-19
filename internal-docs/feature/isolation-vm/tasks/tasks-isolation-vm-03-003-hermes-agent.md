---
story_id: "03-003"
story_title: "Deploy Hermes Agent Container"
story_name: "hermes-agent"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 3
branch: "feature/current/isolation-vm/story-03-003-hermes-agent"
status: "todo"
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

- [ ] Pull or build Hermes agent container image
- [ ] Create Docker Compose or Ansible deployment for Hermes agent
- [ ] Configure Docker socket mount (/var/run/docker.sock)
- [ ] Configure volume mounts from nix-sidecar (/nix, /nix-var-profiles)
- [ ] Configure container networking to use Docker bridge
- [ ] Set container restart policy
- [ ] Configure resource limits (CPU, memory)
- [ ] Test Docker socket access from within container
- [ ] Test container creation from within Hermes container
- [ ] Document agent container capabilities and security boundaries

## Relevant Files

- `shared/active/03-container/docker-compose/isolation-vm/docker-compose.yml` - Docker Compose configuration
- `shared/active/02-config/ansible/roles/isolation-vm-containers/` - Ansible role for container deployment
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/hermes-agent.yml` - Hermes agent deployment
- `shared/active/02-config/ansible/inventory/group_vars/isolation_vm.yml` - Container configuration variables

## Acceptance Criteria

- [ ] Hermes agent container is running and healthy
- [ ] Docker socket is accessible from within container
- [ ] Container can create and manage other Docker containers
- [ ] Nix is accessible via volume mounts from nix-sidecar
- [ ] Volume mounts are correctly configured
- [ ] Container restarts automatically on failure
- [ ] Resource limits are applied
- [ ] Docker socket access is properly secured

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
