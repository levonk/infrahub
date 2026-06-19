---
story_id: "03-004"
story_title: "Configure Volume Mounts and Networking"
story_name: "volume-network-config"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 4
branch: "feature/current/isolation-vm/story-03-004-volume-network-config"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-001", "03-002", "03-003"]
parallel_safe: true
modules: ["container-config"]
priority: "MUST"
risk_level: "medium"
tags: ["feat", "networking"]
due: "2026-06-30"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Configure volume mounts and networking for all agent containers to ensure proper integration with the Nix sidecar pattern and network isolation requirements.

## Sub-Tasks

- [ ] Review and validate all volume mount configurations
- [ ] Ensure Nix store mounts are read-only where appropriate
- [ ] Configure Docker networks for container isolation
- [ ] Set up network routing rules for container egress
- [ ] Configure firewall rules for container network isolation
- [ ] Test inter-container communication
- [ ] Test container-to-external-network communication
- [ ] Verify VPN/proxy routing for container traffic
- [ ] Document network topology and routing rules
- [ ] Create variables for all network and volume configurations

## Relevant Files

- `shared/active/03-container/docker-compose/isolation-vm/docker-compose.yml` - Docker Compose configuration
- `shared/active/02-config/ansible/roles/isolation-vm-containers/` - Ansible role for container deployment
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/networking.yml` - Network configuration
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/volumes.yml` - Volume mount configuration
- `shared/active/02-config/ansible/inventory/group_vars/isolation_vm.yml` - Network and volume variables

## Acceptance Criteria

- [ ] All volume mounts are correctly configured and functional
- [ ] Nix store is accessible from agent containers
- [ ] Container networks are properly isolated
- [ ] Container egress routing works through VPN/proxy
- [ ] Firewall rules enforce network isolation
- [ ] Inter-container communication works as expected
- [ ] All configurations are variable-driven
- [ ] Network topology is documented

## Test Plan

- Manual: Verify volume mounts with `docker inspect` for each container
- Manual: Test Nix access from each container
- Validate: Test network connectivity between containers
- Validate: Test external connectivity from containers
- Validate: Verify traffic routing through VPN with tcpdump or similar
- Validate: Test firewall rules with nmap or similar

## Observability

- Monitor volume mount performance
- Log network traffic patterns
- Track container network operations
- Monitor firewall rule hits

## Compliance

- Follow container guidelines from shared/active/03-container/AGENTS.md
- Use variable-driven configuration per AGENTS.md
- Ensure no hardcoded IP addresses or ports
- Follow security best practices for network isolation

## Risks & Mitigations

- Risk: Volume mount performance may be slow — Mitigation: Monitor and optimize if needed
- Risk: Network routing may bypass VPN — Mitigation: Implement strict firewall rules
- Risk: Container networks may conflict with host networks — Mitigation: Use dedicated subnets

## Dependencies

- Story 03-001 (nix-sidecar deployment) must be complete
- Story 03-002 (base-kalinix deployment) must be complete
- Story 03-003 (hermes-agent deployment) must be complete

## Notes

- This story ties together all container networking and storage
- Network isolation is critical for security
- Document the routing paths for different traffic types
- Consider implementing network policies for additional security
