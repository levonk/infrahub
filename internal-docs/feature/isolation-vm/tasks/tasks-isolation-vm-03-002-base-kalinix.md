---
story_id: "03-002"
story_title: "Deploy Base KaliNix Container"
story_name: "base-kalinix"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 2
branch: "feature/current/isolation-vm/story-03-002-base-kalinix"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001"]
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

Deploy the base-kalinix container that provides Kali Linux + Nix environment for agent operations. This container will be used as the base for agent workloads.

## Sub-Tasks

- [ ] Pull or build base-kalinix container image
- [ ] Create Docker Compose or Ansible deployment for base-kalinix
- [ ] Configure volume mounts from nix-sidecar (/nix, /nix-var-profiles)
- [ ] Configure container networking to use Docker bridge
- [ ] Set container restart policy
- [ ] Configure resource limits (CPU, memory)
- [ ] Test Kali Linux tools functionality
- [ ] Test Nix integration via volume mounts
- [ ] Document container capabilities and limitations

## Relevant Files

- `shared/active/03-container/docker-compose/isolation-vm/docker-compose.yml` - Docker Compose configuration
- `shared/active/02-config/ansible/roles/isolation-vm-containers/` - Ansible role for container deployment
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/base-kalinix.yml` - Base KaliNix deployment
- `shared/active/02-config/ansible/inventory/group_vars/isolation_vm.yml` - Container configuration variables

## Acceptance Criteria

- [ ] base-kalinix container is running and healthy
- [ ] Kali Linux tools are accessible and functional
- [ ] Nix is accessible via volume mounts from nix-sidecar
- [ ] Container can install Nix packages successfully
- [ ] Volume mounts are correctly configured
- [ ] Container restarts automatically on failure
- [ ] Resource limits are applied

## Test Plan

- Manual: Run `docker ps` to verify container is running
- Manual: Exec into container and run `nix --version`
- Validate: Test Kali tool functionality (e.g., nmap, wireshark if available)
- Validate: Test Nix package installation from within container
- Validate: Verify volume mounts with `docker inspect`

## Observability

- Monitor container health and resource usage
- Log Kali tool operations
- Track Nix package installations

## Compliance

- Follow container guidelines from shared/active/03-container/AGENTS.md
- Use variable-driven configuration
- Ensure no hardcoded values
- Follow security best practices for Kali Linux tools

## Risks & Mitigations

- Risk: Kali tools may require additional permissions — Mitigation: Test and configure capabilities as needed
- Risk: Volume mount performance may be slow — Mitigation: Monitor and optimize if needed

## Dependencies

- Story 03-001 (nix-sidecar deployment) must be complete
- base-kalinix container image must be available

## Notes

- base-kalinix provides security tools + Nix environment
- This container serves as the base for agent operations
- Document which Kali tools are included
- Consider security implications of Kali tools in containerized environment
