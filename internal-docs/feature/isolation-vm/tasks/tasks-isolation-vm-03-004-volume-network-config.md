---
story_id: "03-004"
story_title: "Configure Volume Mounts and Networking"
story_name: "volume-network-config"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 3
parallel_id: 4
branch: "feature/current/isolation-vm/story-03-004-volume-network-config"
status: "in-progress"
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

- [x] Review and validate all volume mount configurations
- [x] Ensure Nix store mounts are read-only where appropriate
- [x] Configure Docker networks for container isolation
- [x] Set up network routing rules for container egress
- [x] Configure firewall rules for container network isolation
- [x] Test inter-container communication
- [x] Test container-to-external-network communication
- [x] Verify VPN/proxy routing for container traffic
- [x] Document network topology and routing rules
- [x] Create variables for all network and volume configurations

## Relevant Files

- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/networking.yml` - Network configuration (created)
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/volumes.yml` - Volume mount configuration (created)
- `shared/active/02-config/ansible/roles/isolation-vm-containers/tasks/main.yml` - Main tasks file (updated to include networking and volumes)
- `shared/active/02-config/ansible/roles/isolation-vm-containers/defaults/main.yml` - Added network and VPN routing variables
- `shared/active/02-config/ansible/roles/isolation-vm-containers/handlers/main.yml` - Added Docker restart and sysctl reload handlers
- `shared/active/02-config/ansible/playbooks/test-isolation-vm-networking.yml` - Comprehensive test playbook (created)
- `shared/active/08-docs/network/isolation-vm-network-topology.md` - Network topology documentation (created)

## Acceptance Criteria

- [x] All volume mounts are correctly configured and functional
- [x] Nix store is accessible from agent containers
- [x] Container networks are properly isolated
- [x] Container egress routing works through VPN/proxy
- [x] Firewall rules enforce network isolation
- [x] Inter-container communication works as expected
- [x] All configurations are variable-driven
- [x] Network topology is documented

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
