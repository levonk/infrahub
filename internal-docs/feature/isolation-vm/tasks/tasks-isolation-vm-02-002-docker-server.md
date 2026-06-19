---
story_id: "02-002"
story_title: "Install Docker Server in VM"
story_name: "docker-server"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 2
parallel_id: 2
branch: "feature/current/isolation-vm/story-02-002-docker-server"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001"]
parallel_safe: true
modules: ["vm-services"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "containers"]
due: "2026-06-28"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Install and configure Docker server inside the Isolation VM. This provides the container runtime for agent containers.

## Sub-Tasks

- [ ] Create Ansible role for Docker installation inside VM
- [ ] Install Docker dependencies and Docker CE package
- [ ] Enable and start Docker service
- [ ] Add non-root user (cuser) to docker group
- [ ] Configure Docker daemon settings (log rotation, storage driver)
- [ ] Test Docker installation with hello-world container
- [ ] Configure Docker socket permissions for agent containers
- [ ] Create variables for Docker configuration

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm-docker/` - New Ansible role for Docker in VM
- `shared/active/02-config/ansible/roles/isolation-vm-docker/tasks/main.yml` - Docker installation tasks
- `shared/active/02-config/ansible/roles/isolation-vm-docker/templates/daemon.json` - Docker daemon configuration
- `shared/active/02-config/ansible/inventory/group_vars/isolation_vm.yml` - VM-specific variables

## Acceptance Criteria

- [ ] Docker CE is installed inside the Isolation VM
- [ ] Docker service is running and enabled
- [ ] Non-root user can run Docker commands without sudo
- [ ] Docker socket is accessible to agent containers
- [ ] Docker hello-world container runs successfully
- [ ] Docker configuration is variable-driven

## Test Plan

- Manual: SSH into VM and run `docker version`
- Manual: Run `docker run hello-world` to test basic functionality
- Validate: Check Docker service status with `systemctl status docker`
- Validate: Verify user group membership with `groups cuser`

## Observability

- Enable Docker daemon logging
- Monitor Docker service health
- Log container operations

## Compliance

- Follow container guidelines from shared/active/03-container/AGENTS.md
- Use variable-driven configuration
- Ensure no hardcoded values

## Risks & Mitigations

- Risk: Docker installation may conflict with VM resources — Mitigation: Monitor VM resource usage
- Risk: Docker socket permissions may be too permissive — Mitigation: Follow security best practices

## Dependencies

- Story 02-001 (Debian VM creation) must be complete
- VM must be accessible via SSH

## Notes

- Use official Docker repository for package installation
- Configure Docker to use systemd for service management
- Consider Docker log rotation to prevent disk exhaustion
- Document Docker version for reproducibility
