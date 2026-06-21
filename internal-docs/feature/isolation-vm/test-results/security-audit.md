# Security Audit Test Plan - Isolation VM

**Date**: 2026-06-20  
**Feature**: Isolation VM Security Testing  
**PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`  
**Story**: 04-003 - Test Isolation and Security Boundaries

## Security Test Scope

This security audit validates the isolation and security boundaries between:
- Isolation VM and OCI Cloud Server Host
- Agent containers and host networks
- Agent containers and VPN credentials
- Inter-container isolation
- Resource isolation boundaries

## Security Requirements from PRD

1. **VM Isolation**: VM must be isolated from host services
2. **Docker Socket Isolation**: Agent containers must not have access to host Docker socket
3. **Network Control**: Network egress must be controlled via VPN/proxy
4. **Credential Protection**: VPN credentials must not be exposed to agent containers
5. **Access Control**: Root access must be restricted and audited
6. **Network Firewall**: VM network must be firewalled from host services

## Test Cases

### TC-001: VM Docker Socket Isolation
**Objective**: Verify VM cannot access host Docker socket  
**Risk Level**: Critical  
**Test Method**: Manual verification

**Steps**:
1. SSH into Isolation VM as cuser
2. Attempt to access host Docker socket at `/var/run/docker.sock`
3. Attempt to list host containers with `docker ps`
4. Attempt to create containers on host Docker daemon
5. Verify all attempts fail with permission/connection errors

**Expected Result**: All Docker socket access attempts fail

**Pass Criteria**: 
- [ ] Cannot connect to host Docker socket
- [ ] Cannot list host containers
- [ ] Cannot create containers on host

---

### TC-002: Agent Container Host Network Isolation
**Objective**: Verify agent containers cannot access host networks  
**Risk Level**: Critical  
**Test Method**: Network scanning from within containers

**Steps**:
1. Exec into nix-sidecar container
2. Run `nmap` or `netcat` scans of host network ranges
3. Attempt to connect to host services (SSH, HTTP, etc.)
4. Attempt to access host management ports
5. Verify network isolation is enforced

**Expected Result**: Cannot access host network services

**Pass Criteria**:
- [ ] Cannot reach host SSH port
- [ ] Cannot reach host management interfaces
- [ ] Network scans show only expected routes

---

### TC-003: VPN Credential Exposure Test
**Objective**: Verify VPN credentials are not exposed to agent containers  
**Risk Level**: Critical  
**Test Method**: Environment variable and file inspection

**Steps**:
1. Exec into each agent container (nix-sidecar, base-kalinix, hermes-agent)
2. List all environment variables: `env | grep -i vpn`
3. Search for credential files: `find / -name "*vpn*" -o -name "*cred*" 2>/dev/null`
4. Check container mounts for VPN credential paths
5. Verify no VPN credentials are accessible

**Expected Result**: No VPN credentials found in containers

**Pass Criteria**:
- [ ] No VPN-related environment variables
- [ ] No VPN credential files accessible
- [ ] Container mounts do not include VPN credential paths

---

### TC-004: VM Network Firewall Validation
**Objective**: Verify VM network is firewalled from host services  
**Risk Level**: High  
**Test Method**: Port scanning and firewall rule inspection

**Steps**:
1. From host, scan VM network range: `nmap -sS 192.168.100.0/24`
2. From VM, attempt to access host services on known ports
3. Inspect firewall rules on host: `firewall-cmd --list-all`
4. Inspect firewall rules in VM: `firewall-cmd --list-all`
5. Verify proper segmentation between networks

**Expected Result**: Firewall rules enforce network segmentation

**Pass Criteria**:
- [ ] Host services not accessible from VM
- [ ] VM services not accessible from host (except required)
- [ ] Firewall rules match security requirements

---

### TC-005: Privilege Escalation Boundaries
**Objective**: Test privilege escalation prevention  
**Risk Level**: High  
**Test Method**: Privilege escalation attempts

**Steps**:
1. In VM as cuser, attempt sudo access: `sudo -l`
2. Attempt container breakout from agent containers
3. Attempt to mount host filesystems from containers
4. Attempt to modify Docker socket permissions
5. Verify all privilege escalation attempts fail

**Expected Result**: Privilege escalation is prevented

**Pass Criteria**:
- [ ] Sudo access is properly restricted
- [ ] Container breakout attempts fail
- [ ] Host filesystems cannot be mounted
- [ ] Docker socket permissions cannot be modified

---

### TC-006: Resource Isolation Validation
**Objective**: Verify resource isolation (CPU, memory, disk)  
**Risk Level**: Medium  
**Test Method**: Resource limit testing

**Steps**:
1. Check VM resource limits: `virsh dominfo <vm-name>`
2. Check container resource limits: `docker inspect <container>`
3. Run stress tests in VM and containers
4. Verify resource limits are enforced
5. Check for resource starvation scenarios

**Expected Result**: Resource limits are enforced

**Pass Criteria**:
- [ ] VM CPU limits are enforced
- [ ] VM memory limits are enforced
- [ ] Container CPU limits are enforced
- [ ] Container memory limits are enforced
- [ ] Disk quotas are enforced

---

### TC-007: Inter-Container Isolation
**Objective**: Test isolation between agent containers  
**Risk Level**: Medium  
**Test Method**: Network and process isolation testing

**Steps**:
1. From one container, attempt to access another container's filesystem
2. Attempt to communicate between containers on unauthorized ports
3. Check container process visibility: `ps aux` from within containers
4. Attempt to access shared volumes inappropriately
5. Verify container network segmentation

**Expected Result**: Containers are properly isolated

**Pass Criteria**:
- [ ] Cannot access other container filesystems
- [ ] Network communication follows defined policies
- [ ] Process isolation is maintained
- [ ] Volume access is properly restricted

---

### TC-008: Security Configuration Audit
**Objective**: Perform comprehensive security audit of configurations  
**Risk Level**: High  
**Test Method**: Configuration file inspection and validation

**Steps**:
1. Review SSH configuration in VM for security hardening
2. Review Docker daemon configuration for security settings
3. Review libvirt configuration for isolation settings
4. Review firewall rules for proper segmentation
5. Review container security contexts (capabilities, seccomp, etc.)
6. Check for hardcoded credentials or IPs

**Expected Result**: All configurations follow security best practices

**Pass Criteria**:
- [ ] SSH hardening implemented correctly
- [ ] Docker security settings are appropriate
- [ ] Libvirt isolation is properly configured
- [ ] Firewall rules are correct
- [ ] Container security contexts are minimal
- [ ] No hardcoded credentials or IPs found

---

## Test Execution Plan

### Prerequisites
- [ ] Isolation VM is running and accessible
- [ ] All agent containers are deployed and running
- [ ] VPN and proxy services are operational
- [ ] Ansible test infrastructure is in place

### Test Execution Order
1. TC-001: VM Docker Socket Isolation (Critical)
2. TC-002: Agent Container Host Network Isolation (Critical)
3. TC-003: VPN Credential Exposure Test (Critical)
4. TC-004: VM Network Firewall Validation (High)
5. TC-005: Privilege Escalation Boundaries (High)
6. TC-006: Resource Isolation Validation (Medium)
7. TC-007: Inter-Container Isolation (Medium)
8. TC-008: Security Configuration Audit (High)

### Success Criteria
- All Critical test cases must pass
- At least 80% of High priority test cases must pass
- At least 60% of Medium priority test cases must pass
- Any failures must be documented with remediation plans

## Security Vulnerability Classification

### Critical (Must Fix)
- VM can access host Docker socket
- Agent containers can access host networks
- VPN credentials exposed to containers
- Privilege escalation possible

### High (Should Fix)
- Firewall rules not properly configured
- Resource limits not enforced
- Security configurations not hardened

### Medium (Nice to Fix)
- Inter-container isolation weaknesses
- Configuration hardening opportunities
- Logging and monitoring gaps

## Remediation Planning

For any security vulnerabilities found:
1. Document the vulnerability with severity level
2. Identify the root cause
3. Propose remediation steps
4. Estimate remediation effort
5. Create follow-up task if needed

## Test Results Documentation

After test execution, document:
- Test execution date and time
- Tester name
- Test environment details
- Results for each test case
- Screenshots or logs where applicable
- Vulnerabilities found with severity
- Remediation recommendations

## Compliance Notes

This security audit must comply with:
- `/AGENTS.md` - Root project security guidelines
- `shared/active/02-config/ansible/AGENTS.md` - Ansible security guidelines
- `shared/active/03-container/AGENTS.md` - Container security guidelines

All IP addresses, ports, and credentials must be variable-driven per AGENTS.md requirements.

## Related Documentation

- **PRD**: `shared/active/08-docs/reqs/2026/20260619-isolation-vm.md`
- **OCI Cloud Server Host PRD**: `shared/active/08-docs/reqs/2026/20260619-oci-cloud-server-host.md`
- **Task Index**: `internal-docs/feature/isolation-vm/tasks/index-isolation-vm.md`
