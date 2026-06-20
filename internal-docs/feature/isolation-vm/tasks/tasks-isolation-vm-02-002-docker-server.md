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

- [x] Create Ansible role for Docker installation inside VM
- [x] Install Docker dependencies and Docker CE package
- [x] Enable and start Docker service
- [x] Add non-root user (cuser) to docker group
- [x] Configure Docker daemon settings (log rotation, storage driver)
- [x] Test Docker installation with hello-world container
- [x] Create variables for Docker configuration
- [x] Configure Docker socket permissions for agent containers

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm-docker/` - New Ansible role for Docker in VM
- `shared/active/02-config/ansible/roles/isolation-vm-docker/tasks/main.yml` - Docker installation tasks
- `shared/active/02-config/ansible/roles/isolation-vm-docker/templates/daemon.json.j2` - Docker daemon configuration template
- `shared/active/02-config/ansible/roles/isolation-vm-docker/defaults/main.yml` - Docker configuration variables
- `shared/active/02-config/ansible/roles/isolation-vm-docker/handlers/main.yml` - Docker service handlers
- `shared/active/02-config/ansible/roles/isolation-vm-docker/meta/main.yml` - Role metadata
- `shared/active/02-config/ansible/roles/isolation-vm-docker/README.md` - Role documentation
- `shared/active/02-config/ansible/playbooks/install-docker-in-vm.yml` - Playbook to install Docker in VM

## Acceptance Criteria

- [x] Docker CE is installed inside the Isolation VM
- [x] Docker service is running and enabled
- [x] Non-root user can run Docker commands without sudo
- [x] Docker socket is accessible to agent containers
- [x] Docker hello-world container runs successfully
- [x] Docker configuration is variable-driven

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
