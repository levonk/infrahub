---
story_id: "02-003"
story_title: "Configure VM Networking and User Access"
story_name: "vm-networking-users"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 2
parallel_id: 3
branch: "feature/current/isolation-vm/story-02-003-vm-networking-users"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["02-001"]
parallel_safe: true
modules: ["vm-config"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "networking"]
due: "2026-06-28"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Configure basic networking, user accounts, and CLI tools inside the Isolation VM. This provides the foundation for agent container operations.

## Sub-Tasks

- [x] Configure network interfaces for both bridges (NAT and routed)
- [x] Set up DNS resolution inside VM
- [x] Configure routing table for external access via routed bridge
- [x] Create non-root user (cuser) with sudo access
- [x] Configure SSH access for cuser user
- [x] Install basic CLI tools: zsh, tmux, curl, git, vim
- [x] Configure zsh as default shell for cuser
- [x] Set up basic tmux configuration
- [x] Configure timezone and locale
- [x] Test user login and basic tool functionality

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm-config/` - New Ansible role for VM configuration
- `shared/active/02-config/ansible/roles/isolation-vm-config/tasks/main.yml` - Main task file
- `shared/active/02-config/ansible/roles/isolation-vm-config/tasks/networking.yml` - Network configuration
- `shared/active/02-config/ansible/roles/isolation-vm-config/tasks/users.yml` - User configuration
- `shared/active/02-config/ansible/roles/isolation-vm-config/tasks/tools.yml` - CLI tools installation
- `shared/active/02-config/ansible/roles/isolation-vm-config/tasks/system.yml` - System configuration
- `shared/active/02-config/ansible/roles/isolation-vm-config/templates/interfaces.j2` - Network interfaces template
- `shared/active/02-config/ansible/roles/isolation-vm-config/templates/resolv.conf.j2` - DNS configuration template
- `shared/active/02-config/ansible/roles/isolation-vm-config/templates/routes.j2` - Routing configuration template
- `shared/active/02-config/ansible/roles/isolation-vm-config/defaults/main.yml` - Default variables
- `shared/active/02-config/ansible/roles/isolation-vm-config/handlers/main.yml` - Service handlers
- `shared/active/02-config/ansible/roles/isolation-vm-config/meta/main.yml` - Role metadata
- `shared/active/02-config/ansible/playbooks/configure-isolation-vm.yml` - Configuration playbook
- `levonk/active/02-config/ansible/inventories/oci.yml` - Updated with isolation_vms host group
- `levonk/active/02-config/ansible/host_vars/oci-cloud-server.yml` - Added SSH public key variable

## Acceptance Criteria

- [x] VM has functional network connectivity on both bridges
- [x] DNS resolution works inside VM
- [x] Non-root user (cuser) exists with sudo access
- [x] SSH access works for cuser user
- [x] Basic CLI tools are installed and functional
- [x] zsh is default shell for cuser
- [x] tmux is configured and usable
- [x] All configuration is variable-driven

## Test Plan

- Manual: SSH into VM as cuser user
- Manual: Test network connectivity with `ping` and `curl`
- Validate: Test DNS resolution with `nslookup` or `dig`
- Validate: Verify sudo access with `sudo -l`
- Validate: Test zsh and tmux functionality

## Observability

- Monitor network connectivity
- Log user login events
- Track system resource usage

## Compliance

- Follow Ansible best practices from AGENTS.md
- Use variable-driven configuration
- Follow security best practices for user access

## Risks & Mitigations

- Risk: Network configuration may break connectivity — Mitigation: Test thoroughly before proceeding
- Risk: Sudo access may be too permissive — Mitigation: Follow principle of least privilege

## Dependencies

- Story 02-001 (Debian VM creation) must be complete
- VM must be accessible via SSH

## Notes

- Use SSH keys for authentication, not passwords
- Configure sudo to require password for security
- Document user access procedures
- Consider setting up SSH bastion host access patterns
