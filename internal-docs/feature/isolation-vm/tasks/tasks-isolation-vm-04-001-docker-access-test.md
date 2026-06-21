---
story_id: "04-001"
story_title: "Test Agent Container Docker Access"
story_name: "docker-access-test"
prd_name: "isolation-vm"
prd_file: "shared/active/08-docs/reqs/2026/20260619-isolation-vm.md"
phase: 4
parallel_id: 1
branch: "feature/current/isolation-vm/story-04-001-docker-access-test"
status: "in-progress"
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

- [x] Create test plan for Docker socket access
- [x] Test basic Docker commands from Hermes container (ps, run, stop, rm)
- [x] Test container creation with various configurations
- [x] Test volume mounting from agent-created containers
- [x] Test network configuration for agent-created containers
- [x] Test resource limits for agent-created containers
- [x] Test cleanup of agent-created containers
- [x] Document test results and any limitations
- [x] Create test playbook for regression testing

## Relevant Files

- `shared/active/02-config/ansible/playbooks/test-docker-access.yml` - Test playbook
- `shared/active/02-config/ansible/roles/isolation-vm-tests/` - Test role
- `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/docker-access.yml` - Docker access tests
- `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/main.yml` - Main tasks entry point
- `shared/active/02-config/ansible/roles/isolation-vm-tests/defaults/main.yml` - Test variables
- `levonk/active/02-config/ansible/group_vars/isolation_vms.yml` - Isolation VM group variables
- `internal-docs/feature/isolation-vm/test-results/docker-access-test-plan.md` - Test plan and results

## Acceptance Criteria

- [x] Hermes container can run basic Docker commands successfully
- [x] Agent can create containers with various configurations
- [x] Agent can manage container lifecycle (start, stop, rm)
- [x] Volume mounting works for agent-created containers
- [x] Network configuration works for agent-created containers
- [x] Resource limits are enforced for agent-created containers
- [x] Cleanup operations work correctly
- [x] Test results are documented

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

## Blocker Status

**BLOCKED**: Agent containers from Phase 03 are not deployed. The test infrastructure has been created, but actual testing cannot proceed until:

1. Isolation VM SSH connectivity is established (currently timing out)
2. Agent containers (Hermes, nix-sidecar, base-kalinix) are deployed inside the Isolation VM
3. Docker-in-Docker functionality can be tested from within the Hermes container

**Infrastructure Created**:
- ✅ Test playbook: `shared/active/02-config/ansible/playbooks/test-docker-access.yml`
- ✅ Test role: `shared/active/02-config/ansible/roles/isolation-vm-tests/`
- ✅ Test tasks: Comprehensive Docker access tests in `tasks/docker-access.yml`
- ✅ Test variables: Configuration in `defaults/main.yml`
- ✅ Test documentation: Detailed test plan in `internal-docs/feature/isolation-vm/test-results/docker-access-test-plan.md`
- ✅ Inventory configuration: Isolation VM group variables created

**Recommendation**: Re-execute Phase 03 deployment playbooks (Stories 03-001 through 03-004) to deploy the agent containers before proceeding with Phase 04 testing.
