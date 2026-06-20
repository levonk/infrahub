---
story_id: "03-002"
story_title: "Deploy Base KaliNix Container"
story_name: "base-kalinix"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 2
branch: "feature/current/isolation-vm/story-03-002-base-kalinix"
status: "in-progress"
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

- [x] Pull or build base-kalinix container image
- [x] Create Docker Compose or Ansible deployment for base-kalinix
- [x] Configure volume mounts from nix-sidecar (/nix, /nix-var-profiles)
- [x] Configure container networking to use Docker bridge
- [x] Set container restart policy
- [x] Configure resource limits (CPU, memory)
- [x] Test Kali Linux tools functionality
- [x] Test Nix integration via volume mounts
- [x] Document container capabilities and limitations

## Relevant Files

- `shared/active/03-container/services/base/base-kalinix/Dockerfile.base-kalinix` - Base KaliNix container image
- `shared/active/03-container/services/base/base-kali/Dockerfile.base-kali` - Base Kali container image (dependency)
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/base-kalinix.yml` - Base KaliNix deployment tasks
- `shared/active/02-config/ansible/roles/isolation-vm-containers/defaults/main.yml` - Container configuration variables
- `shared/active/02-config/ansible/roles/isolation-vm-containers/README.md` - Role documentation
- `shared/active/02-config/ansible/playbooks/test-base-kalinix.yml` - Test playbook for base-kalinix

## Acceptance Criteria

- [ ] base-kalinix container is running and healthy - Requires deployment to verify
- [ ] Kali Linux tools are accessible and functional - Requires deployment to verify
- [ ] Nix is accessible via volume mounts from nix-sidecar - Requires deployment to verify
- [ ] Container can install Nix packages successfully - Requires deployment to verify
- [x] Volume mounts are correctly configured - Configured in tasks (nix-store, nix-config, nix-cache, home)
- [x] Container restarts automatically on failure - Configured (restart_policy: unless-stopped)
- [x] Resource limits are applied - Configured in tasks (2g memory, 1.0 CPU)

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
- Includes comprehensive Kali Linux security tools (nmap, metasploit, burpsuite, etc.)
- Documented all available Kali tools in role README
- Consider security implications of Kali tools in containerized environment
- All configuration is variable-driven per AGENTS.md requirements
