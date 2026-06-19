---
story_id: "04-001"
story_title: "Test Agent Container Docker Access"
story_name: "docker-access-test"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 4
parallel_id: 1
branch: "feature/current/isolation-vm/story-04-001-docker-access-test"
status: "todo"
assignee: ""
reviewer: ""
dependencies: ["03-004"]
parallel_safe: true
modules: ["testing"]
priority: "MUST"
risk_level: "low"
tags: ["test", "containers"]
due: "2026-07-02"
created_at: "2026-06-19"
updated_at: "2026-06-19"
---

## Summary

Test that agent containers can successfully create and manage Docker containers through the Docker socket. This validates the Docker-in-Docker functionality.

## Sub-Tasks

- [ ] Create test plan for Docker socket access
- [ ] Test basic Docker commands from Hermes container (ps, run, stop, rm)
- [ ] Test container creation with various configurations
- [ ] Test volume mounting from agent-created containers
- [ ] Test network configuration for agent-created containers
- [ ] Test resource limits for agent-created containers
- [ ] Test cleanup of agent-created containers
- [ ] Document test results and any limitations
- [ ] Create test playbook for regression testing

## Relevant Files

- `shared/active/02-config/ansible/playbooks/test-docker-access.yml` - Test playbook
- `shared/active/02-config/ansible/roles/isolation-vm-tests/` - Test role
- `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/docker-access.yml` - Docker access tests
- `internal-docs/feature/isolation-vm/test-results/` - Test results documentation

## Acceptance Criteria

- [ ] Hermes container can run basic Docker commands successfully
- [ ] Agent can create containers with various configurations
- [ ] Agent can manage container lifecycle (start, stop, rm)
- [ ] Volume mounting works for agent-created containers
- [ ] Network configuration works for agent-created containers
- [ ] Resource limits are enforced for agent-created containers
- [ ] Cleanup operations work correctly
- [ ] Test results are documented

## Test Plan

- Manual: Exec into Hermes container and run `docker ps`
- Manual: Create a test container: `docker run -d --name test nginx`
- Manual: Stop and remove test container
- Validate: Test with different container configurations
- Validate: Test volume mounting with test volumes
- Validate: Verify resource limits with stress tests

## Observability

- Log all Docker operations performed during tests
- Monitor container resource usage during tests
- Track test execution time and results

## Compliance

- Document test procedures for future reference
- Follow security best practices during testing
- Ensure test containers are cleaned up

## Risks & Mitigations

- Risk: Test containers may consume excessive resources — Mitigation: Monitor and clean up promptly
- Risk: Docker socket permissions may be insufficient — Mitigation: Document any permission issues

## Dependencies

- Story 03-004 (volume and network configuration) must be complete
- All agent containers must be deployed and running

## Notes

- This is a critical validation of the agent isolation model
- Test various Docker API operations to ensure full compatibility
- Consider edge cases (large containers, complex networks)
- Document any limitations found during testing
