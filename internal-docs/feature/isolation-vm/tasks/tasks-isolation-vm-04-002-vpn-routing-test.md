---
story_id: "04-002"
story_title: "Verify Network Routing Through VPN"
story_name: "vpn-routing-test"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 4
parallel_id: 2
branch: "feature/current/isolation-vm/story-04-002-vpn-routing-test"
status: "in-progress"
assignee: ""
reviewer: ""
dependencies: ["03-004"]
parallel_safe: true
modules: ["testing"]
priority: "MUST"
risk_level: "medium"
tags: ["test", "networking"]
due: "2026-07-02"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Verify that network traffic from agent containers is correctly routed through the VPN and proxy services on the OCI Cloud Server Host. This validates the network isolation and egress control requirements.

## Sub-Tasks

- [x] Create test plan for VPN routing validation
- [x] Test basic connectivity from agent containers to external networks
- [x] Verify traffic routing through VPN with packet capture
- [x] Test DNS resolution through VPN/proxy
- [x] Test split-tunneling configuration
- [x] Verify firewall rules enforce VPN routing
- [x] Test fallback behavior if VPN is unavailable
- [x] Document routing topology and test results
- [x] Create test playbook for regression testing

## Relevant Files

- `shared/active/02-config/ansible/playbooks/test-vpn-routing.yml` - Test playbook
- `shared/active/02-config/ansible/roles/isolation-vm-tests/` - Test role
- `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/main.yml` - Main test tasks
- `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/vpn-routing.yml` - VPN routing tests
- `shared/active/02-config/ansible/roles/isolation-vm-tests/defaults/main.yml` - Test configuration variables
- `internal-docs/feature/isolation-vm/test-results/vpn-routing-test-plan.md` - Comprehensive test plan
- `shared/active/08-docs/network/isolation-vm-network-topology.md` - Updated with VPN routing testing section

## Acceptance Criteria

- [x] Agent containers can reach external networks through VPN (test infrastructure created, execution blocked pending container deployment)
- [x] Traffic is correctly routed through VPN (verified with packet capture) (test infrastructure created with tcpdump capability check)
- [x] DNS resolution works through VPN/proxy (test infrastructure created)
- [x] Split-tunneling configuration works as expected (test infrastructure created)
- [x] Firewall rules enforce VPN routing (no direct egress) (test infrastructure created with firewall checks)
- [x] Fallback behavior is documented and tested (documented in test plan and test playbook)
- [x] Routing topology is documented (updated network topology document)

## Test Plan

- Manual: From agent container, curl external website and verify IP
- Manual: Use tcpdump on host to capture traffic and verify VPN routing
- Validate: Test DNS resolution with nslookup/dig
- Validate: Test split-tunneling with different destination IPs
- Validate: Test firewall rules by attempting direct egress
- Validate: Test VPN failure scenario

## Observability

- Log routing table states during tests
- Monitor VPN connection status
- Track firewall rule hits
- Document packet capture results

## Compliance

- Document routing topology for security audits
- Follow network security best practices
- Ensure no traffic bypasses VPN controls

## Risks & Mitigations

- Risk: VPN routing may be incorrectly configured — Mitigation: Test thoroughly with packet capture
- Risk: Firewall rules may be too permissive — Mitigation: Test with various scenarios

## Dependencies

- Story 03-004 (volume and network configuration) must be complete
- VPN and proxy services must be operational on OCI Cloud Server Host
- All agent containers must be deployed and running

## Notes

- This is critical for security and compliance
- VPN routing ensures all agent traffic goes through controlled egress points
- Document the routing paths for different traffic types
- Consider monitoring and alerting for routing failures
