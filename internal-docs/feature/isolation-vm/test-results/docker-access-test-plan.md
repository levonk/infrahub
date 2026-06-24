# Docker Access Test Plan - Isolation VM

**Story**: 04-001 - Test Agent Container Docker Access  
**Date**: 2026-06-20  
**Purpose**: Validate Docker-in-Docker functionality from agent containers

## Test Objectives

1. Validate that agent containers can access Docker socket
2. Test basic Docker command execution from within containers
3. Verify container creation and lifecycle management
4. Test advanced Docker features (volumes, networks, resource limits)
5. Validate cleanup operations
6. Document any limitations or security concerns

## Test Environment

- **Target**: OCI Cloud Server (oci-cloud-server)
- **Test Container**: Hermes agent container (hermes-agent)
- **Docker Socket**: Mounted from host at `/var/run/docker.sock`
- **Test Images**: nginx:alpine (lightweight for testing)

## Test Cases

### TC-001: Basic Docker Commands
**Objective**: Verify basic Docker CLI functionality from Hermes container

**Steps**:
1. Execute `docker ps` from Hermes container
2. Execute `docker version` from Hermes container
3. Execute `docker info` from Hermes container

**Expected Results**:
- All commands execute successfully
- Output shows Docker daemon information
- No permission errors

**Status**: ⏳ Pending

---

### TC-002: Container Creation
**Objective**: Test ability to create new containers from Hermes container

**Steps**:
1. Create nginx:alpine container with name `docker-access-test-{timestamp}`
2. Verify container appears in `docker ps` output
3. Check container status is "Up"

**Expected Results**:
- Container created successfully
- Container appears in process list
- Container is running

**Status**: ⏳ Pending

---

### TC-003: Container Lifecycle Management
**Objective**: Test start, stop, and remove operations

**Steps**:
1. Stop the test container
2. Verify container no longer appears in `docker ps`
3. Remove the test container
4. Verify container no longer appears in `docker ps -a`

**Expected Results**:
- Container stops successfully
- Container removes successfully
- No orphaned containers remain

**Status**: ⏳ Pending

---

### TC-004: Volume Mounting
**Objective**: Test volume mount functionality for agent-created containers

**Steps**:
1. Create container with host volume mount: `-v /tmp:/tmp`
2. Execute command in container to list mounted directory
3. Verify directory contents are accessible

**Expected Results**:
- Volume mount succeeds
- Container can access host directory
- File operations work correctly

**Status**: ⏳ Pending

---

### TC-005: Resource Limits
**Objective**: Test resource limit enforcement for agent-created containers

**Steps**:
1. Create container with memory limit: `--memory=512m`
2. Create container with CPU limit: `--cpus=0.5`
3. Inspect container to verify limits are applied
4. Check container HostConfig.Memory and HostConfig.NanoCpus

**Expected Results**:
- Resource limits are accepted
- Limits are visible in container inspection
- Limits are enforced by Docker daemon

**Status**: ⏳ Pending

---

### TC-006: Network Configuration
**Objective**: Test custom network creation and container networking

**Steps**:
1. Create custom Docker network: `test-network-{timestamp}`
2. Run container on custom network
3. Verify container gets IP address on custom network
4. Clean up network and container

**Expected Results**:
- Network creation succeeds
- Container joins network successfully
- Container has valid IP address
- Network cleanup succeeds

**Status**: ⏳ Pending

---

### TC-007: Cleanup Operations
**Objective**: Verify proper cleanup of test resources

**Steps**:
1. Stop all test containers
2. Remove all test containers
3. Remove test networks
4. Verify no orphaned resources remain

**Expected Results**:
- All test containers removed
- All test networks removed
- No resource leaks

**Status**: ⏳ Pending

---

## Test Execution

### Automated Test Playbook

**Playbook**: `shared/active/02-config/ansible/playbooks/test-docker-access.yml`  
**Role**: `shared/active/02-config/ansible/roles/isolation-vm-tests/`  
**Test Tasks**: `shared/active/02-config/ansible/roles/isolation-vm-tests/tasks/docker-access.yml`

**Execution Command**:
```bash
cd ~/p/gh/levonk/infrahub
devbox run -- ansible-playbook -i levonk/active/02-config/ansible/inventories/oci.yml \
  shared/active/02-config/ansible/playbooks/test-docker-access.yml \
  --vault-password-file ~/.ansible/vault_password
```

### Manual Test Execution

For manual verification, exec into Hermes container:
```bash
docker exec -it hermes-agent bash
```

Then run test commands manually as documented in each test case.

## Success Criteria

- ✅ All 7 test cases pass
- ✅ No permission errors encountered
- ✅ No resource leaks after cleanup
- ✅ Docker socket access is functional
- ✅ Advanced Docker features work correctly

## Known Limitations

- None identified yet

## Security Considerations

- Docker socket access provides container root access to host Docker daemon
- This is intentional for agent isolation model
- Monitor for any unexpected permission escalations
- Ensure test containers are cleaned up promptly

## Test Results Summary

**Overall Status**: ⏸️ Blocked - Containers Not Deployed  
**Test Cases Completed**: 0/7  
**Passed**: 0  
**Failed**: 0  
**Blocked**: 7

### Detailed Results

| Test Case | Status | Result | Notes |
|----------|--------|--------|-------|
| TC-001: Basic Docker Commands | 🚫 Blocked | - | Hermes container not running |
| TC-002: Container Creation | 🚫 Blocked | - | Hermes container not running |
| TC-003: Container Lifecycle Management | 🚫 Blocked | - | Hermes container not running |
| TC-004: Volume Mounting | 🚫 Blocked | - | Hermes container not running |
| TC-005: Resource Limits | 🚫 Blocked | - | Hermes container not running |
| TC-006: Network Configuration | 🚫 Blocked | - | Hermes container not running |
| TC-007: Cleanup Operations | 🚫 Blocked | - | Hermes container not running |

## Current State Assessment

**Infrastructure Status**:
- ✅ OCI Cloud Server: Running and accessible
- ✅ Hypervisor (KVM/libvirt/QEMU): Installed and configured
- ✅ Storage Pools: Configured and active
- ✅ Bridge Networks: NAT and routed bridges configured
- ✅ Isolation VM: Running (virsh shows "isolation-vm running")
- ❌ Isolation VM SSH: Not accessible (connection timeout)
- ❌ Agent Containers: Not deployed (Hermes, nix-sidecar, base-kalinix not found)

**Root Cause Analysis**:
The Phase 03 agent containers (Stories 03-001 through 03-004) were marked as complete in the task index, but the actual container deployment has not been executed. The Isolation VM is running but not fully configured for SSH access, and the agent containers have not been deployed inside the VM.

**Blocker**: Story 04-001 cannot proceed until:
1. Isolation VM SSH connectivity is established
2. Agent containers from Phase 03 are actually deployed
3. Docker-in-Docker functionality can be tested

## Next Steps

1. **Immediate**: Document current blocker status in story file
2. **Required**: Re-execute Phase 03 deployment playbooks to deploy agent containers
3. **Required**: Fix Isolation VM SSH connectivity issues
4. **Then**: Resume Docker access testing once containers are running
5. **Finally**: Update acceptance criteria based on actual test results
